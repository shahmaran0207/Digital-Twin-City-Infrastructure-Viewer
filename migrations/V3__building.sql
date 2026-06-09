-- =====================================================================
-- V3: building — GIS건물통합정보 (시뮬레이션 입력: 그림자/침수 차폐, 3D 압출)
--   원천: NSDI AL_D162_26 (부산, 폴리곤 23만건, 원본 EPSG:5186 → 적재 시 4326 변환)
--   원본 컬럼은 A0~A39로 익명화돼 있어, 실제 의미로 매핑해 보존
--   (A0 관리번호, A3 주소, A12 건물명, A24 연면적, A28 구조, A30 용도,
--    A32 지상층, A33 지하층, A37 높이[결측 多])
-- =====================================================================

CREATE TABLE IF NOT EXISTS digital_twin.building (
    id            bigint GENERATED ALWAYS AS IDENTITY,
    source_id     varchar(40)      NULL,  -- A0 건물 관리번호
    sigungu       varchar(50)      NULL,
    name          varchar(200)     NULL,  -- A12 건물명 (빈 값 많음)
    addr          varchar(300)     NULL,  -- A3 대지위치 + A6 지번
    main_use      varchar(100)     NULL,  -- A30 주용도 (예: 업무시설)
    struct        varchar(100)     NULL,  -- A28 구조 (예: 철근콘크리트구조)
    floors_above  integer          NULL,  -- A32 지상층수
    floors_below  integer          NULL,  -- A33 지하층수
    height_m      double precision NULL,  -- A37 높이(m) — 원본, 대부분 0/결측
    height_est    double precision NULL,  -- 3D 압출용 추정높이 (height_m>0 ? height_m : floors_above*3.3)
    total_area    double precision NULL,  -- A24 연면적(㎡)
    props         jsonb            NULL,  -- 그 외 보존이 필요한 원본 속성
    geom          geometry(MultiPolygon, 4326) NOT NULL,
    CONSTRAINT building_pk PRIMARY KEY (id)
);

COMMENT ON TABLE  digital_twin.building              IS 'GIS건물통합정보 (그림자/침수 차폐, 3D 압출용 폴리곤)';
COMMENT ON COLUMN digital_twin.building.source_id    IS '원본 건물 관리번호 (A0)';
COMMENT ON COLUMN digital_twin.building.height_m     IS '원본 높이(m), 대부분 결측';
COMMENT ON COLUMN digital_twin.building.height_est   IS '3D 압출용 추정높이 — 원본 높이 없으면 지상층수×3.3m';
COMMENT ON COLUMN digital_twin.building.geom         IS '건물 외곽 폴리곤 (EPSG:4326, 원본 5186에서 변환)';

CREATE INDEX IF NOT EXISTS idx_building_geom    ON digital_twin.building USING gist (geom);
CREATE INDEX IF NOT EXISTS idx_building_sigungu ON digital_twin.building (sigungu);
