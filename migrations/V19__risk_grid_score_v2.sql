\encoding UTF8
-- =====================================================================
-- V19: 위험지수 v2 — 표적 곱셈 게이트 (Phase 4-B)
--   v1(가산) 폐기 근거와 v2 산식: data/analysis/output/weights.md
--
--   v1은 "아무것도 없는 곳이 최고 위험"이 됐다. R등급 1,344개 중 1,020개(75.9%)가
--   보관소·심야업소가 모두 0인 격자였고, 부산 최대 유흥가(부평동 심야업소 167)는 G였다.
--   원인: 표적 요인이 희소해(3.8%) 죽고, 부재 요인이 거의 만점(0.93)이라 점수를 지배.
--
--   v2 = 표적지수 × 환경위험
--     표적지수 = 0.15 + 0.85 × max(보관소500m 정규화, 0.5 × 인구 정규화)
--       · 보관소가 없어도 **사람이 살면 자전거가 있다** → 인구를 보조 표적 신호로 쓴다.
--         이 항이 없으면 주거지와 농지가 구분되지 않는다.
--       · 하한 0.15 — 노상·아파트 거치 자전거가 데이터에 없으므로 표적 0인 곳도
--         아주 낮은 위험은 있다. **임의값이라 민감도 분석 대상**이다.
--     환경위험 = CCTV부재 0.30 + 보안등부재 0.21 + 심야업소500m 0.21
--              + 지구대멂 0.14 + 야간공실화 0.07 + 비상벨멂 0.07   (합 1.00)
--       · v1에서 표적(0.30)을 뺀 0.70을 1.0으로 재정규화한 값(비율 유지)
-- =====================================================================

DROP TABLE IF EXISTS digital_twin.risk_grid_score;

CREATE TABLE digital_twin.risk_grid_score (
                                              grid_id      bigint      NOT NULL,
                                              crime_type   varchar(20) NOT NULL,
    -- 정규화 요인값 0~1 (격자 클릭 시 "요소별 기여도" 팝업용)
                                              n_target     double precision NOT NULL,     -- 표적지수 (하한 반영 후)
                                              n_cctv_lack  double precision NOT NULL,
                                              n_light_lack double precision NOT NULL,
                                              n_night_biz  double precision NOT NULL,
                                              n_police_far double precision NOT NULL,
                                              n_vacancy    double precision NOT NULL,
                                              n_bell_far   double precision NOT NULL,
                                              env_risk     double precision NOT NULL,     -- 환경위험 가중합 (표적 곱하기 전)
                                              score        double precision NOT NULL,     -- 표적 × 환경위험
                                              grade        char(1)     NOT NULL,
                                              CONSTRAINT risk_grid_score_pk PRIMARY KEY (grid_id, crime_type),
                                              CONSTRAINT risk_grid_score_fk FOREIGN KEY (grid_id)
                                                  REFERENCES digital_twin.risk_grid (id) ON DELETE CASCADE
);

COMMENT ON TABLE digital_twin.risk_grid_score IS
    'RTM 위험지수 v2 (표적 × 환경위험). 회귀 예측이 아니라 환경 요인 지표 — "예측 정확도" 표현 금지';
COMMENT ON COLUMN digital_twin.risk_grid_score.env_risk IS
    '표적을 곱하기 전 환경위험. score와 함께 보면 "표적이 없어서 낮은지, 환경이 좋아서 낮은지" 구분된다';

INSERT INTO digital_twin.risk_grid_score
WITH base AS (
    SELECT fa.grid_id,
           fa.rack_cnt_500m, fa.biz_cnt_500m, fa.pop_est,
           fa.cctv_cnt_100m, fa.light_cnt,
           fa.police_dist_m, fa.bell_dist_m,
           coalesce(ap.employee_cnt::double precision
               / nullif(ap.tot_ppltn, 0), 0) AS vacancy
    FROM digital_twin.risk_grid_factor fa
             JOIN digital_twin.risk_grid g ON g.id = fa.grid_id
             LEFT JOIN digital_twin.admin_population ap
                       ON ap.year = 2024
                           AND ST_Contains(ap.geom, g.centroid)
), bound AS (
    SELECT percentile_cont(0.99) WITHIN GROUP (ORDER BY rack_cnt_500m) AS rack_p99,
    percentile_cont(0.99) WITHIN GROUP (ORDER BY biz_cnt_500m)  AS biz_p99,
    percentile_cont(0.99) WITHIN GROUP (ORDER BY pop_est)       AS pop_p99,
    percentile_cont(0.99) WITHIN GROUP (ORDER BY cctv_cnt_100m) AS cctv_p99,
    percentile_cont(0.99) WITHIN GROUP (ORDER BY light_cnt)     AS light_p99,
    percentile_cont(0.99) WITHIN GROUP (ORDER BY vacancy)       AS vac_p99
FROM base
    ), norm AS (
SELECT b.grid_id,
    -- 표적: 보관소 신호와 인구 신호(절반 가중) 중 큰 값, 하한 0.15
    0.15 + 0.85 * greatest(
    least(b.rack_cnt_500m / nullif(d.rack_p99, 0), 1.0),
    0.5 * least(b.pop_est / nullif(d.pop_p99, 0), 1.0)
    ) AS n_target,
    -- 환경: 유발 요인
    least(b.biz_cnt_500m / nullif(d.biz_p99, 0), 1.0) AS n_night_biz,
    least(b.vacancy      / nullif(d.vac_p99, 0), 1.0) AS n_vacancy,
    -- 환경: 부재 요인 (정규화 후 반전)
    1.0 - least(b.cctv_cnt_100m / nullif(d.cctv_p99, 0), 1.0)  AS n_cctv_lack,
    1.0 - least(b.light_cnt     / nullif(d.light_p99, 0), 1.0) AS n_light_lack,
    -- 환경: 거리 요인 (기준 초과면 1.0 = 보호 없음)
    least(coalesce(b.police_dist_m, 99999) / 2000.0, 1.0) AS n_police_far,
    least(coalesce(b.bell_dist_m,   99999) /  500.0, 1.0) AS n_bell_far
FROM base b CROSS JOIN bound d
    ), scored AS (
SELECT n.*,
    n.n_cctv_lack  * 0.30
    + n.n_light_lack * 0.21
    + n.n_night_biz  * 0.21
    + n.n_police_far * 0.14
    + n.n_vacancy    * 0.07
    + n.n_bell_far   * 0.07 AS env_risk
FROM norm n
    ), final AS (
SELECT s.*, s.n_target * s.env_risk AS score FROM scored s
    ), graded AS (
SELECT f.*, ntile(10) OVER (ORDER BY f.score DESC) AS decile FROM final f
    )
SELECT grid_id, 'bike_theft',
       n_target, n_cctv_lack, n_light_lack, n_night_biz, n_police_far, n_vacancy, n_bell_far,
       env_risk, score,
       CASE WHEN decile = 1 THEN 'R' WHEN decile <= 3 THEN 'Y' ELSE 'G' END
FROM graded;

CREATE INDEX IF NOT EXISTS idx_risk_grid_score_grade ON digital_twin.risk_grid_score (crime_type, grade);
