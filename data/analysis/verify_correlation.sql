\encoding UTF8
-- =====================================================================
-- 실측 대조: 구·군별 환경 취약도 vs 경찰서별 절도 (Phase 4-B 검증)
--
--   실행: psql -h localhost -U busan_app -d postgres -f data/analysis/verify_correlation.sql
--   이 파일이 REPORT.md 수치의 유일한 출처다. 손으로 쿼리를 다시 짜지 않는다.
--
--   경찰서 16개는 구·군 16개와 이름으로 1:1 대응한다
--   (수영서가 따로 있어 남부서는 남구만 담당 — 관할 경계 없이 구·군 집계로 대조 가능).
--
--   ⚠ 구·군 코드를 범위로 잡지 않고 16행을 손으로 박는다.
--     기장군만 21510으로 건너뛰기 때문에 21010~21150 범위로 잡으면 조용히 빠진다.
--     2026-08-25 실제로 발생해 n=15로 계산됐다.
-- =====================================================================

-- 경찰서별 5대범죄 (원본: data/경찰청 부산광역시경찰청_경찰서별 5대 범죄 발생 현황_20251231.csv, 2025)
-- CSV가 CP949라 \copy가 번거롭고 16행뿐이라 값으로 박는다. 수정 시 원본 CSV와 대조할 것.
DROP TABLE IF EXISTS tmp_police;
CREATE TEMP TABLE tmp_police (
    sgg_cd  varchar(5) PRIMARY KEY,   -- admin_population.adm_cd 앞 5자리
    station text NOT NULL,            -- 경찰서명
    sgg_nm  text NOT NULL,            -- 대응 구·군
    theft   int  NOT NULL             -- 절도 발생 건수
);

INSERT INTO tmp_police VALUES
                           ('21010', '중부',   '중구',      643),
                           ('21020', '서부',   '서구',      741),
                           ('21030', '동부',   '동구',      572),
                           ('21040', '영도',   '영도구',    457),
                           ('21050', '부산진', '부산진구', 2624),
                           ('21060', '동래',   '동래구',   1279),
                           ('21070', '남부',   '남구',     1097),
                           ('21080', '북부',   '북구',      921),
                           ('21090', '해운대', '해운대구', 1636),
                           ('21100', '사하',   '사하구',    836),
                           ('21110', '금정',   '금정구',    718),
                           ('21120', '강서',   '강서구',    352),
                           ('21130', '연제',   '연제구',    898),
                           ('21140', '수영',   '수영구',    304),
                           ('21150', '사상',   '사상구',    683),
                           ('21510', '기장',   '기장군',    595);

-- 검증 1: 16개 코드가 admin_population에 전부 붙는가
--   dong_cnt = 0 인 행이 하나라도 있으면 매핑이 깨진 것이다(기장군 사고의 재발).
--   dong_cnt 합계는 205, pop 합계는 3,257,256이어야 한다.
SELECT p.sgg_cd,
       p.sgg_nm,
       p.station,
       p.theft,
       count(ap.adm_cd)  AS dong_cnt,
       sum(ap.tot_ppltn) AS pop
FROM tmp_police p
         LEFT JOIN digital_twin.admin_population ap
                   ON ap.year = 2024
                       AND substring(ap.adm_cd, 1, 5) = p.sgg_cd
GROUP BY p.sgg_cd, p.sgg_nm, p.station, p.theft
ORDER BY p.sgg_cd;

-- =====================================================================
-- 검증 2: 격자 → 구·군 귀속 + 미매칭 진단
--
--   격자 centroid가 행정동 폴리곤 안에 있으면 그 동의 구·군으로 귀속한다.
--   밖이면(해안 경계·매립지) 폴리곤 매칭이 실패한다 — 13,439 중 901개(6.7%).
--   이 901개를 버릴지 최근접 구·군에 붙일지는 아래 진단 결과를 보고 정한다.
--   특정 구에 몰려 있고 점수대가 다르면 버리는 순간 그 구가 왜곡된다.
-- =====================================================================

DROP TABLE IF EXISTS tmp_grid_sgg;
CREATE TEMP TABLE tmp_grid_sgg AS
SELECT g.id AS grid_id,
       -- 폴리곤 안에 들어간 경우의 구·군 (정상 귀속)
       substring(ap.adm_cd, 1, 5) AS sgg_in,
       -- 미매칭일 때만 최근접 행정동을 찾는다 (전체에 KNN을 돌리면 느리다)
       CASE WHEN ap.adm_cd IS NULL THEN
                (SELECT substring(a2.adm_cd, 1, 5)
                 FROM digital_twin.admin_population a2
                 WHERE a2.year = 2024
                 ORDER BY a2.geom <-> g.centroid
                 LIMIT 1)
           END AS sgg_near
FROM digital_twin.risk_grid g
         LEFT JOIN digital_twin.admin_population ap
                   ON ap.year = 2024
                       AND ST_Contains(ap.geom, g.centroid);

-- 미매칭이 어느 구에 몰려 있는가, 그리고 그 격자들의 취약도가 다른가
SELECT p.sgg_nm,
       count(*) FILTER (WHERE t.sgg_in IS NOT NULL) AS matched,
       count(*) FILTER (WHERE t.sgg_in IS NULL)     AS unmatched,
       round(avg(s.score) FILTER (WHERE t.sgg_in IS NOT NULL)::numeric, 3) AS avg_matched,
       round(avg(s.score) FILTER (WHERE t.sgg_in IS NULL)::numeric, 3)     AS avg_unmatched
FROM tmp_grid_sgg t
         JOIN digital_twin.risk_grid_score s
              ON s.grid_id = t.grid_id AND s.crime_type = 'bike_env_vuln'
         JOIN tmp_police p
              ON p.sgg_cd = coalesce(t.sgg_in, t.sgg_near)
GROUP BY p.sgg_nm
ORDER BY unmatched DESC;

-- =====================================================================
-- 검증 3: 구·군별 집계 + Spearman 순위 상관
--
--   미매칭 901개는 **제외**한다 (검증 2 결과 근거).
--     · 강서 347 · 기장 169 · 사하 130 — 해안·매립지에 몰려 있다
--     · 평균 점수가 매칭분보다 일관되게 낮다(강서 0.124 vs 0.151 등).
--       인구가 귀속되지 않아 표적지수가 하한 0.15에 고정된 탓이다.
--       즉 낮은 점수가 "안전하다"가 아니라 "데이터가 없다"를 뜻한다.
--     · 최근접 구에 붙이면 면적 큰 구의 평균이 데이터 부재 때문에 더 내려간다.
--   93.3%(12,538개)로 집계해도 구별 최소 표본이 중구 48개라 대조에 충분하다.
-- =====================================================================

DROP TABLE IF EXISTS tmp_sgg_agg;
CREATE TEMP TABLE tmp_sgg_agg AS
SELECT p.sgg_cd,
       p.sgg_nm,
       p.theft,
       count(*)                                  AS grid_cnt,
       sum(s.score)                              AS score_sum,
       avg(s.score)                              AS score_avg,
       count(*) FILTER (WHERE s.grade = 'R')     AS r_cnt,
       -- 인구가 배분된 격자만의 평균. 산·농지·항만의 빈 격자가 평균을 희석하는 것을 제거한다.
       avg(s.score) FILTER (WHERE f.pop_est > 0) AS score_avg_pop,
       (SELECT sum(ap.tot_ppltn)
        FROM digital_twin.admin_population ap
        WHERE ap.year = 2024
          AND substring(ap.adm_cd, 1, 5) = p.sgg_cd) AS pop
FROM tmp_grid_sgg t
         JOIN digital_twin.risk_grid_score s
              ON s.grid_id = t.grid_id AND s.crime_type = 'bike_env_vuln'
         JOIN digital_twin.risk_grid_factor f ON f.grid_id = t.grid_id
         JOIN tmp_police p ON p.sgg_cd = t.sgg_in
WHERE t.sgg_in IS NOT NULL
GROUP BY p.sgg_cd, p.sgg_nm, p.theft;

-- 순위 변환. 값이 모두 달라 동점 보정은 불필요하지만, 생기면 rank()는 최소순위를 준다.
DROP TABLE IF EXISTS tmp_rank;
CREATE TEMP TABLE tmp_rank AS
SELECT a.*,
       a.theft::double precision / a.pop * 100000 AS theft_rate,
       rank() OVER (ORDER BY a.theft)                                       AS rk_theft,
       rank() OVER (ORDER BY a.theft::double precision / a.pop)             AS rk_rate,
       rank() OVER (ORDER BY a.score_sum)                                   AS rk_sum,
       rank() OVER (ORDER BY a.score_avg)                                   AS rk_avg,
       rank() OVER (ORDER BY a.score_avg_pop)                               AS rk_avg_pop,
       rank() OVER (ORDER BY a.r_cnt)                                       AS rk_rcnt,
       rank() OVER (ORDER BY a.grid_cnt)                                    AS rk_grid,
       rank() OVER (ORDER BY a.pop)                                         AS rk_pop
FROM tmp_sgg_agg a;

-- 구·군별 원표 (REPORT.md 표의 출처)
SELECT sgg_nm,
       theft,
       round(theft_rate::numeric, 1)    AS theft_per_100k,
       grid_cnt,
       r_cnt,
       round(score_avg::numeric, 3)     AS score_avg,
       round(score_avg_pop::numeric, 3) AS score_avg_pop,
       pop
FROM tmp_rank
ORDER BY theft_rate DESC;

-- Spearman = 순위끼리의 Pearson 상관
SELECT 'score_sum     vs theft'      AS pair, round(corr(rk_sum,     rk_theft)::numeric, 3) AS spearman FROM tmp_rank
UNION ALL
SELECT 'score_avg     vs theft',           round(corr(rk_avg,     rk_theft)::numeric, 3) FROM tmp_rank
UNION ALL
SELECT 'score_avg     vs theft_rate',      round(corr(rk_avg,     rk_rate)::numeric, 3)  FROM tmp_rank
UNION ALL
SELECT 'score_avg_pop vs theft_rate',      round(corr(rk_avg_pop, rk_rate)::numeric, 3)  FROM tmp_rank
UNION ALL
SELECT 'r_cnt         vs theft',           round(corr(rk_rcnt,    rk_theft)::numeric, 3) FROM tmp_rank
UNION ALL
SELECT '(base) grid_cnt vs theft',         round(corr(rk_grid,    rk_theft)::numeric, 3) FROM tmp_rank
UNION ALL
SELECT '(base) pop      vs theft',         round(corr(rk_pop,     rk_theft)::numeric, 3) FROM tmp_rank;
