-- =====================================================================
-- V7: dem_raster — 수치표고모델 (침수 시뮬레이션, bathtub 모델)
--   원천: 한반도90m_GRS80.img (NSDI 90m DEM)
--   적재: raster2pgsql 로 타일 적재 (별도 명령, 가공/적재 단계에서 실행)
--     예) raster2pgsql -s 4326 -t 100x100 -I -C 한반도90m.tif digital_twin.dem_raster | psql ...
--   침수 도출: 수위 H 임계값 미만 영역을 ST_DumpAsPolygons 로 폴리곤화 → GeoJSON 응답
--   ※ 90m는 거칠어 추후 5m DEM 확보 시 동일 테이블 교체
-- =====================================================================

CREATE EXTENSION IF NOT EXISTS postgis_raster;

CREATE TABLE IF NOT EXISTS digital_twin.dem_raster (
    rid  integer GENERATED ALWAYS AS IDENTITY,
    rast raster NOT NULL,
    CONSTRAINT dem_raster_pk PRIMARY KEY (rid)
);

COMMENT ON TABLE digital_twin.dem_raster IS '수치표고모델 래스터 (침수 시뮬레이션, raster2pgsql 적재)';

-- 래스터 타일 공간 인덱스 (타일별 외곽 convex hull 기준)
CREATE INDEX IF NOT EXISTS idx_dem_raster_hull
    ON digital_twin.dem_raster USING gist (ST_ConvexHull(rast));
