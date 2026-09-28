\encoding UTF8
-- =====================================================================
-- 민감도 분석: 가중치 ±20% · 표적 하한 0.15 (Phase 4-B)
--
--   실행: psql -h localhost -U busan_app -d postgres -f data/analysis/sensitivity.sql
--   가중치는 회귀로 추정한 값이 아니라 문헌·판단 기반 초기값이다(weights.md).
--   따라서 "이 값이 맞다"는 증명은 불가능하고, 대신 **조금 흔들어도 결론이 버티는지**를 본다.
--
--   ⚠ DB를 재계산하지 않는다.
--     risk_grid_score에 정규화 요인값(n_cctv_lack 등 6개)과 n_target이 컬럼으로 남아 있어
--     가중치만 바꿔 재조합하면 된다. 표적 하한은 n_target = 0.15 + 0.85X 에서 X를 역산한다.
--     V19를 다시 돌리면 같은 값이 나오는지부터 확인해야 하므로 오히려 검증이 번거로워진다.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. 기준 가중치 (v2 환경위험, weights.md)
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS tmp_base_w;
CREATE TEMP TABLE tmp_base_w (
    factor text PRIMARY KEY,
    w      double precision NOT NULL
);

INSERT INTO tmp_base_w VALUES
    ('cctv',   0.30),   -- CCTV 부재
    ('light',  0.21),   -- 보안등 부재
    ('biz',    0.21),   -- 심야업소 500m
    ('police', 0.14),   -- 지구대 멂
    ('vac',    0.07),   -- 야간 공실화
    ('bell',   0.07);   -- 비상벨 멂

-- ---------------------------------------------------------------------
-- 2. 가중치 시나리오 — 요인 하나를 ±20% 흔들고 나머지를 재정규화(합 1.0 유지)
--
--    한 요인만 키우고 끝내면 합이 1을 넘어 점수 자체가 커진다.
--    그러면 "가중치 때문에 순위가 바뀌었는지" 대신 "전부 커졌는지"를 보게 된다.
--    나머지에 (1 - w_i') / (1 - w_i) 를 곱해 비율을 유지한 채 합을 1.0으로 되돌린다.
--    예) cctv +20% → 0.36, 나머지 합 0.70 → 0.64 (스케일 0.9143)
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS tmp_w;
CREATE TEMP TABLE tmp_w AS
SELECT 'base'::text AS wset, factor, w
FROM tmp_base_w
UNION ALL
SELECT t.factor || CASE WHEN m.mult > 1 THEN '_up' ELSE '_dn' END AS wset,
       b.factor,
       CASE WHEN b.factor = t.factor
                THEN b.w * m.mult
            ELSE b.w * (1.0 - t.w * m.mult) / (1.0 - t.w)
           END AS w
FROM tmp_base_w t
         CROSS JOIN (VALUES (1.2), (0.8)) AS m(mult)
         CROSS JOIN tmp_base_w b;

-- 검산: 모든 시나리오의 가중치 합이 1.0이어야 한다
SELECT wset, round(sum(w)::numeric, 6) AS w_sum
FROM tmp_w
GROUP BY wset
HAVING round(sum(w)::numeric, 6) <> 1.0;

-- ---------------------------------------------------------------------
-- 3. 최종 시나리오 = 가중치셋 + 표적 하한
--    하한 0.15는 임의값이라 가장 취약한 지점이다. 1/3과 2배를 함께 본다.
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS tmp_scn;
CREATE TEMP TABLE tmp_scn (
    scn          text PRIMARY KEY,
    wset         text NOT NULL,
    target_floor double precision NOT NULL
);

INSERT INTO tmp_scn
SELECT DISTINCT wset, wset, 0.15 FROM tmp_w;

INSERT INTO tmp_scn VALUES
    ('floor_0.05', 'base', 0.05),
    ('floor_0.30', 'base', 0.30);

-- ---------------------------------------------------------------------
-- 4. 정규화 요인값을 세로로 펼친다 (가중치와 조인하기 위해)
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS tmp_norm;
CREATE TEMP TABLE tmp_norm AS
SELECT grid_id, 'cctv'   AS factor, n_cctv_lack  AS v FROM digital_twin.risk_grid_score WHERE crime_type = 'bike_env_vuln'
UNION ALL
SELECT grid_id, 'light',  n_light_lack FROM digital_twin.risk_grid_score WHERE crime_type = 'bike_env_vuln'
UNION ALL
SELECT grid_id, 'biz',    n_night_biz  FROM digital_twin.risk_grid_score WHERE crime_type = 'bike_env_vuln'
UNION ALL
SELECT grid_id, 'police', n_police_far FROM digital_twin.risk_grid_score WHERE crime_type = 'bike_env_vuln'
UNION ALL
SELECT grid_id, 'vac',    n_vacancy    FROM digital_twin.risk_grid_score WHERE crime_type = 'bike_env_vuln'
UNION ALL
SELECT grid_id, 'bell',   n_bell_far   FROM digital_twin.risk_grid_score WHERE crime_type = 'bike_env_vuln';

CREATE INDEX ON tmp_norm (factor);

-- 표적지수 원값 역산 — 저장된 n_target에서 하한을 걷어낸다
DROP TABLE IF EXISTS tmp_target;
CREATE TEMP TABLE tmp_target AS
SELECT grid_id,
       (n_target - 0.15) / 0.85 AS x
FROM digital_twin.risk_grid_score
WHERE crime_type = 'bike_env_vuln';

CREATE INDEX ON tmp_target (grid_id);

-- ---------------------------------------------------------------------
-- 5. 시나리오별 점수 = (하한 + (1-하한) × X) × Σ(가중치 × 요인값)
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS tmp_score;
CREATE TEMP TABLE tmp_score AS
SELECT s.scn,
       n.grid_id,
       (s.target_floor + (1.0 - s.target_floor) * t.x) * sum(w.w * n.v) AS score
FROM tmp_scn s
         JOIN tmp_w w      ON w.wset = s.wset
         JOIN tmp_norm n   ON n.factor = w.factor
         JOIN tmp_target t ON t.grid_id = n.grid_id
GROUP BY s.scn, n.grid_id, s.target_floor, t.x;

DROP TABLE IF EXISTS tmp_rank_s;
CREATE TEMP TABLE tmp_rank_s AS
SELECT scn,
       grid_id,
       score,
       row_number() OVER (PARTITION BY scn ORDER BY score DESC) AS rn
FROM tmp_score;

CREATE INDEX ON tmp_rank_s (scn, grid_id);

-- ---------------------------------------------------------------------
-- 6. 결과 — base 대비 상위 격자가 얼마나 유지되는가
--
--    top50   : 지도에서 "가장 취약한 곳"으로 짚을 격자
--    top1344 : R등급 컷(상위 10%) — 등급이 뒤집히는지
--    spearman: 전체 13,439개 순위 상관 (1.0에 가까울수록 안정)
--    base 행은 검산용이다(50/1344/1.0000이 나와야 한다).
-- ---------------------------------------------------------------------
SELECT r.scn,
       count(*) FILTER (WHERE r.rn <= 50   AND b.rn <= 50)   AS top50_keep,
       count(*) FILTER (WHERE r.rn <= 1344 AND b.rn <= 1344) AS r_grade_keep,
       round(100.0 * count(*) FILTER (WHERE r.rn <= 1344 AND b.rn <= 1344) / 1344, 1) AS r_keep_pct,
       round(corr(r.rn, b.rn)::numeric, 4) AS spearman_vs_base
FROM tmp_rank_s r
         JOIN tmp_rank_s b ON b.grid_id = r.grid_id AND b.scn = 'base'
GROUP BY r.scn
ORDER BY top50_keep, r_grade_keep;

-- ---------------------------------------------------------------------
-- 7. 하한을 올리면 v1의 실패 모드가 되살아나는가
--
--    v1이 폐기된 이유는 "표적이 아무것도 없는 격자"가 R등급을 채웠기 때문이다(75.9%).
--    표적 하한을 올린다는 것은 곧 표적 없는 격자에 점수를 더 준다는 뜻이므로,
--    같은 실패로 되돌아가는지 확인해야 한다. 순위 상관만으로는 이게 안 보인다.
-- ---------------------------------------------------------------------
WITH s AS (
    SELECT sc.grid_id,
           sc.grade,
           -- 하한 0.30 시나리오 점수
           (0.30 + 0.70 * ((sc.n_target - 0.15) / 0.85)) * sc.env_risk AS score30,
           f.rack_cnt_500m,
           f.biz_cnt_500m
    FROM digital_twin.risk_grid_score sc
             JOIN digital_twin.risk_grid_factor f ON f.grid_id = sc.grid_id
    WHERE sc.crime_type = 'bike_env_vuln'
), r AS (
    SELECT *, ntile(10) OVER (ORDER BY score30 DESC) AS d30 FROM s
)
SELECT count(*) FILTER (WHERE grade = 'R' AND rack_cnt_500m = 0 AND biz_cnt_500m = 0) AS base_r_notarget,
       count(*) FILTER (WHERE d30 = 1 AND rack_cnt_500m = 0 AND biz_cnt_500m = 0)     AS f30_r_notarget,
       count(*) FILTER (WHERE d30 = 1 AND grade <> 'R')                               AS newly_r,
       count(*) FILTER (WHERE d30 = 1 AND grade <> 'R'
                            AND rack_cnt_500m = 0 AND biz_cnt_500m = 0)               AS newly_r_notarget
FROM r;
