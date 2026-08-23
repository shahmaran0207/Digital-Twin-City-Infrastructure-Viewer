\encoding UTF8
-- ^ Windows psql은 기본 클라이언트 인코딩이 UHC(CP949)라 이 줄이 없으면
--   한글 주석·데이터에서 "UHC와 대응되는 문자 코드가 UTF8에 없습니다" 오류가 난다.
--   import_data.ps1은 $env:PGCLIENTENCODING='UTF8'을 설정하므로 무관하지만,
--   psql을 직접 실행하는 경우를 대비해 파일에 박아둔다.

-- =====================================================================
-- V8: 범죄예방·자전거 유형 추가 (Phase 1-C)
--   기존 13종(코드 0~12)에 이어 13번부터 배정한다.
--   신규 카테고리 3종:
--     bicycle          자전거      — 보관소·대여소·자전거도로 (도난 분석의 "보호 대상")
--     crime_prevention 범죄예방    — 비상벨·안심택배함·보안등·지구대 (위험 "저감 요인")
--     business_night   심야업소    — 상권정보의 유흥·숙박·PC방 (위험 "유발 요인")
--
--   ▸ 자전거보관소를 crime_prevention이 아니라 bicycle에 둔 이유:
--     보관소는 방범 시설이 아니라 보호 대상이다. 비상벨과 같은 묶음에 넣으면
--     레이어 필터에서 "켜고 끄는 의미"가 흐려진다.
--   ▸ business_night는 시설물이 아니라 분석 입력이다.
--     프론트 레이어 패널에서 기본 off로 노출한다 (PLAN.md 1-C).
--   ▸ 기존 행(safety_cctv 등)은 재분류하지 않는다. 프론트 색상 팔레트와
--     기존 API 응답에 영향이 가기 때문이다.
-- =====================================================================

INSERT INTO digital_twin.facility_type (code, name, name_ko, category, category_ko) VALUES
    -- 자전거
    (13, 'bicycle_rack',      '자전거보관소',   'bicycle',          '자전거'),
    (14, 'bicycle_station',   '자전거대여소',   'bicycle',          '자전거'),
    -- 범죄예방
    (15, 'emergency_bell',    '안전비상벨',     'crime_prevention', '범죄예방'),
    (16, 'security_light',    '보안등',         'crime_prevention', '범죄예방'),
    (17, 'safe_delivery_box', '안심택배함',     'crime_prevention', '범죄예방'),
    (18, 'police_station',    '지구대·파출소',  'crime_prevention', '범죄예방'),
    -- 심야업소 (분석 입력 — 기본 off)
    (19, 'entertainment_bar', '유흥·단란주점',  'business_night',   '심야업소'),
    (20, 'lodging',           '숙박업소',       'business_night',   '심야업소'),
    (21, 'internet_cafe',     'PC방',           'business_night',   '심야업소')
ON CONFLICT (code) DO UPDATE SET
    name        = EXCLUDED.name,
    name_ko     = EXCLUDED.name_ko,
    category    = EXCLUDED.category,
    category_ko = EXCLUDED.category_ko;

-- V1 주석의 카테고리 목록 갱신 (신규 3종 반영)
COMMENT ON COLUMN digital_twin.facility_type.category IS
    '레이어 카테고리 영문 키 (traffic/safety/road_facility/transit/living/bicycle/crime_prevention/business_night)';
