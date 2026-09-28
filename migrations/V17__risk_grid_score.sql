\encoding UTF8
-- =====================================================================
-- V17: risk_grid_score — RTM 위험지수 (Phase 4-B)
--   가중치와 근거: data/analysis/output/weights.md (v1, 2026-08-24)
--
--   산식 = Σ(정규화 요인 × 가중치), 합 1.0
--     보관소 0.30 / CCTV부재 0.20 / 보안등부재 0.15 / 심야업소 0.15
--     지구대멂 0.10 / 야간공실화 0.05 / 비상벨멂 0.05
--
--   crime_type 컬럼을 둬서 나중에 유형(절도·폭력)별로 다른 가중치를 쌓을 수 있게 한다.
-- =====================================================================

DROP TABLE IF EXISTS digital_twin.risk_grid_score;

CREATE TABLE digital_twin.risk_grid_score (
                                              grid_id      bigint      NOT NULL,
                                              crime_type   varchar(20) NOT NULL,          -- 'bike_theft' 등
    -- 정규화된 요인값 0~1 (격자 클릭 시 "요소별 기여도" 팝업에 쓴다)
                                              n_rack       double precision NOT NULL,
                                              n_cctv_lack  double precision NOT NULL,
                                              n_light_lack double precision NOT NULL,
                                              n_night_biz  double precision NOT NULL,
                                              n_police_far double precision NOT NULL,
                                              n_vacancy    double precision NOT NULL,
                                              n_bell_far   double precision NOT NULL,
                                              score        double precision NOT NULL,     -- 0~1 가중합
                                              grade        char(1)     NOT NULL,          -- R(위험) Y(주의) G(양호)
                                              CONSTRAINT risk_grid_score_pk PRIMARY KEY (grid_id, crime_type),
                                              CONSTRAINT risk_grid_score_fk FOREIGN KEY (grid_id)
                                                  REFERENCES digital_twin.risk_grid (id) ON DELETE CASCADE
);

COMMENT ON TABLE digital_twin.risk_grid_score IS
    'RTM 위험지수. 회귀 예측이 아니라 환경 요인 가중합 지표 — "예측 정확도" 표현 금지';
COMMENT ON COLUMN digital_twin.risk_grid_score.grade IS
    '분위 기반 등급: 상위 10% R / 다음 20% Y / 나머지 G. 절대 기준이 아니라 상대 순위';

INSERT INTO digital_twin.risk_grid_score
WITH base AS (
    -- 요인값 + 행정동 야간 공실화 지표(격자 중심이 포함된 행정동 값)
    SELECT fa.grid_id,
           fa.rack_cnt, fa.cctv_cnt_100m, fa.light_cnt, fa.night_biz_cnt,
           fa.police_dist_m, fa.bell_dist_m,
           coalesce(ap.employee_cnt::double precision
               / nullif(ap.tot_ppltn, 0), 0) AS vacancy
    FROM digital_twin.risk_grid_factor fa
             JOIN digital_twin.risk_grid g ON g.id = fa.grid_id
             LEFT JOIN digital_twin.admin_population ap
                       ON ap.year = 2024
                           AND ST_Contains(ap.geom, g.centroid)
), bound AS (
    -- 상위 1% 클리핑 기준 (이상치 1개가 전체를 누르는 것 방지)
    SELECT percentile_cont(0.99) WITHIN GROUP (ORDER BY rack_cnt)      AS rack_p99,
    percentile_cont(0.99) WITHIN GROUP (ORDER BY cctv_cnt_100m) AS cctv_p99,
    percentile_cont(0.99) WITHIN GROUP (ORDER BY light_cnt)     AS light_p99,
    percentile_cont(0.99) WITHIN GROUP (ORDER BY night_biz_cnt) AS biz_p99,
    percentile_cont(0.99) WITHIN GROUP (ORDER BY vacancy)       AS vac_p99
FROM base
    ), norm AS (
SELECT b.grid_id,
    -- 개수 요인: 클리핑 후 0~1
    least(b.rack_cnt      / nullif(d.rack_p99, 0), 1.0) AS n_rack,
    least(b.night_biz_cnt / nullif(d.biz_p99, 0), 1.0)  AS n_night_biz,
    least(b.vacancy       / nullif(d.vac_p99, 0), 1.0)  AS n_vacancy,
    -- 부재 요인: 정규화한 뒤 뒤집는다
    1.0 - least(b.cctv_cnt_100m / nullif(d.cctv_p99, 0), 1.0) AS n_cctv_lack,
    1.0 - least(b.light_cnt     / nullif(d.light_p99, 0), 1.0) AS n_light_lack,
    -- 거리 요인: 기준 거리를 넘으면 1.0(보호 없음)
    least(coalesce(b.police_dist_m, 99999) / 2000.0, 1.0) AS n_police_far,
    least(coalesce(b.bell_dist_m,   99999) /  500.0, 1.0) AS n_bell_far
FROM base b CROSS JOIN bound d
    ), scored AS (
SELECT n.*,
    n.n_rack       * 0.30
    + n.n_cctv_lack  * 0.20
    + n.n_light_lack * 0.15
    + n.n_night_biz  * 0.15
    + n.n_police_far * 0.10
    + n.n_vacancy    * 0.05
    + n.n_bell_far   * 0.05 AS score
FROM norm n
    ), graded AS (
-- 분위 기반 등급: 절대 점수로 자르면 전부 G로 몰릴 수 있다
SELECT s.*,
    ntile(10) OVER (ORDER BY s.score DESC) AS decile
FROM scored s
    )
SELECT grid_id, 'bike_theft',
       n_rack, n_cctv_lack, n_light_lack, n_night_biz, n_police_far, n_vacancy, n_bell_far,
       score,
       CASE WHEN decile = 1 THEN 'R'      -- 상위 10%
            WHEN decile <= 3 THEN 'Y'     -- 다음 20%
            ELSE 'G' END
FROM graded;

CREATE INDEX IF NOT EXISTS idx_risk_grid_score_grade ON digital_twin.risk_grid_score (crime_type, grade);
