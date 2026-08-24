\encoding UTF8
-- =====================================================================
-- V16: risk_grid_factor 나머지 요인 채우기 (Phase 4-B)
--   risk_grid_factor는 V15(격자 내 개수) + V16(반경·거리·인구) 두 단계로 만든다.
--
--   요인 성격에 따라 계산 방식을 나눈다 (2026-08-24 결정)
--     · 방범CCTV  → **반경 50m·100m 내 개수**
--       최근접 거리는 "가장 가까운 카메라가 그 지점을 본다"는 가정인데, 교차로에서는
--       가까운 것이 반대편을 향하고 먼 것이 그 지점을 비출 수 있다. 원천에 방향·화각·PTZ
--       정보가 전혀 없어(props = 시설명칭·연번·장비종류) 시야 모델링이 불가능하다.
--       방향을 모를 때는 "100m 안에 5대"가 "가장 가까운 1대가 30m"보다 감시 확률이 높다.
--     · 비상벨·지구대 → **최근접 거리** (달려가는 거리라 방향과 무관)
--     · 보안등 → 개수 (빛은 퍼진다, V15에서 처리)
-- =====================================================================

ALTER TABLE digital_twin.risk_grid_factor
    ADD COLUMN IF NOT EXISTS cctv_cnt_50m  integer NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS cctv_cnt_100m integer NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS pop_est       double precision NULL;

COMMENT ON COLUMN digital_twin.risk_grid_factor.cctv_cnt_50m IS
    '격자 중심 반경 50m 내 방범CCTV 수 (방향 정보가 없어 원형 근사)';
COMMENT ON COLUMN digital_twin.risk_grid_factor.pop_est IS
    '추정 인구 = Σ(행정동 인구 × 교차면적/행정동면적). 행정동 내부 균일 분포 가정';

-- ─────────────────────────────────────────────────────────────
-- 성능 준비 (2026-08-24 추가): 캐스팅 때문에 인덱스를 못 타던 문제 해결
--   ST_DWithin(...::geography, ...) 는 geom(geometry)에 걸린 GIST 인덱스를 쓰지 못한다.
--   그대로 두면 격자 13,439 × CCTV 21,053 = 2.8억 번 타원체 거리 계산이 되어
--   ① UPDATE가 끝나지 않는다(실제로 취소해야 했다).
--   → 격자 중심을 컬럼으로 굳히고, facility에 geography 표현식 인덱스를 만든다.
-- ─────────────────────────────────────────────────────────────

-- 격자 중심점 (GENERATED — geom이 바뀌면 자동 갱신)
ALTER TABLE digital_twin.risk_grid
    ADD COLUMN IF NOT EXISTS centroid geometry(Point, 4326)
    GENERATED ALWAYS AS (ST_Centroid(geom)) STORED;

CREATE INDEX IF NOT EXISTS idx_risk_grid_centroid
    ON digital_twin.risk_grid USING gist (centroid);

-- facility geography 표현식 인덱스 — 반경·최근접 계산에 쓰는 유형만 부분 인덱스로
--   보안등(16)은 격자 내 개수만 쓰므로(반경 계산 없음) 인덱스를 만들지 않는다
CREATE INDEX IF NOT EXISTS idx_facility_geog_cctv
    ON digital_twin.facility USING gist ((geom::geography)) WHERE facility_type = 6;
CREATE INDEX IF NOT EXISTS idx_facility_geog_bell
    ON digital_twin.facility USING gist ((geom::geography)) WHERE facility_type = 15;
CREATE INDEX IF NOT EXISTS idx_facility_geog_police
    ON digital_twin.facility USING gist ((geom::geography)) WHERE facility_type = 18;

-- KNN(`<->`)용 **geometry** 부분 인덱스 — 위 geography 인덱스로는 <-> 정렬을 못 탄다.
--   전체 facility(29만)에 걸린 인덱스로 `WHERE facility_type = 18`(94건)을 찾으면
--   조건에 안 맞는 항목을 계속 건너뛰어야 해서 격자 13,439개를 돌릴 수 없다
--   (2026-08-24 ② UPDATE를 취소해야 했던 원인).
CREATE INDEX IF NOT EXISTS idx_facility_geom_bell
    ON digital_twin.facility USING gist (geom) WHERE facility_type = 15;
CREATE INDEX IF NOT EXISTS idx_facility_geom_police
    ON digital_twin.facility USING gist (geom) WHERE facility_type = 18;

-- ① CCTV 반경 내 개수 (격자 중심 기준)
UPDATE digital_twin.risk_grid_factor fa
SET cctv_cnt_50m  = sub.c50,
    cctv_cnt_100m = sub.c100
    FROM (
    SELECT g.id,
           count(f.id) FILTER (
               WHERE ST_DWithin(g.centroid::geography, f.geom::geography, 50)) AS c50,
           count(f.id) AS c100
      FROM digital_twin.risk_grid g
      LEFT JOIN digital_twin.facility f
             ON f.facility_type = 6
            AND ST_DWithin(g.centroid::geography, f.geom::geography, 100)
     WHERE g.grid_size = 250
     GROUP BY g.id
  ) sub
WHERE fa.grid_id = sub.id;

-- ② 최근접 거리 (비상벨 15 / 지구대·파출소 18)
UPDATE digital_twin.risk_grid_factor fa
SET bell_dist_m   = d.bell,
    police_dist_m = d.police
    FROM (
    SELECT g.id,
           (SELECT ST_Distance(g.centroid::geography, f.geom::geography)
              FROM digital_twin.facility f
             WHERE f.facility_type = 15
             ORDER BY f.geom <-> g.centroid
             LIMIT 1) AS bell,
           (SELECT ST_Distance(g.centroid::geography, f.geom::geography)
              FROM digital_twin.facility f
             WHERE f.facility_type = 18
             ORDER BY f.geom <-> g.centroid
             LIMIT 1) AS police
      FROM digital_twin.risk_grid g
     WHERE g.grid_size = 250
  ) d
WHERE fa.grid_id = d.id;

-- ③ 인구 면적 비례 배분
--   최적화 두 가지:
--     · 행정동 면적을 CTE에서 **한 번만** 계산한다. 서브쿼리 안에 두면 겹치는 쌍마다
--       복잡한 폴리곤 면적을 다시 계산한다(행정동 하나가 격자 수십 개와 겹친다).
--     · 면적을 **geography로 캐스팅하지 않는다.** 여기서 쓰는 것은 면적의 '비율'이라
--       분자·분모의 단위가 상쇄된다. 행정동 한 곳(수 km) 안에서는 투영 왜곡이
--       무시할 수준이라 평면 면적비로 충분하고, geography 계산보다 훨씬 싸다.
WITH ap AS (
    SELECT tot_ppltn, geom, ST_Area(geom) AS area_deg2
      FROM digital_twin.admin_population
     WHERE year = 2024
)
UPDATE digital_twin.risk_grid_factor fa
SET pop_est = p.pop
    FROM (
    SELECT g.id,
           sum(ap.tot_ppltn
               * ST_Area(ST_Intersection(g.geom, ap.geom))
               / nullif(ap.area_deg2, 0)) AS pop
      FROM digital_twin.risk_grid g
      JOIN ap
        ON ST_Intersects(g.geom, ap.geom)
     WHERE g.grid_size = 250
     GROUP BY g.id
  ) p
WHERE fa.grid_id = p.id;
