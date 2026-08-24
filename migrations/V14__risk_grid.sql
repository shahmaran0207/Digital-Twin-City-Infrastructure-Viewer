\encoding UTF8
-- =====================================================================
-- V14: risk_grid — 위험도 격자 (Phase 4 / 4-B 공용)
--   결정(2026-08-23): 격자 250m · 육지만 · CCTV 커버리지 반경 50m
--     · 250m 선택 이유: 500m는 행정동 하나에 몇 개뿐이라 "이 블록이 위험한가"를
--       보여주지 못한다. 실측 250m=13,439셀 / 500m=3,555셀
--     · 육지만: 부산은 해안선이 길어 BBox로 만들면 바다 셀이 절반에 가깝다
--
--   기하만 담는다. 요인값·점수는 다음 단계에서 별도로 만든다
--   (격자는 한 번 만들고 고정, 점수는 재계산되므로 수명이 다르다).
--
--   grid_i / grid_j: ST_SquareGrid가 주는 격자 좌표. 이웃 셀 연산(평활·KDE)에 쓴다.
-- =====================================================================

CREATE TABLE IF NOT EXISTS digital_twin.risk_grid (
                                                      id        bigint   GENERATED ALWAYS AS IDENTITY,
                                                      grid_size smallint NOT NULL,          -- 한 변 길이(m)
                                                      grid_i    integer  NOT NULL,
                                                      grid_j    integer  NOT NULL,
                                                      geom      geometry(Polygon, 4326) NOT NULL,
    CONSTRAINT risk_grid_pk PRIMARY KEY (id),
    CONSTRAINT risk_grid_ij_uq UNIQUE (grid_size, grid_i, grid_j)
    );

COMMENT ON TABLE  digital_twin.risk_grid           IS '위험도 격자 (250m, 부산 육지). 기하 전용 — 점수는 별도 테이블';
COMMENT ON COLUMN digital_twin.risk_grid.grid_size IS '격자 한 변 길이(m)';
COMMENT ON COLUMN digital_twin.risk_grid.grid_i    IS 'ST_SquareGrid 격자 열 좌표 (이웃 셀 연산용)';

CREATE INDEX IF NOT EXISTS idx_risk_grid_geom ON digital_twin.risk_grid USING gist (geom);

-- 재실행 가능하게
DELETE FROM digital_twin.risk_grid WHERE grid_size = 250;

-- 부산 육지 경계(행정동 합집합)와 교차하는 셀만 생성
--   ST_SquareGrid는 투영좌표계에서 써야 한 변이 정확히 250m가 된다 → 5179로 변환 후 생성, 4326으로 되돌림
INSERT INTO digital_twin.risk_grid (grid_size, grid_i, grid_j, geom)
SELECT 250, c.i, c.j, ST_Transform(c.geom, 4326)
FROM (
         SELECT ST_Transform(ST_Union(geom), 5179) AS g
         FROM digital_twin.admin_population
         WHERE year = 2024
     ) busan,
     ST_SquareGrid(250, busan.g) c
WHERE ST_Intersects(c.geom, busan.g);
