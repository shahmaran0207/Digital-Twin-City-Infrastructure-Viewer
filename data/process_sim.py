# -*- coding: utf-8 -*-
"""
시뮬레이션/경계 데이터 가공 (Phase 1-R, 2~4단계)

설계: plans/data-rebuild.md

대상 (모두 shapefile → EWKT CSV):
  - building   : AL_D162_26_20260115.shp  (폴리곤 23만, EPSG:5186 → 4326)
  - road_node  : MOCT_NODE.shp            (전국 포인트 → 부산 추출, EPSG:5186 → 4326)
  - road_link  : MOCT_LINK.shp            (전국 라인 → 부산 추출, EPSG:5186 → 4326)
  - admin_emd  : emd.shp                   (전국 폴리곤 → 부산 추출, EPSG:5179 → 4326)

공통 원칙:
  - shapely 미설치 → pyshp __geo_interface__ 로 링 구조(외곽/홀, 멀티) 해석 후 직접 EWKT 생성
  - 좌표 변환은 pyproj Transformer (always_xy=True), 출력은 lon lat 순 7자리
  - 부산 추출: 노드/emd 는 부산 BBox/코드로 직접, 링크는 '양끝 노드 모두 부산' 인 것만(라우팅 무결성)

실행: py data/process_sim.py [building|road|admin|all]   (기본 all)
"""
import csv
import io
import json
import os
import sys
import zipfile

from pyproj import Transformer
import shapefile  # pyshp

sys.stdout.reconfigure(encoding='utf-8')
BASE = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.join(BASE, 'processed')
os.makedirs(OUT_DIR, exist_ok=True)

# 부산 추출용 BBox (4326). 가덕도(서쪽)·기장(동/북)까지 포함하는 넉넉한 범위
BUSAN_LON_MIN, BUSAN_LON_MAX = 128.70, 129.40
BUSAN_LAT_MIN, BUSAN_LAT_MAX = 34.85, 35.45

# 좌표계 → 4326 변환기 (always_xy: 입력/출력 모두 경도,위도 순)
TF_5186 = Transformer.from_crs('EPSG:5186', 'EPSG:4326', always_xy=True)  # building, road
TF_5179 = Transformer.from_crs('EPSG:5179', 'EPSG:4326', always_xy=True)  # emd

# 부산 시군구 법정동코드 앞5자리 → 시군구명 (admin_emd.sigungu 채움용)
SIGUNGU_BY_CODE = {
    '26110': '중구', '26140': '서구', '26170': '동구', '26200': '영도구',
    '26230': '부산진구', '26260': '동래구', '26290': '남구', '26320': '북구',
    '26350': '해운대구', '26380': '사하구', '26410': '금정구', '26440': '강서구',
    '26470': '연제구', '26500': '수영구', '26530': '사상구', '26710': '기장군',
}


# ---------------------------------------------------------------------------
# EWKT 생성 헬퍼 (shapely 없이 pyshp __geo_interface__ + pyproj 로 직접 조립)
# ---------------------------------------------------------------------------
def _xform_ring(transformer, ring):
    """링(좌표 리스트)을 변환 후 'lon lat, lon lat ...' 문자열로."""
    xs = [pt[0] for pt in ring]
    ys = [pt[1] for pt in ring]
    lons, lats = transformer.transform(xs, ys)
    return ', '.join(f'{lo:.7f} {la:.7f}' for lo, la in zip(lons, lats))


def polygon_to_ewkt(shape, transformer):
    """pyshp 폴리곤 shape → SRID=4326;MULTIPOLYGON(...) EWKT.
    __geo_interface__ 가 외곽/홀·멀티 구조를 처리해 준다."""
    geo = shape.__geo_interface__
    gtype = geo['type']
    if gtype == 'Polygon':
        polys = [geo['coordinates']]            # 단일 폴리곤 → 멀티로 승격
    elif gtype == 'MultiPolygon':
        polys = geo['coordinates']
    else:
        return None
    poly_strs = []
    for rings in polys:
        ring_strs = [f'({_xform_ring(transformer, r)})' for r in rings if len(r) >= 4]
        if ring_strs:
            poly_strs.append('(' + ', '.join(ring_strs) + ')')
    if not poly_strs:
        return None
    return 'SRID=4326;MULTIPOLYGON(' + ', '.join(poly_strs) + ')'


def line_to_ewkt(shape, transformer):
    """pyshp 라인 shape → SRID=4326;LINESTRING(...) EWKT.
    멀티파트면 모든 파트 좌표를 끝점 보존하며 이어붙임(노드 토폴로지 유지)."""
    pts = shape.points
    if len(pts) < 2:
        return None
    return 'SRID=4326;LINESTRING(' + _xform_ring(transformer, pts) + ')'


def open_shp(zpath, base, enc='cp949'):
    z = zipfile.ZipFile(os.path.join(BASE, zpath))
    return shapefile.Reader(
        shp=io.BytesIO(z.read(base + '.shp')),
        dbf=io.BytesIO(z.read(base + '.dbf')),
        shx=io.BytesIO(z.read(base + '.shx')),
        encoding=enc)


def write_csv(name, header, rows):
    path = os.path.join(OUT_DIR, name)
    with open(path, 'w', encoding='utf-8-sig', newline='') as f:
        w = csv.writer(f)
        w.writerow(header)
        w.writerows(rows)
    print(f'=> {path} ({len(rows)} rows)')
    return path


# ---------------------------------------------------------------------------
# 2단계: building
# ---------------------------------------------------------------------------
# A* 필드 매핑 (data-rebuild.md): 의미가 확정된 것만 컬럼으로, 나머지는 props
BLD_MAPPED = {
    'A0': 'source_id', 'A3': '_addr', 'A6': '_jibun', 'A12': 'name',
    'A24': 'total_area', 'A28': 'struct', 'A30': 'main_use',
    'A32': 'floors_above', 'A33': 'floors_below', 'A37': 'height_m',
}


def _to_int(v):
    try:
        return int(float(v))
    except (ValueError, TypeError):
        return ''


def _to_float(v):
    try:
        return float(v)
    except (ValueError, TypeError):
        return ''


def _sigungu_from_addr(addr):
    """'부산광역시 중구 대창동1가' → '중구' (구/군 으로 끝나는 토큰)."""
    for tok in str(addr).split():
        if tok.endswith('구') or tok.endswith('군'):
            return tok
    return ''


def process_building():
    sf = open_shp('AL_D162_26_20260115.zip', 'AL_D162_26_20260115')
    fields = [f[0] for f in sf.fields[1:]]
    total = len(sf)
    out, dropped = [], 0
    for i, sr in enumerate(sf.iterShapeRecords()):
        rec = dict(zip(fields, list(sr.record)))
        geom = polygon_to_ewkt(sr.shape, TF_5186)
        if geom is None:                         # 빈/불량 지오메트리 제외
            dropped += 1
            continue
        addr = (str(rec.get('A3', '')).strip() + ' ' + str(rec.get('A6', '')).strip()).strip()
        floors_above = _to_int(rec.get('A32'))
        height_m = _to_float(rec.get('A37'))
        # 3D 압출용 추정높이: 원본 높이>0 이면 그대로, 아니면 지상층수×3.3
        if isinstance(height_m, float) and height_m > 0:
            height_est = round(height_m, 2)
        elif isinstance(floors_above, int) and floors_above > 0:
            height_est = round(floors_above * 3.3, 2)
        else:
            height_est = ''
        # props: 매핑되지 않은 A* 필드 중 비어있지 않은 값(키는 원본 A명 유지)
        props = {}
        for k in fields:
            if k in BLD_MAPPED:
                continue
            v = rec.get(k)
            if v is None or str(v).strip() == '':
                continue
            props[k] = str(v).strip()
        out.append([
            str(rec.get('A0', '')).strip(),          # source_id
            _sigungu_from_addr(rec.get('A3', '')),   # sigungu
            str(rec.get('A12', '')).strip(),         # name
            addr,                                    # addr
            str(rec.get('A30', '')).strip(),         # main_use
            str(rec.get('A28', '')).strip(),         # struct
            floors_above,                            # floors_above
            _to_int(rec.get('A33')),                 # floors_below
            height_m,                                # height_m
            height_est,                              # height_est
            _to_float(rec.get('A24')),               # total_area
            json.dumps(props, ensure_ascii=False) if props else '',
            geom,
        ])
    write_csv('building.csv',
              ['source_id', 'sigungu', 'name', 'addr', 'main_use', 'struct',
               'floors_above', 'floors_below', 'height_m', 'height_est',
               'total_area', 'props', 'geom'],
              out)
    return {'name': 'building', 'total': total, 'kept': len(out), 'dropped': dropped}


# ---------------------------------------------------------------------------
# 3단계: road_node / road_link (부산 추출)
# ---------------------------------------------------------------------------
LINK_MAPPED = {'LINK_ID', 'F_NODE', 'T_NODE', 'LANES', 'ROAD_RANK',
               'ROAD_TYPE', 'MAX_SPD', 'LENGTH', 'ROAD_NAME'}


def process_road():
    # --- 노드: 전국 → 변환 → 부산 BBox 안인 것만 ---
    nsf = open_shp('[2026-01-13]NODELINKDATA.zip', 'MOCT_NODE')
    nfields = [f[0] for f in nsf.fields[1:]]
    node_total = len(nsf)
    ids, xs, ys, recs = [], [], [], []
    for sr in nsf.iterShapeRecords():
        if not sr.shape.points:
            continue
        x, y = sr.shape.points[0]
        rec = dict(zip(nfields, list(sr.record)))
        ids.append(str(rec.get('NODE_ID', '')).strip())
        xs.append(x)
        ys.append(y)
        recs.append(rec)
    lons, lats = TF_5186.transform(xs, ys)       # 일괄 변환

    busan_nodes = set()
    node_rows = []
    for nid, lon, lat, rec in zip(ids, lons, lats, recs):
        if not (BUSAN_LON_MIN <= lon <= BUSAN_LON_MAX and BUSAN_LAT_MIN <= lat <= BUSAN_LAT_MAX):
            continue
        busan_nodes.add(nid)
        node_rows.append([
            nid,
            str(rec.get('NODE_TYPE', '')).strip(),
            str(rec.get('NODE_NAME', '')).strip(),
            f'SRID=4326;POINT({lon:.7f} {lat:.7f})',
        ])
    write_csv('road_node.csv', ['node_id', 'node_type', 'node_name', 'geom'], node_rows)

    # --- 링크: 1차로 dbf만 훑어 '양끝 노드 모두 부산'인 인덱스 선별 → 2차로 지오메트리 ---
    lsf = open_shp('[2026-01-13]NODELINKDATA.zip', 'MOCT_LINK')
    lfields = [f[0] for f in lsf.fields[1:]]
    link_total = len(lsf)
    keep_idx = []
    for i, rec in enumerate(lsf.iterRecords()):
        d = dict(zip(lfields, list(rec)))
        f_node = str(d.get('F_NODE', '')).strip()
        t_node = str(d.get('T_NODE', '')).strip()
        if f_node in busan_nodes and t_node in busan_nodes:
            keep_idx.append(i)

    link_rows, link_dropped_geom = [], 0
    for i in keep_idx:
        rec = dict(zip(lfields, list(lsf.record(i))))
        geom = line_to_ewkt(lsf.shape(i), TF_5186)
        if geom is None:
            link_dropped_geom += 1
            continue
        length_m = _to_float(rec.get('LENGTH'))
        cost = length_m if isinstance(length_m, float) else ''
        props = {}
        for k in lfields:
            if k in LINK_MAPPED:
                continue
            v = rec.get(k)
            if v is None or str(v).strip() == '':
                continue
            props[k] = str(v).strip()
        link_rows.append([
            str(rec.get('LINK_ID', '')).strip(),     # link_id
            str(rec.get('F_NODE', '')).strip(),      # f_node
            str(rec.get('T_NODE', '')).strip(),      # t_node
            cost,                                    # cost = 길이 m
            cost,                                    # reverse_cost = cost (일방통행 정보 없음)
            _to_int(rec.get('LANES')),               # lanes
            str(rec.get('ROAD_RANK', '')).strip(),   # road_rank
            str(rec.get('ROAD_TYPE', '')).strip(),   # road_type
            _to_int(rec.get('MAX_SPD')),             # max_spd
            length_m,                                # length_m
            str(rec.get('ROAD_NAME', '')).strip(),   # road_name
            json.dumps(props, ensure_ascii=False) if props else '',
            geom,
        ])
    write_csv('road_link.csv',
              ['link_id', 'f_node', 't_node', 'cost', 'reverse_cost', 'lanes',
               'road_rank', 'road_type', 'max_spd', 'length_m', 'road_name',
               'props', 'geom'],
              link_rows)
    return [
        {'name': 'road_node', 'total': node_total, 'kept': len(node_rows), 'dropped': 0},
        {'name': 'road_link', 'total': link_total, 'kept': len(link_rows),
         'dropped': link_dropped_geom,
         'note': f'양끝 노드 부산 매칭 {len(keep_idx)}건 중 지오메트리 불량 {link_dropped_geom} 제외'},
    ]


# ---------------------------------------------------------------------------
# 4단계: admin_emd (부산 코드26 추출)
# ---------------------------------------------------------------------------
def process_admin():
    sf = open_shp('emd_20230729.zip', 'emd')
    fields = [f[0] for f in sf.fields[1:]]
    total = len(sf)
    out, dropped = [], 0
    for sr in sf.iterShapeRecords():
        rec = dict(zip(fields, list(sr.record)))
        emd_cd = str(rec.get('EMD_CD', '')).strip()
        if not emd_cd.startswith('26'):           # 부산만
            continue
        geom = polygon_to_ewkt(sr.shape, TF_5179)
        if geom is None:
            dropped += 1
            continue
        out.append([
            emd_cd,
            str(rec.get('EMD_KOR_NM', '')).strip(),
            SIGUNGU_BY_CODE.get(emd_cd[:5], ''),
            geom,
        ])
    write_csv('admin_emd.csv', ['emd_cd', 'emd_ko_nm', 'sigungu', 'geom'], out)
    return {'name': 'admin_emd', 'total': total, 'kept': len(out), 'dropped': dropped}


def main():
    target = sys.argv[1] if len(sys.argv) > 1 else 'all'
    stats = []
    if target in ('all', 'building'):
        print('== building ==')
        stats.append(process_building())
    if target in ('all', 'road'):
        print('== road ==')
        stats.extend(process_road())
    if target in ('all', 'admin'):
        print('== admin ==')
        stats.append(process_admin())

    print('\n== 요약 ==')
    for s in stats:
        line = f"{s['name']:12s} 원본 {s['total']:>9} -> 적재 {s['kept']:>9} (제외 {s['dropped']})"
        if s.get('note'):
            line += f"  [{s['note']}]"
        print(line)


if __name__ == '__main__':
    main()
