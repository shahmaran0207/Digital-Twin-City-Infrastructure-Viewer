\encoding UTF8
-- =====================================================================
-- V11: road_link 모드 플래그 (Phase 1-C, 링크 데이터 A안)
--
--   A안 = 자전거·보행 네트워크를 별도 테이블로 쪼개지 않고 road_link 하나에 모아
--          모드 허용 플래그로 구분한다. 네트워크가 1개면 pgRouting 쿼리도 하나로 끝나고,
--          Phase 5 교통우회·대피 시뮬레이션이 그대로 재사용된다.
--
--   ① ID 컬럼 폭 확대 (varchar(10) → varchar(20))
--      표준노드링크 ID는 10자리지만 **OSM way/node ID는 10~12자리**라 그대로 넣으면 잘린다.
--      UNIQUE 제약이 걸린 컬럼이므로 잘리면 서로 다른 링크가 충돌한다.
--
--   ② 모드 플래그 + source_type
--      기존 86,896건은 표준노드링크(차량 도로망) → source_type = 'moct'
--      앞으로 들어올 OSM 자전거도로·보도는 'osm'
--
--   ③ 기존 링크 플래그 부여 규칙
--      car  : 전부 true (표준노드링크 자체가 차량 도로망)
--      bike : 고속국도(101)·도시고속국도(102) 제외, 제한속도 80 이상 제외
--      foot : bike와 동일 기준
--      → 자동차전용도로는 법적으로 자전거·보행 통행이 금지된다.
--      ⚠️ 한계: 표준노드링크에는 **보도 유무 정보가 없다.** 따라서 foot_allowed는
--         "법적으로 금지되지 않음"이지 "걸을 만하다"가 아니다. 실제 보행 경로는
--         OSM footway가 들어온 뒤 그쪽을 우선 쓰는 것이 맞다.
--
--   ④ pm_allowed (GENERATED)
--      PM = 자전거도로 ∪ (차도 ∩ 제한속도 30km/h 이하)   ← 2026-08-20 결정
--      OSM 자전거도로는 max_spd가 없으므로 source_type으로 구분한다.
-- =====================================================================

-- ① ID 폭 확대 (road_node 포함 — f_node/t_node와 짝을 맞춘다)
ALTER TABLE digital_twin.road_node ALTER COLUMN node_id TYPE varchar(20);
ALTER TABLE digital_twin.road_link ALTER COLUMN link_id TYPE varchar(20);
ALTER TABLE digital_twin.road_link ALTER COLUMN f_node  TYPE varchar(20);
ALTER TABLE digital_twin.road_link ALTER COLUMN t_node  TYPE varchar(20);

-- ② 모드 플래그 + 출처 구분
ALTER TABLE digital_twin.road_link
    ADD COLUMN IF NOT EXISTS car_allowed  boolean NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS bike_allowed boolean NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS foot_allowed boolean NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS source_type  varchar(8) NOT NULL DEFAULT 'moct';

COMMENT ON COLUMN digital_twin.road_link.car_allowed  IS '차량 통행 가능';
COMMENT ON COLUMN digital_twin.road_link.bike_allowed IS '자전거 통행 가능 (자동차전용도로 제외)';
COMMENT ON COLUMN digital_twin.road_link.foot_allowed IS '보행 가능(법적 금지 아님). 보도 유무는 알 수 없음 — OSM footway 우선';
COMMENT ON COLUMN digital_twin.road_link.source_type  IS '출처: moct(표준노드링크) | osm(OpenStreetMap, ODbL)';

-- ③ 기존 표준노드링크 86,896건에 규칙 적용
UPDATE digital_twin.road_link
   SET car_allowed  = true,
       bike_allowed = (road_rank NOT IN ('101', '102') AND coalesce(max_spd, 0) < 80),
       foot_allowed = (road_rank NOT IN ('101', '102') AND coalesce(max_spd, 0) < 80),
       source_type  = 'moct'
 WHERE source_type = 'moct';

-- ④ PM 통행 가능 (파생 컬럼 — 규칙을 한 곳에 고정해 쿼리마다 재현하지 않는다)
ALTER TABLE digital_twin.road_link
    ADD COLUMN IF NOT EXISTS pm_allowed boolean
    GENERATED ALWAYS AS (
        (bike_allowed AND source_type = 'osm')          -- OSM 자전거도로·보행겸용
        OR (car_allowed AND coalesce(max_spd, 999) <= 30)  -- 저속 차도
    ) STORED;

COMMENT ON COLUMN digital_twin.road_link.pm_allowed IS
    'PM(킥보드) 통행 가능 = 자전거도로 ∪ (차도 ∩ 제한속도 30 이하). 50km/h 기준은 민감도 분석용으로 별도 산출';

-- 모드별 조회가 잦으므로 부분 인덱스 (false 행은 인덱스에 담지 않는다)
CREATE INDEX IF NOT EXISTS idx_road_link_bike ON digital_twin.road_link (bike_allowed) WHERE bike_allowed;
CREATE INDEX IF NOT EXISTS idx_road_link_foot ON digital_twin.road_link (foot_allowed) WHERE foot_allowed;
CREATE INDEX IF NOT EXISTS idx_road_link_pm   ON digital_twin.road_link (pm_allowed)   WHERE pm_allowed;
CREATE INDEX IF NOT EXISTS idx_road_link_src  ON digital_twin.road_link (source_type);
