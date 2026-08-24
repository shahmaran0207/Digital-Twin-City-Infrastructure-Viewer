\encoding UTF8
-- =====================================================================
-- V15: risk_grid_factor — 격자별 RTM 요인값 (Phase 4-B)
--   격자 13,439개 × 요인 7종을 미리 계산해 담는다.
--   매 조회마다 facility 29만 건과 공간 조인하면 느리므로 사전 집계한다.
--
--   요인 구분 (crime-prediction.md 3-1)
--     · 개수(밀도)   : 격자 안에 몇 개인가        → 면적 요인
--     · 최근접 거리  : 가장 가까운 것이 몇 m인가  → 접근성 요인
--     둘을 섞지 않는다.
--
--   CCTV 커버리지는 반경 50m 결정(2026-08-23) — 야간·화각 제약을 감안한 보수적 값.
--   100m로 잡으면 커버리지를 과대평가해 위험 구역을 놓치는 쪽으로 틀린다.
-- =====================================================================

-- 전부 파생 값이라 재생성이 안전하다. DROP으로 시작해 스키마가 이 스크립트와 항상 일치하게 한다.
DROP TABLE IF EXISTS digital_twin.risk_grid_factor;

CREATE TABLE digital_twin.risk_grid_factor (
                                               grid_id        bigint  NOT NULL,
    -- 위험 유발 (↑)
                                               rack_cnt       integer NOT NULL DEFAULT 0,  -- 자전거보관소 수
                                               night_biz_cnt  integer NOT NULL DEFAULT 0,  -- 유흥·요리주점+숙박+PC방
    -- 위험 저감 (↓)
                                               cctv_cnt       integer NOT NULL DEFAULT 0,  -- 방범CCTV 수
                                               light_cnt      integer NOT NULL DEFAULT 0,  -- 보안등 수
                                               bell_dist_m    double precision NULL,       -- 안전비상벨 최근접 거리
                                               police_dist_m  double precision NULL,       -- 지구대·파출소 최근접 거리
                                               CONSTRAINT risk_grid_factor_pk PRIMARY KEY (grid_id),
                                               CONSTRAINT risk_grid_factor_fk FOREIGN KEY (grid_id)
                                                   REFERENCES digital_twin.risk_grid (id) ON DELETE CASCADE
);


COMMENT ON TABLE digital_twin.risk_grid_factor IS
    '격자별 RTM 요인값 (사전 집계). 요인이 늘면 컬럼 추가 후 재계산';
COMMENT ON COLUMN digital_twin.risk_grid_factor.rack_cnt IS
    '자전거보관소 수. 개방/폐쇄 가중은 불가 — 부산 원천의 설치형태 값이 거치형 718·단독형 445·기타 6·미기재 103뿐이고 개방·폐쇄 구분이 없다(2026-08-24 확인)';

-- 재실행 가능하게
TRUNCATE digital_twin.risk_grid_factor;

INSERT INTO digital_twin.risk_grid_factor
(grid_id, rack_cnt, night_biz_cnt, cctv_cnt, light_cnt)
SELECT g.id,
       count(*) FILTER (WHERE f.facility_type = 13),
    count(*) FILTER (WHERE f.facility_type IN (19, 20, 21)),
    count(*) FILTER (WHERE f.facility_type = 6),
    count(*) FILTER (WHERE f.facility_type = 16)
FROM digital_twin.risk_grid g
         LEFT JOIN digital_twin.facility f
                   ON ST_Intersects(g.geom, f.geom)
                       AND f.facility_type IN (6, 13, 16, 19, 20, 21)
WHERE g.grid_size = 250
GROUP BY g.id;
