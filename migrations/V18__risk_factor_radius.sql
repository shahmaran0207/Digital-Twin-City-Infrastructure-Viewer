\encoding UTF8
-- =====================================================================
-- V18: 표적 요인을 반경 500m 집계로 확장 (Phase 4-B, v2 산식 준비)
--
--   문제: 격자 내 개수로만 세니 표적 요인이 너무 희소했다.
--         보관소 517셀(3.8%) / 심야업소 1,235셀(9.2%)만 0이 아니어서
--         정규화 평균이 0.02, 가중치 0.30·0.15가 작동하지 않았다.
--         → 위험지수가 "CCTV·보안등 부재"만으로 결정되어 농지가 최고 위험이 됐다.
--
--   해결: 격자 중심 반경 500m 내 개수로 바꿔 신호를 퍼뜨린다.
--         격자 경계에서 뚝 끊기는 문제도 함께 해결된다(옆 칸 보관소도 반영).
--         500m = 자전거로 1~2분, "이 근처에 자전거가 있다"고 볼 수 있는 범위.
--
--   기존 격자 내 개수(rack_cnt·night_biz_cnt)는 지우지 않는다 — 팝업에서
--   "이 칸에 몇 개"를 보여줄 때 쓰고, 민감도 분석에서 반경 유무를 비교한다.
-- =====================================================================

ALTER TABLE digital_twin.risk_grid_factor
    ADD COLUMN IF NOT EXISTS rack_cnt_500m integer NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS biz_cnt_500m  integer NOT NULL DEFAULT 0;

COMMENT ON COLUMN digital_twin.risk_grid_factor.rack_cnt_500m IS
    '격자 중심 반경 500m 내 자전거보관소 수 — 격자 내 개수는 너무 희소해 v2 산식은 이 값을 쓴다';
COMMENT ON COLUMN digital_twin.risk_grid_factor.biz_cnt_500m IS
    '격자 중심 반경 500m 내 심야업소 수(유흥·요리주점+숙박+PC방)';

-- geography 부분 인덱스 — 캐스팅한 표현식 그대로 만들어야 인덱스를 탄다
CREATE INDEX IF NOT EXISTS idx_facility_geog_rack
    ON digital_twin.facility USING gist ((geom::geography)) WHERE facility_type = 13;
CREATE INDEX IF NOT EXISTS idx_facility_geog_biz
    ON digital_twin.facility USING gist ((geom::geography)) WHERE facility_type IN (19, 20, 21);

-- 자전거보관소 (idx_facility_geog_rack 과 조건 일치: facility_type = 13)
UPDATE digital_twin.risk_grid_factor fa
SET rack_cnt_500m = sub.cnt
    FROM (
    SELECT g.id, count(f.id) AS cnt
      FROM digital_twin.risk_grid g
      LEFT JOIN digital_twin.facility f
             ON f.facility_type = 13
            AND ST_DWithin(g.centroid::geography, f.geom::geography, 500)
     WHERE g.grid_size = 250
     GROUP BY g.id
  ) sub
WHERE fa.grid_id = sub.id;

-- 심야업소 (idx_facility_geog_biz 와 조건 일치: facility_type IN (19,20,21))
UPDATE digital_twin.risk_grid_factor fa
SET biz_cnt_500m = sub.cnt
    FROM (
    SELECT g.id, count(f.id) AS cnt
      FROM digital_twin.risk_grid g
      LEFT JOIN digital_twin.facility f
             ON f.facility_type IN (19, 20, 21)
            AND ST_DWithin(g.centroid::geography, f.geom::geography, 500)
     WHERE g.grid_size = 250
     GROUP BY g.id
  ) sub
WHERE fa.grid_id = sub.id;

