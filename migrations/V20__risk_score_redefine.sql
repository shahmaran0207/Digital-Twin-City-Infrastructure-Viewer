\encoding UTF8
-- =====================================================================
-- V20: 지표 재정의 — "도난 위험 예측" → "환경 취약도 진단" (Phase 4-B)
--
--   실측 검증 결과(2026-08-25, data/analysis/output/REPORT.md):
--     평균 취약도 vs 절도 발생률  -0.179  (음의 상관)
--     인구 단독      vs 절도 총량  +0.818  (우리 지수 +0.386보다 훨씬 강함)
--   원인: CCTV의 **역인과** — 절도가 많았던 곳에 CCTV를 설치했기 때문에
--         "CCTV 부재"가 위험을 거꾸로 가리켰다.
--
--   → 산식(v2)은 그대로 두고 **이름과 설명만 정직하게 고친다.**
--     측정하고 있는 것은 "감시·조명 인프라 부족도"이며, 그건 정책적으로 쓸 수 있는 정보다
--     (어디에 CCTV·보안등을 놓을지). "예측"이라는 표현을 쓰지 않는다.
-- =====================================================================

-- crime_type 값 교체: 'bike_theft'(도난 예측으로 읽힘) → 'bike_env_vuln'(환경 취약도)
UPDATE digital_twin.risk_grid_score
SET crime_type = 'bike_env_vuln'
WHERE crime_type = 'bike_theft';

COMMENT ON TABLE digital_twin.risk_grid_score IS
    '자전거 도난 관점 환경 취약도 (표적 × 환경위험). 절도 발생 예측이 아니다 — '
    '실측 대조에서 발생률과 음의 상관(-0.179)이 나왔고 원인은 CCTV 역인과다. '
    '측정 대상은 "감시·조명 인프라 부족도". 근거: data/analysis/output/REPORT.md';

COMMENT ON COLUMN digital_twin.risk_grid_score.crime_type IS
    '지표 종류. bike_env_vuln = 자전거 도난 관점 환경 취약도';

COMMENT ON COLUMN digital_twin.risk_grid_score.score IS
    '환경 취약도 0~1 = 표적지수 × 환경위험. 절대적 의미 없는 상대 지표 — 등급은 분위 기반';

COMMENT ON COLUMN digital_twin.risk_grid_score.grade IS
    '분위 등급: 상위 10% R / 다음 20% Y / 나머지 G. '
    '"R = 도난이 일어난다"가 아니라 "R = 감시·조명이 가장 부족하다"는 뜻';
