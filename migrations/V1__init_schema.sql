-- =====================================================================
-- V1: 스키마 / 테이블 초기화
--   기존 "DigitalTwin" 스키마의 시설물별 13개 테이블 구조를
--   단일 facility 테이블 + facility_type 룩업 테이블로 통합 재설계
--
--   변경 요점
--   - 스키마명 "DigitalTwin"(따옴표 필수) → digital_twin (소문자, 따옴표 불필요)
--   - 동일 구조 13개 테이블 → facility 1개 (facility_type으로 구분)
--   - geom: 수동 UPDATE 방식 → lon/lat 기반 GENERATED 컬럼 (항상 자동 동기화)
--   - GIST 공간 인덱스 + facility_type / sigungu 인덱스 추가
--   - id: numeric → bigint IDENTITY (원천 데이터 id는 source_id로 보존)
-- =====================================================================

CREATE EXTENSION IF NOT EXISTS postgis;

CREATE SCHEMA IF NOT EXISTS digital_twin;

-- ---------------------------------------------------------------
-- 시설물 유형 룩업
-- ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS digital_twin.facility_type (
    code        integer      NOT NULL,
    name        varchar(50)  NOT NULL,
    name_ko     varchar(100) NOT NULL,
    category    varchar(30)  NOT NULL,
    category_ko varchar(50)  NOT NULL,
    CONSTRAINT facility_type_pk PRIMARY KEY (code),
    CONSTRAINT facility_type_name_uq UNIQUE (name)
);

COMMENT ON TABLE  digital_twin.facility_type             IS '시설물 유형 코드 테이블';
COMMENT ON COLUMN digital_twin.facility_type.code        IS '시설물 타입 코드 (원천 CSV의 facility_type 값)';
COMMENT ON COLUMN digital_twin.facility_type.name        IS '시설물 유형 영문 키 (API/프론트 레이어 키)';
COMMENT ON COLUMN digital_twin.facility_type.name_ko     IS '시설물 유형 한글명';
COMMENT ON COLUMN digital_twin.facility_type.category    IS '레이어 카테고리 영문 키 (traffic/safety/road_facility/transit/living)';
COMMENT ON COLUMN digital_twin.facility_type.category_ko IS '레이어 카테고리 한글명';

-- ---------------------------------------------------------------
-- 통합 시설물 테이블
-- ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS digital_twin.facility (
    id            bigint GENERATED ALWAYS AS IDENTITY,
    facility_type integer          NOT NULL,
    source_id     varchar(50)      NULL,
    sigungu       varchar(50)      NULL,
    name          varchar(200)     NULL,
    lon           double precision NOT NULL,
    lat           double precision NOT NULL,
    props         jsonb            NULL,
    geom          geometry(Point, 4326)
                  GENERATED ALWAYS AS (ST_SetSRID(ST_MakePoint(lon, lat), 4326)) STORED,
    CONSTRAINT facility_pk PRIMARY KEY (id),
    CONSTRAINT facility_type_fk FOREIGN KEY (facility_type)
        REFERENCES digital_twin.facility_type (code),
    -- 부산 인근 좌표만 허용 (적재 시 오류 데이터 차단)
    CONSTRAINT facility_lon_range CHECK (lon > 128.5 AND lon < 129.5),
    CONSTRAINT facility_lat_range CHECK (lat > 34.8  AND lat < 35.7)
);

COMMENT ON TABLE  digital_twin.facility               IS '통합 시설물 테이블 (전 시설물 포인트, facility_type으로 구분)';
COMMENT ON COLUMN digital_twin.facility.id            IS '내부 고유 ID (자동 증가)';
COMMENT ON COLUMN digital_twin.facility.facility_type IS '시설물 타입 코드 (facility_type.code 참조)';
COMMENT ON COLUMN digital_twin.facility.source_id     IS '원천 데이터의 id';
COMMENT ON COLUMN digital_twin.facility.sigungu       IS '시군구';
COMMENT ON COLUMN digital_twin.facility.name          IS '시설물 명칭 (있는 경우)';
COMMENT ON COLUMN digital_twin.facility.lon           IS '경도 (EPSG:4326)';
COMMENT ON COLUMN digital_twin.facility.lat           IS '위도 (EPSG:4326)';
COMMENT ON COLUMN digital_twin.facility.props         IS '시설물별 추가 속성 (예: ITS CCTV 스트림 url)';
COMMENT ON COLUMN digital_twin.facility.geom          IS 'lon/lat에서 자동 생성되는 포인트 지오메트리 (GENERATED)';

-- ---------------------------------------------------------------
-- 인덱스
-- ---------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_facility_geom    ON digital_twin.facility USING gist (geom);
CREATE INDEX IF NOT EXISTS idx_facility_type    ON digital_twin.facility (facility_type);
CREATE INDEX IF NOT EXISTS idx_facility_sigungu ON digital_twin.facility (sigungu);
