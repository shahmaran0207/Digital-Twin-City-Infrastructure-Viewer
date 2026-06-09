-- =====================================================================
-- V5: shelter / population_grid — 대피 시뮬레이션 입력
--   shelter         : 지진해일 긴급대피장소 표준데이터 (포인트)
--   population_grid : SGIS 격자인구 (폴리곤, 대피 수요)
--   ※ 두 데이터 모두 아직 미확보 — 스키마(DDL)만 선반영, 적재는 확보 후
-- =====================================================================

-- ---------------------------------------------------------------
-- 지진해일 긴급대피장소
-- ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS digital_twin.shelter (
    id        bigint GENERATED ALWAYS AS IDENTITY,
    source_id varchar(50)      NULL,
    name      varchar(200)     NULL,
    addr      varchar(300)     NULL,
    capacity  integer          NULL,  -- 수용인원
    elevation double precision NULL,  -- 해발고도(m)
    props     jsonb            NULL,
    geom      geometry(Point, 4326) NOT NULL,
    CONSTRAINT shelter_pk PRIMARY KEY (id)
);

COMMENT ON TABLE  digital_twin.shelter           IS '지진해일 긴급대피장소 (대피 시뮬레이션 목적지)';
COMMENT ON COLUMN digital_twin.shelter.capacity  IS '수용인원';
COMMENT ON COLUMN digital_twin.shelter.elevation IS '해발고도(m)';

CREATE INDEX IF NOT EXISTS idx_shelter_geom ON digital_twin.shelter USING gist (geom);

-- ---------------------------------------------------------------
-- 격자 인구 (SGIS)
-- ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS digital_twin.population_grid (
    id         bigint GENERATED ALWAYS AS IDENTITY,
    grid_id    varchar(30)      NULL,
    population integer          NULL,  -- 격자 내 인구 수
    props      jsonb            NULL,  -- 연령대별 등 부가 통계
    geom       geometry(Polygon, 4326) NOT NULL,
    CONSTRAINT population_grid_pk PRIMARY KEY (id)
);

COMMENT ON TABLE  digital_twin.population_grid            IS 'SGIS 격자인구 (대피 수요 / 위기레벨 가중치)';
COMMENT ON COLUMN digital_twin.population_grid.population IS '격자 내 총 인구';

CREATE INDEX IF NOT EXISTS idx_population_grid_geom ON digital_twin.population_grid USING gist (geom);
