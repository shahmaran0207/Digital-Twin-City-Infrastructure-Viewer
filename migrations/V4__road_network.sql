-- =====================================================================
-- V4: road_node / road_link — 국가표준노드링크 부산 추출 (교통·대피 시뮬레이션)
--   원천: MOCT_NODE / MOCT_LINK (전국본, 원본 EPSG:5186 → 적재 시 4326 변환)
--   가공 단계에서 부산 BBox로 추출 후 적재
--   pgRouting pgr_dijkstra 직결을 위해 source/target/cost/reverse_cost 컬럼 보유
-- =====================================================================

CREATE EXTENSION IF NOT EXISTS pgrouting;

-- ---------------------------------------------------------------
-- 도로 노드 (교차점)
-- ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS digital_twin.road_node (
    id        bigint GENERATED ALWAYS AS IDENTITY,
    node_id   varchar(10)  NOT NULL,  -- 원본 NODE_ID
    node_type varchar(3)   NULL,
    node_name varchar(50)  NULL,
    geom      geometry(Point, 4326) NOT NULL,
    CONSTRAINT road_node_pk PRIMARY KEY (id),
    CONSTRAINT road_node_nodeid_uq UNIQUE (node_id)
);

COMMENT ON TABLE  digital_twin.road_node IS '표준노드링크 노드 (부산, pgRouting 정점)';

CREATE INDEX IF NOT EXISTS idx_road_node_geom ON digital_twin.road_node USING gist (geom);

-- ---------------------------------------------------------------
-- 도로 링크 (구간)
-- ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS digital_twin.road_link (
    id           bigint GENERATED ALWAYS AS IDENTITY,
    link_id      varchar(10)      NOT NULL,  -- 원본 LINK_ID
    f_node       varchar(10)      NULL,      -- 원본 시점 노드
    t_node       varchar(10)      NULL,      -- 원본 종점 노드
    source       bigint           NULL,      -- pgRouting 시작 정점 (road_node.id)
    target       bigint           NULL,      -- pgRouting 도착 정점 (road_node.id)
    cost         double precision NULL,      -- 통행비용 (기본: 링크 길이 m)
    reverse_cost double precision NULL,      -- 역방향 비용 (일방통행 반영)
    lanes        integer          NULL,
    road_rank    varchar(3)       NULL,
    road_type    varchar(3)       NULL,
    max_spd      integer          NULL,
    length_m     double precision NULL,
    road_name    varchar(50)      NULL,
    props        jsonb            NULL,
    geom         geometry(LineString, 4326) NOT NULL,
    CONSTRAINT road_link_pk PRIMARY KEY (id),
    CONSTRAINT road_link_linkid_uq UNIQUE (link_id)
);

COMMENT ON TABLE  digital_twin.road_link              IS '표준노드링크 링크 (부산, pgRouting 간선)';
COMMENT ON COLUMN digital_twin.road_link.source       IS 'pgRouting 시작 정점 — road_node.id, 가공 후 채움';
COMMENT ON COLUMN digital_twin.road_link.target       IS 'pgRouting 도착 정점 — road_node.id, 가공 후 채움';
COMMENT ON COLUMN digital_twin.road_link.cost         IS '통행비용(기본 길이 m) — pgr_dijkstra 입력';
COMMENT ON COLUMN digital_twin.road_link.reverse_cost IS '역방향 통행비용 — 일방통행이면 음수/무한';

CREATE INDEX IF NOT EXISTS idx_road_link_geom   ON digital_twin.road_link USING gist (geom);
CREATE INDEX IF NOT EXISTS idx_road_link_source ON digital_twin.road_link (source);
CREATE INDEX IF NOT EXISTS idx_road_link_target ON digital_twin.road_link (target);
