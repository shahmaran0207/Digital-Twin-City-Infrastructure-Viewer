\encoding UTF8
-- =====================================================================
-- V12: OSM 자전거·보행 링크를 road_link에 적재 (Phase 1-C, 링크 데이터 A안)
--
--   입력: data/processed/osm_link.csv  (fetch_osm.py 산출)
--         컬럼 = osm_id, highway, name, bicycle, foot, surface, segregated, width, ewkt
--
--   ▸ 실행 전 반드시 fetch_osm.py를 먼저 돌려 CSV를 만들어야 한다.
--   ▸ 저장소 루트에서 실행할 것 (\copy 경로가 상대경로).
--   ▸ 라이선스: OSM은 ODbL — README에 "© OpenStreetMap contributors" 표기 필요.
--
--   모드 플래그 규칙 (V11 정의에 맞춤)
--     car  : 전부 false — OSM에서 가져오는 것은 자전거도로·보도뿐이다
--     cycleway   → bike=true,  foot = (foot 태그가 yes/designated)
--     footway    → foot=true,  bike = (bicycle 태그가 yes/designated)
--     pedestrian → foot=true,  bike = (bicycle 태그가 yes/designated)
--     path       → foot=true,  bike = (bicycle 태그가 no가 아니면 true)
--                  path는 용도가 명시되지 않은 혼용 경로라 자전거를 기본 허용한다
--     pm_allowed 는 V11의 GENERATED 컬럼이 자동 계산 (source_type='osm' AND bike_allowed)
--
--   link_id 는 'osm' + osm_id 로 만들어 표준노드링크 ID와 충돌하지 않게 한다.
--   f_node/t_node/source/target 은 채우지 않는다 → 라우팅 위상 연결은 별도 단계.
-- =====================================================================

-- 컬럼 폭 확대: road_type이 varchar(3)(표준노드링크 코드 기준)이라
--   'cycleway'(8자)·'pedestrian'(10자)이 들어가지 않는다. road_name도 OSM 명칭이 더 길 수 있다.
ALTER TABLE digital_twin.road_link ALTER COLUMN road_type TYPE varchar(20);
ALTER TABLE digital_twin.road_link ALTER COLUMN road_name TYPE varchar(120);

-- 재실행 가능하게: 이전 OSM 적재분을 지우고 다시 넣는다
DELETE FROM digital_twin.road_link WHERE source_type = 'osm';

CREATE TEMP TABLE osm_stage (
    osm_id     bigint,
    highway    text,
    name       text,
    bicycle    text,
    foot       text,
    surface    text,
    segregated text,
    width      text,
    ewkt       text
);

\copy osm_stage FROM 'data/processed/osm_link.csv' WITH (FORMAT csv, HEADER true)

INSERT INTO digital_twin.road_link
    (link_id, road_name, road_type, source_type,
     car_allowed, bike_allowed, foot_allowed,
     length_m, cost, reverse_cost, props, geom)
SELECT
    'osm' || s.osm_id,
    nullif(s.name, ''),
    s.highway,
    'osm',
    false,                                          -- car
    -- ⚠️ coalesce 필수: CSV 모드의 빈 필드는 ''가 아니라 NULL로 들어온다.
    --    NULL IN (...) 은 NULL이 되어 NOT NULL 제약을 위반한다(2026-08-23 실제로 겪음).
    CASE s.highway                                  -- bike
        WHEN 'cycleway' THEN true
        WHEN 'path'     THEN coalesce(s.bicycle, '') <> 'no'
        ELSE coalesce(s.bicycle, '') IN ('yes', 'designated')
    END,
    CASE s.highway                                  -- foot
        WHEN 'cycleway' THEN coalesce(s.foot, '') IN ('yes', 'designated')
        ELSE true
    END,
    ST_Length(ST_GeomFromEWKT(s.ewkt)::geography),  -- length_m
    ST_Length(ST_GeomFromEWKT(s.ewkt)::geography),  -- cost (보행·자전거는 거리 기반)
    ST_Length(ST_GeomFromEWKT(s.ewkt)::geography),  -- reverse_cost (양방향)
    jsonb_strip_nulls(jsonb_build_object(
        'osm_id',     s.osm_id,
        'highway',    s.highway,
        'bicycle',    nullif(s.bicycle, ''),
        'foot',       nullif(s.foot, ''),
        'surface',    nullif(s.surface, ''),
        'segregated', nullif(s.segregated, ''),
        'width',      nullif(s.width, ''),
        'license',    'ODbL © OpenStreetMap contributors'
    )),
    ST_GeomFromEWKT(s.ewkt)
FROM osm_stage s
WHERE ST_IsValid(ST_GeomFromEWKT(s.ewkt));

DROP TABLE osm_stage;
