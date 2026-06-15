-- =====================================================================
-- V2: facility_type 코드 시드
--   코드 값은 원천 CSV의 facility_type 컬럼 값을 그대로 사용
--   (기존 테이블명 매핑: road_sign→road_mark(노면문자), safety_signal→safety_sign(안전표지),
--    train_info→steel_pole(철주))
--   code 11: 구 단속CCTV(illegal_parking_cctv) → 전국어린이보호구역표준데이터 대체로
--            child_protection_zone(어린이보호구역)로 변경 (2026-06-15)
-- =====================================================================

INSERT INTO digital_twin.facility_type (code, name, name_ko, category, category_ko) VALUES
    (0,  'traffic_lane',         '차선',                       'traffic',       '교통 인프라'),
    (1,  'safety_sign',          '안전표지',                   'road_facility', '도로 시설물'),
    (2,  'road_direction',       '노면방향표시',               'traffic',       '교통 인프라'),
    (3,  'road_mark',            '노면문자표시',               'traffic',       '교통 인프라'),
    (4,  'steel_pole',           '철주',                       'road_facility', '도로 시설물'),
    (5,  'attachment_board',     '부착대',                     'road_facility', '도로 시설물'),
    (6,  'safety_cctv',          '방범용 CCTV',                'safety',        '안전·방범'),
    (7,  'safety_zone',          '안전지대',                   'road_facility', '도로 시설물'),
    (8,  'cross_road',           '교차로',                     'traffic',       '교통 인프라'),
    (9,  'city_park',            '도시공원',                   'living',        '생활공간'),
    (10, 'smart_shelter',        '스마트 버스쉘터',            'transit',       '대중교통'),
    (11, 'child_protection_zone', '어린이보호구역',            'safety',        '안전·방범'),
    (12, 'its_cctv',             'ITS 교통 CCTV',              'traffic',       '교통 인프라')
ON CONFLICT (code) DO UPDATE SET
    name        = EXCLUDED.name,
    name_ko     = EXCLUDED.name_ko,
    category    = EXCLUDED.category,
    category_ko = EXCLUDED.category_ko;
