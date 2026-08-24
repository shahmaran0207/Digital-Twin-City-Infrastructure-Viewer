\encoding UTF8
-- =====================================================================
-- V13: admin_population — SGIS 행정동 인구·경계 (Phase 1-C, RTM 인구 요인)
--
--   입력: data/processed/admin_population.csv  (fetch_sgis_population.py 산출)
--   ▸ 저장소 루트에서 실행할 것 (\copy 상대경로)
--
--   왜 population_grid(V5)를 쓰지 않는가:
--     V5의 population_grid는 **격자** 테이블이다. 그런데 SGIS OpenAPI3는 격자 인구를
--     제공하지 않고 행정구역 단위만 준다. 행정동 폴리곤을 격자 테이블에 넣으면
--     이름과 내용이 어긋나므로 별도 테이블로 둔다.
--     RTM 격자 값은 Phase 4-B에서 **행정동 ∩ 격자 면적 비례 배분**으로 만든다.
--     → 한계: 행정동 내부 인구 분포가 균일하다고 가정하게 된다(문서에 명시).
--
--   연도를 PK에 넣어 다년치를 쌓을 수 있게 한다(2020~2024 제공, 2025는 아직 없음).
-- =====================================================================

CREATE TABLE IF NOT EXISTS digital_twin.admin_population (
    adm_cd       varchar(10)      NOT NULL,   -- SGIS 행정동 코드
    adm_nm       varchar(200)     NOT NULL,   -- 행정동명 (병합 시 'A+B')
    year         smallint         NOT NULL,
    tot_ppltn    integer          NULL,       -- 총인구
    ppltn_dnsty  double precision NULL,       -- 인구밀도(명/㎢)
    avg_age      double precision NULL,       -- 평균연령
    tot_family   integer          NULL,       -- 세대수
    tot_house    integer          NULL,       -- 주택수
    employee_cnt integer          NULL,       -- 종사자수
    corp_cnt     integer          NULL,       -- 사업체수
    props        jsonb            NULL,
    geom         geometry(MultiPolygon, 4326) NOT NULL,
    CONSTRAINT admin_population_pk PRIMARY KEY (adm_cd, year)
);

COMMENT ON TABLE  digital_twin.admin_population IS
    'SGIS 행정동 인구·경계 (RTM 인구 요인 / 격자 값은 면적 비례 배분으로 산출)';
COMMENT ON COLUMN digital_twin.admin_population.employee_cnt IS
    '종사자수 — employee_cnt/tot_ppltn 을 주야간 지표로 쓴다(종사자 많고 거주인구 적으면 주간 활동 중심)';
COMMENT ON COLUMN digital_twin.admin_population.adm_nm IS
    '행정동명. 통계는 쪼개져 있고 경계는 합쳐진 경우(녹산동+신호동) 이름을 +로 이어 붙인다';

CREATE INDEX IF NOT EXISTS idx_admin_population_geom ON digital_twin.admin_population USING gist (geom);
CREATE INDEX IF NOT EXISTS idx_admin_population_year ON digital_twin.admin_population (year);

-- 재실행 가능하게: 같은 연도 적재분을 지우고 다시 넣는다
CREATE TEMP TABLE pop_stage (
    adm_cd       text,
    adm_nm       text,
    year         text,
    tot_ppltn    text,
    ppltn_dnsty  text,
    avg_age      text,
    tot_family   text,
    tot_house    text,
    employee_cnt text,
    corp_cnt     text,
    ewkt         text
);

\copy pop_stage FROM 'data/processed/admin_population.csv' WITH (FORMAT csv, HEADER true)

DELETE FROM digital_twin.admin_population
 WHERE year IN (SELECT DISTINCT year::smallint FROM pop_stage);

INSERT INTO digital_twin.admin_population
    (adm_cd, adm_nm, year, tot_ppltn, ppltn_dnsty, avg_age,
     tot_family, tot_house, employee_cnt, corp_cnt, props, geom)
SELECT
    s.adm_cd,
    s.adm_nm,
    s.year::smallint,
    nullif(s.tot_ppltn, '')::double precision::integer,
    nullif(s.ppltn_dnsty, '')::double precision,
    nullif(s.avg_age, '')::double precision,
    nullif(s.tot_family, '')::double precision::integer,
    nullif(s.tot_house, '')::double precision::integer,
    nullif(s.employee_cnt, '')::double precision::integer,
    nullif(s.corp_cnt, '')::double precision::integer,
    jsonb_build_object(
        'source', 'SGIS OpenAPI3 stats/population + boundary/hadmarea',
        'geom_repaired', NOT ST_IsValid(ST_GeomFromEWKT(s.ewkt))),
    -- 원천 폴리곤에 자기교차(Ring Self-intersection)가 있는 행이 있다.
    -- 그냥 걸러내면 다대1동(사하구, 인구 35,764) 하나가 빠져 그 구 인구 요인이
    -- 과소평가된다 → ST_MakeValid로 보정한다(building·admin_emd 적재 때와 동일 처리).
    -- MakeValid 결과가 GeometryCollection일 수 있어 폴리곤(타입 3)만 추출한 뒤 Multi로 통일.
    ST_Multi(ST_CollectionExtract(ST_MakeValid(ST_GeomFromEWKT(s.ewkt)), 3))
FROM pop_stage s;

DROP TABLE pop_stage;
