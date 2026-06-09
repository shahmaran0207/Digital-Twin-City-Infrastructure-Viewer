-- =====================================================================
-- V6: admin_emd — 읍면동 경계 (통계 시각화 / 시군구 집계)
--   원천: emd_20230729 (전국 읍면동 폴리곤, prj 누락 → EPSG:5179 가정, 적재 시 4326 변환)
--   부산(법정동코드 앞 2자리 '26')만 추출
--   시군구 경계는 emd dissolve로 파생 (admin_sigungu 뷰)
-- =====================================================================

CREATE TABLE IF NOT EXISTS digital_twin.admin_emd (
    id        bigint GENERATED ALWAYS AS IDENTITY,
    emd_cd    varchar(10)  NOT NULL,  -- 읍면동 코드 (EMD_CD)
    emd_ko_nm varchar(60)  NULL,      -- 읍면동 한글명 (EMD_KOR_NM)
    sigungu   varchar(50)  NULL,      -- 시군구명 (코드/별도 매핑으로 채움)
    geom      geometry(MultiPolygon, 4326) NOT NULL,
    CONSTRAINT admin_emd_pk PRIMARY KEY (id),
    CONSTRAINT admin_emd_cd_uq UNIQUE (emd_cd)
);

COMMENT ON TABLE  digital_twin.admin_emd        IS '읍면동 경계 (부산, 통계 시각화 / 시군구 집계 기반)';
COMMENT ON COLUMN digital_twin.admin_emd.emd_cd IS '읍면동 법정동코드 (앞 2자리 26 = 부산)';

CREATE INDEX IF NOT EXISTS idx_admin_emd_geom    ON digital_twin.admin_emd USING gist (geom);
CREATE INDEX IF NOT EXISTS idx_admin_emd_sigungu ON digital_twin.admin_emd (sigungu);

-- 시군구 경계: 읍면동을 시군구 단위로 합쳐 파생 (코드 앞 5자리 = 시군구)
CREATE OR REPLACE VIEW digital_twin.admin_sigungu AS
SELECT
    substring(emd_cd FROM 1 FOR 5) AS sigungu_cd,
    max(sigungu)                   AS sigungu,
    ST_Multi(ST_Union(geom))       AS geom
FROM digital_twin.admin_emd
GROUP BY substring(emd_cd FROM 1 FOR 5);

COMMENT ON VIEW digital_twin.admin_sigungu IS '시군구 경계 (admin_emd dissolve 파생 뷰)';
