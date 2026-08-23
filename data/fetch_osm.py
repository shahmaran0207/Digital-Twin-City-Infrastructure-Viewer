# -*- coding: utf-8 -*-
"""OSM 자전거·보행 링크 수집 (Overpass API) — Phase 1-C 링크 데이터 A안

표준노드링크는 차량 도로망뿐이라 자전거도로·보도가 없다. OSM으로 보완한다.

라이선스: OpenStreetMap 데이터는 **ODbL** — 출처 표시 + 동일조건 배포 의무.
          README에 "© OpenStreetMap contributors" 표기 필요.

주의:
  · Overpass는 `python-urllib` 기본 User-Agent를 406으로 거부한다 → UA 지정 필수
  · `out geom`을 쓰면 way에 좌표가 붙어 나와 노드를 따로 조회할 필요가 없다
  · 한 번에 다 받으면 타임아웃 → highway 유형별로 나누고, 실패하면 BBox를 4분할 재귀

출력: processed/osm_link.csv (osm_id, highway, name, bicycle, foot, surface, ewkt)

실행: py data/fetch_osm.py
"""
import csv
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

sys.stdout.reconfigure(encoding='utf-8')
BASE = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.join(BASE, 'processed')

OVERPASS = 'https://overpass-api.de/api/interpreter'
UA = {'User-Agent': 'DigitalTwin-Busan/1.0 (local research script)'}
# 부산 BBox (facility 좌표 범위 + 여유) — south, west, north, east
BUSAN = (34.8, 128.5, 35.7, 129.5)
HIGHWAYS = ['cycleway', 'footway', 'path', 'pedestrian']
KEEP_TAGS = ['name', 'bicycle', 'foot', 'surface', 'segregated', 'width']


def query(hw, bbox, timeout=300):
    s, w, n, e = bbox
    q = (f'[out:json][timeout:{timeout}];'
         f'way["highway"="{hw}"]({s},{w},{n},{e});out geom;')
    req = urllib.request.Request(OVERPASS,
                                 data=urllib.parse.urlencode({'data': q}).encode(),
                                 headers=UA)
    with urllib.request.urlopen(req, timeout=timeout + 60) as r:
        return json.load(r).get('elements', [])


def fetch(hw, bbox, depth=0):
    """수집. 실패 원인에 따라 대응을 나눈다.

      · 429(요청 과다) / 504(서버 과부하) → **같은 BBox로 대기 후 재시도**
        분할하면 요청 수가 늘어 상황이 악화된다(2026-08-23 실제로 겪음).
      · 타임아웃 등 그 외 → BBox 4분할 재귀 (응답이 너무 커서 못 받는 경우)
    """
    for attempt in range(4):
        try:
            els = query(hw, bbox)
            print(f'  {"  " * depth}{hw} {bbox} → {len(els):,}')
            return els
        except urllib.error.HTTPError as exc:
            if exc.code in (429, 504) and attempt < 3:
                wait = 60 * (attempt + 1)
                print(f'  {"  " * depth}{hw} {exc.code} → {wait}초 대기 후 재시도')
                time.sleep(wait)
                continue
            last = exc
            break
        except Exception as exc:
            last = exc
            break

    if depth >= 2:
        print(f'  {"  " * depth}! 포기 {hw} {bbox}: {last}')
        return []
    print(f'  {"  " * depth}분할 {hw} {bbox} ({last})')
    s, w, n, e = bbox
    ms, mw = (s + n) / 2, (w + e) / 2
    out = []
    for sub in [(s, w, ms, mw), (s, mw, ms, e), (ms, w, n, mw), (ms, mw, n, e)]:
        time.sleep(10)                          # Overpass 부하 배려 (분할 시 특히)
        out += fetch(hw, sub, depth + 1)
    return out


def to_ewkt(geometry):
    """Overpass geometry(lat/lon 배열) → EWKT LINESTRING. 2점 미만이면 None."""
    pts = [(g['lon'], g['lat']) for g in geometry if 'lat' in g and 'lon' in g]
    # 연속 중복점 제거 (같은 좌표가 반복되면 ST_IsValid 실패)
    dedup = [p for i, p in enumerate(pts) if i == 0 or p != pts[i - 1]]
    if len(dedup) < 2:
        return None
    coords = ', '.join(f'{lon:.7f} {lat:.7f}' for lon, lat in dedup)
    return f'SRID=4326;LINESTRING({coords})'


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    rows, seen, skipped = [], set(), 0
    for hw in HIGHWAYS:
        for el in fetch(hw, BUSAN):
            oid = el.get('id')
            if oid in seen:                     # BBox 분할 시 경계 way가 중복될 수 있다
                continue
            ewkt = to_ewkt(el.get('geometry') or [])
            if not ewkt:
                skipped += 1
                continue
            seen.add(oid)
            tags = el.get('tags') or {}
            rows.append({'osm_id': oid, 'highway': hw, 'ewkt': ewkt,
                         **{t: tags.get(t, '') for t in KEEP_TAGS}})
        time.sleep(20)

    out = os.path.join(OUT_DIR, 'osm_link.csv')
    with open(out, 'w', encoding='utf-8-sig', newline='') as f:
        w = csv.DictWriter(f, fieldnames=['osm_id', 'highway'] + KEEP_TAGS + ['ewkt'])
        w.writeheader()
        w.writerows(rows)
    print(f'\n=> {out} ({len(rows):,}행, 좌표 부족으로 제외 {skipped:,})')

    from collections import Counter
    for hw, c in Counter(r['highway'] for r in rows).most_common():
        print(f'   {hw:12} {c:>7,}')


if __name__ == '__main__':
    main()
