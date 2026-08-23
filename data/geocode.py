# -*- coding: utf-8 -*-
"""주소 → 좌표 변환 (SGIS 지오코딩 API) — Phase 1-C

대상 두 가지:
  1) 지구대·파출소 94건 — 원천에 좌표 컬럼이 아예 없다
  2) 보안등 5,287건 — 좌표 컬럼이 비어 있어 process_data.py에서 제외된 행

보안: SGIS 인증정보는 `.env`의 SGIS_ID / SGIS_SECRET_KEY에서만 읽는다.
      로컬 스크립트라 프론트에 노출되지 않는다. (CLAUDE.md 보안 원칙)

좌표계 주의: SGIS 지오코딩은 **UTM-K(EPSG:5179)** 로 x, y를 준다.
             DB는 WGS84(4326)이므로 pyproj로 반드시 변환한다.

캐시: 같은 주소를 두 번 호출하지 않도록 processed/geocode_cache.json에 쌓는다.
      중간에 끊겨도 다시 실행하면 이어서 진행된다(5천 건이라 재실행 비용이 큼).

실행: py data/geocode.py 지구대
      py data/geocode.py 보안등
"""
import concurrent.futures
import csv
import glob
import json
import os
import sys
import threading
import time
import urllib.parse
import urllib.request

from pyproj import Transformer

sys.stdout.reconfigure(encoding='utf-8')
BASE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(BASE)
OUT_DIR = os.path.join(BASE, 'processed')
CACHE_PATH = os.path.join(OUT_DIR, 'geocode_cache.json')

AUTH_URL = 'https://sgisapi.kostat.go.kr/OpenAPI3/auth/authentication.json'
GEO_URL = 'https://sgisapi.kostat.go.kr/OpenAPI3/addr/geocode.json'
TO_WGS84 = Transformer.from_crs('EPSG:5179', 'EPSG:4326', always_xy=True)

# 부산 범위 (process_data.py와 동일 기준)
LON_MIN, LON_MAX = 128.5, 129.5
LAT_MIN, LAT_MAX = 34.8, 35.7


def env(key):
    for line in open(os.path.join(ROOT, '.env'), encoding='utf-8'):
        if line.startswith(key + '='):
            return line.split('=', 1)[1].strip()
    raise SystemExit(f'.env 에 {key} 가 없습니다')


def get_token():
    q = urllib.parse.urlencode({'consumer_key': env('SGIS_ID'),
                                'consumer_secret': env('SGIS_SECRET_KEY')})
    r = json.load(urllib.request.urlopen(f'{AUTH_URL}?{q}', timeout=20))
    if r.get('errCd') != 0:
        raise SystemExit(f"SGIS 인증 실패: {r.get('errMsg')}")
    return r['result']['accessToken']


def load_cache():
    if os.path.exists(CACHE_PATH):
        return json.load(open(CACHE_PATH, encoding='utf-8'))
    return {}


def save_cache(cache):
    with open(CACHE_PATH, 'w', encoding='utf-8') as f:
        json.dump(cache, f, ensure_ascii=False)


def normalize(addr):
    """공백 중복 제거. 원천에 '부산광역시 중구  해관로 19'처럼 두 칸이 섞여 있다."""
    return ' '.join(addr.split())


class Geocoder:
    def __init__(self, cache):
        self.cache = cache
        self.token = get_token()
        self.calls = 0
        self.lock = threading.Lock()   # 캐시 쓰기·토큰 재발급 보호

    def __call__(self, addr):
        """(lon, lat) 또는 None. 부산 범위를 벗어난 결과는 버린다."""
        addr = normalize(addr)
        if not addr:
            return None
        with self.lock:
            if addr in self.cache:
                v = self.cache[addr]
                return tuple(v) if v else None

        result = None
        for attempt in range(3):
            try:
                q = urllib.parse.urlencode({'accessToken': self.token, 'address': addr})
                r = json.load(urllib.request.urlopen(f'{GEO_URL}?{q}', timeout=20))
                self.calls += 1
                if r.get('errMsg') != 'Success':
                    # 토큰 만료(4시간)면 재발급 후 한 번 더
                    with self.lock:
                        self.token = get_token()
                    continue
                data = (r.get('result') or {}).get('resultdata') or []
                if data:
                    lon, lat = TO_WGS84.transform(float(data[0]['x']), float(data[0]['y']))
                    if LON_MIN < lon < LON_MAX and LAT_MIN < lat < LAT_MAX:
                        result = (round(lon, 7), round(lat, 7))
                break
            except Exception as e:                      # 네트워크 오류는 재시도
                if attempt == 2:
                    print(f'  ! 실패: {addr} ({e})')
                time.sleep(1 + attempt)

        with self.lock:
            self.cache[addr] = list(result) if result else None
        return result


def read_csv_rows(path):
    raw = open(path, 'rb').read()
    enc = 'utf-8-sig' if raw[:3] == b'\xef\xbb\xbf' else 'cp949'
    return list(csv.DictReader(raw.decode(enc).splitlines()))


def run(rows, addr_fields, label, on_success, workers=8):
    """rows를 지오코딩하며 진행상황을 출력. on_success(row, lon, lat) 호출.

    SGIS 응답이 **1건당 약 3초**라 순차 처리는 5천 건에 4시간이 걸린다.
    대기 시간이 대부분이므로 스레드 풀로 동시 요청한다(기본 8 — 공공 API라 과하게 올리지 않음).
    캐시 덕에 같은 주소는 한 번만 호출한다.
    """
    cache = load_cache()
    geo = Geocoder(cache)
    lock = threading.Lock()

    # 1) 해결해야 할 고유 주소만 추림 (캐시 히트는 호출하지 않는다)
    row_addr = [(r, normalize(next((r[f] for f in addr_fields if (r.get(f) or '').strip()), '')))
                for r in rows]
    todo = sorted({a for _, a in row_addr if a and a not in cache})
    print(f'  {label}: 행 {len(rows):,} / 고유 주소 {len({a for _, a in row_addr if a}):,} '
          f'/ 신규 호출 {len(todo):,} (동시 {workers})')

    # 2) 병렬 호출
    done = 0
    with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as ex:
        for _ in ex.map(geo, todo):
            done += 1
            if done % 200 == 0:
                with lock:
                    save_cache(cache)
                print(f'  {label} 지오코딩 {done:,}/{len(todo):,}')
    save_cache(cache)

    # 3) 캐시를 보고 결과 조립
    ok = fail = 0
    for r, a in row_addr:
        v = cache.get(a)
        if v:
            on_success(r, v[0], v[1])
            ok += 1
        else:
            fail += 1
    print(f'=> {label}: 성공 {ok:,} / 실패 {fail:,} (API 호출 {geo.calls:,})')
    return ok, fail


def do_police():
    """지구대·파출소 부산 94건 → 좌표 붙여 CSV 저장."""
    src = os.path.join(BASE, '경찰청_전국 지구대 파출소 주소 현황_20251231.csv')
    rows = [r for r in read_csv_rows(src) if '부산' in (r.get('시도청') or '')]
    print(f'지구대·파출소 부산 {len(rows)}건')

    out_rows = []
    # 원천 '관서명'이 "남포"처럼 종류가 빠져 있어 지도 팝업에서 불분명하다 → "남포지구대"로 합친다
    run(rows, ['주소'], '지구대',
        lambda r, lon, lat: out_rows.append({
            '관서명': f"{r['관서명']}{r['구분']}", '구분': r['구분'], '경찰서': r['경찰서'],
            '주소': normalize(r['주소']), '경도': lon, '위도': lat}))

    out = os.path.join(BASE, '지구대파출소_부산광역시_geocoded.csv')
    with open(out, 'w', encoding='utf-8-sig', newline='') as f:
        w = csv.DictWriter(f, fieldnames=['관서명', '구분', '경찰서', '주소', '경도', '위도'])
        w.writeheader()
        w.writerows(out_rows)
    print(f'=> {out} ({len(out_rows)}행)')


def do_security_light():
    """보안등 좌표 결측분 → 좌표 채워 CSV 저장.

    출력 헤더를 원본 보안등 CSV와 똑같이 맞춘다. 그러면 process_data.py의
    code 16 메타를 그대로 재사용할 수 있다.
    """
    files = sorted(glob.glob(os.path.join(BASE, '부산광역시_*_보안등정보.csv')))
    header, missing = None, []
    for p in files:
        rows = read_csv_rows(p)
        if rows and header is None:
            header = list(rows[0].keys())
        missing += [r for r in rows
                    if not (r.get('위도') or '').strip() or not (r.get('경도') or '').strip()]
    print(f'보안등 좌표 결측 {len(missing)}건 (파일 {len(files)}개)')

    filled = []

    def fill(r, lon, lat):
        r['경도'], r['위도'] = lon, lat
        filled.append(r)

    run(missing, ['소재지도로명주소', '소재지지번주소'], '보안등', fill)

    out = os.path.join(BASE, '보안등_좌표보완_부산광역시.csv')
    with open(out, 'w', encoding='utf-8-sig', newline='') as f:
        w = csv.DictWriter(f, fieldnames=header)
        w.writeheader()
        w.writerows(filled)
    print(f'=> {out} ({len(filled)}행)')


if __name__ == '__main__':
    jobs = {'지구대': do_police, '보안등': do_security_light}
    names = sys.argv[1:] or list(jobs)
    for n in names:
        if n not in jobs:
            raise SystemExit(f'알 수 없는 대상: {n} (가능: {", ".join(jobs)})')
        jobs[n]()
