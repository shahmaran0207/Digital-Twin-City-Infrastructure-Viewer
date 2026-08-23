\encoding UTF8
-- =====================================================================
-- V10: 주차장 유형 추가 (Phase 1-C)
--   RTM 요인으로 쓰기 위해 수집(주차장은 차량 대상 절도의 표적 밀집 지점).
--   카테고리는 신설하지 않고 기존 living(생활공간)에 넣는다 —
--   도시공원과 같은 '생활 인프라' 성격이고, 카테고리를 늘리면
--   레이어 패널의 1단 트리만 길어진다.
--
--   ※ 여성안심 데이터(tn_pubr_public_female_safety_...)는 부산 25건뿐이라
--     2026-08-23 사용자 결정으로 수집 대상에서 제외했다(코드 미배정).
-- =====================================================================

INSERT INTO digital_twin.facility_type (code, name, name_ko, category, category_ko) VALUES
    (22, 'parking_lot', '주차장', 'living', '생활공간')
ON CONFLICT (code) DO UPDATE SET
    name        = EXCLUDED.name,
    name_ko     = EXCLUDED.name_ko,
    category    = EXCLUDED.category,
    category_ko = EXCLUDED.category_ko;
