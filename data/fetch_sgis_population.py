# -*- coding: utf-8 -*-
"""SGIS 행정동 인구 + 경계 수집 (Phase 1-C — RTM 인구 요인)

왜 격자가 아니라 행정동인가:
  SGIS OpenAPI3는 격자 단위 인구를 주지 않는다(`stats/population.json`은 행정구역 단위).
  대신 **부산 행정동 206개**의 인구 통계와 경계 폴리곤을 받을 수 있다.
  RTM 격자 값은 Phase 4-B에서 **행정동 폴리곤 ∩ 격자의 면적 비례 배분**으로 만든다.
  → 한계: 행정동 내부 분포는 균일하다고 가정하게 된다. REPORT/문서에 명시할 것.

수집 항목 (성별·연령 분해는 API가 제공하지 않음 — gender 파라미터는 412 거부)
  tot_ppltn 총인구 / ppltn_dnsty 인구밀도 / avg_age 평균연령
  tot_family 세대수 / tot_house 주택수 / employee_cnt 종사자수 / corp_cnt 사업체수
  ▸ employee_cnt / tot_ppltn 을 **주야간 지표**로 쓸 수 있다
    (종사자가 많고 거주인구가 적으면 주간 활동 중심 지역)

좌표계: 경계는 **EPSG:5179(UTM-K)** 로 온다 → pyproj로 4326 변환 필수.

보안: 인증정보는 `.env`의 SGIS_ID / SGIS_SECRET_KEY에서만 읽는다.

출력: processed/admin_population.csv (EWKT MULTIPOLYGON)
실행: py data/fetch_sgis_population.py [연도]      기본 2024 (2025는 아직 없음)
"""
import csv
import json
import os
import sys
import urllib.parse
import urllib.request

from pyproj import Transformer

sys.stdout.reconfigure(encoding='utf-8')
BASE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(BASE)
OUT_DIR = os.path.join(BASE, 'processed')

API = 'https://sgisapi.kostat.go.kr/OpenAPI3/'
BUSAN_CD = '21'          # SGIS 시도 코드 (부산). 행정동까지는 low_search=2
TO_WGS84 = Transformer.from_crs('EPSG:5179', 'EPSG:4326', always_xy=True)

STAT_FIELDS = ['tot_ppltn', 'ppltn_dnsty', 'avg_age', 'tot_family',
               'tot_house', 'employee_cnt', 'corp_cnt']


def env(key):
    for line in open(os.path.join(ROOT, '.env'), encoding='utf-8'):
        if line.startswith(key + '='):
            return line.split('=', 1)[1].strip()
    raise SystemExit(f'.env 에 {key} 가 없습니다')


def token():
    q = urllib.parse.urlencode({'consumer_key': env('SGIS_ID'),
                                'consumer_secret': env('SGIS_SECRET_KEY')})
    r = json.load(urllib.request.urlopen(f'{API}auth/authentication.json?{q}', timeout=20))
    if r.get('errCd') != 0:
        raise SystemExit(f"SGIS 인증 실패: {r.get('errMsg')}")
    return r['result']['accessToken']


def call(tok, path, **params):
    u = f'{API}{path}?' + urllib.parse.urlencode({'accessToken': tok, **params})
    return json.load(urllib.request.urlopen(u, timeout=180))


def num(v):
    """'N/A'·빈값은 빈 문자열로. 숫자는 그대로 문자열 유지(적재 시 캐스팅)."""
    v = (v or '').strip()
    return '' if v in ('', 'N/A', 'null') else v


def ring_ewkt(ring):
    """5179 좌표 링 → '4326 x y, ...' 문자열. 닫히지 않은 링은 닫는다."""
    pts = [TO_WGS84.transform(x, y) for x, y in ring]
    if pts[0] != pts[-1]:
        pts.append(pts[0])
    return '(' + ', '.join(f'{lon:.7f} {lat:.7f}' for lon, lat in pts) + ')'


def to_multipolygon_ewkt(geom):
    """GeoJSON Polygon/MultiPolygon → EWKT MULTIPOLYGON (모두 Multi로 통일)."""
    if geom['type'] == 'Polygon':
        polys = [geom['coordinates']]
    elif geom['type'] == 'MultiPolygon':
        polys = geom['coordinates']
    else:
        return None
    body = ', '.join('(' + ', '.join(ring_ewkt(r) for r in poly) + ')' for poly in polys)
    return f'SRID=4326;MULTIPOLYGON({body})'


def main(year='2024'):
    os.makedirs(OUT_DIR, exist_ok=True)
    tok = token()

    stats = call(tok, 'stats/population.json',
                 year=year, adm_cd=BUSAN_CD, low_search='2')['result']
    bounds = call(tok, 'boundary/hadmarea.geojson',
                  year=year, adm_cd=BUSAN_CD, low_search='2')['features']
    print(f'{year}년 부산 — 통계 {len(stats)}건 / 경계 {len(bounds)}건')

    geom_by_cd = {}
    for f in bounds:
        cd = (f.get('properties') or {}).get('adm_cd')
        ewkt = to_multipolygon_ewkt(f['geometry'])
        if cd and ewkt:
            geom_by_cd[cd] = ewkt

    # 통계와 경계의 코드 체계가 어긋나는 경우가 있다(2026-08-23 확인):
    #   통계는 녹산동(21120561)·신호동(21120562)으로 쪼개져 있으나 경계는 21120560 하나뿐.
    #   그냥 버리면 강서구 인구 39,388명이 사라져 그 구 인구 요인이 과소평가된다
    #   (보안등 동구 결측과 같은 유형의 편향) → **앞 7자리가 같은 경계로 합친다.**
    def resolve(cd):
        if cd in geom_by_cd:
            return cd
        for gc in geom_by_cd:
            if gc[:7] == cd[:7]:
                return gc
        return None

    merged, no_geom = {}, []
    for s in stats:
        cd = s.get('adm_cd')
        gc = resolve(cd)
        if gc is None:
            no_geom.append((cd, s.get('adm_nm')))
            continue
        cur = merged.setdefault(gc, {'adm_cd': gc, 'names': [], 'year': year,
                                     'ewkt': geom_by_cd[gc],
                                     **{k: 0.0 for k in STAT_FIELDS}, '_n': 0})
        cur['names'].append(s.get('adm_nm', ''))
        cur['_n'] += 1
        for k in STAT_FIELDS:
            v = num(s.get(k))
            if v:
                cur[k] += float(v)

    rows = []
    for m in merged.values():
        # 합산이 맞는 항목(인구·세대·주택·종사자·사업체)과 평균이어야 하는 항목(평균연령·밀도)을 구분
        n = max(m['_n'], 1)
        row = {'adm_cd': m['adm_cd'], 'adm_nm': '+'.join(m['names']), 'year': m['year']}
        for k in STAT_FIELDS:
            v = m[k] / n if k in ('avg_age', 'ppltn_dnsty') else m[k]
            row[k] = f'{v:.1f}'.rstrip('0').rstrip('.') if v else ''
        row['ewkt'] = m['ewkt']
        rows.append(row)

    out = os.path.join(OUT_DIR, 'admin_population.csv')
    with open(out, 'w', encoding='utf-8-sig', newline='') as f:
        w = csv.DictWriter(f, fieldnames=['adm_cd', 'adm_nm', 'year'] + STAT_FIELDS + ['ewkt'])
        w.writeheader()
        w.writerows(rows)

    total = sum(int(float(r['tot_ppltn'])) for r in rows if r['tot_ppltn'])
    print(f'=> {out} ({len(rows)}행)  총인구 합계 {total:,}')
    if no_geom:
        print(f'   ! 경계 없어 제외 {len(no_geom)}건: {no_geom}')
    # 경계만 있고 통계가 없는 경우도 알려준다
    orphan = set(geom_by_cd) - {r['adm_cd'] for r in rows}
    if orphan:
        print(f'   ! 통계 없는 경계 {len(orphan)}건: {sorted(orphan)[:5]}')


if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else '2024')
