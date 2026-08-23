# -*- coding: utf-8 -*-
"""공공데이터포털 표준데이터 API 수집 → 부산만 필터해 CSV 저장 (Phase 1-C)

보안: 인증키는 `.env`의 DATA_KEY에서만 읽는다. 코드·로그·CSV에 절대 남기지 않는다.
      이 스크립트는 서버 사이드(로컬) 전용이며 프론트는 이 키를 볼 수 없다.
      (CLAUDE.md 보안 원칙 / plans/security.md 1번)

출력: data/{이름}_부산광역시_api.csv — 헤더는 API 필드명(영문) 그대로 둔다.
      한글 라벨을 임의로 붙이면 실제 의미와 어긋날 위험이 있어, 정확성을 택했다.

실행: py data/fetch_api.py            (전체)
      py data/fetch_api.py 자전거대여소  (하나만)
"""
import csv
import json
import os
import sys
import time
import urllib.parse
import urllib.request

sys.stdout.reconfigure(encoding='utf-8')
BASE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(BASE)
API = 'https://api.data.go.kr/openapi/'
PAGE_SIZE = 1000

# 이름: (엔드포인트, 부산 판별에 쓸 필드 후보)
#  · 주소 필드(rdnmadr/lnmadr)가 비어 있는 행이 있어 여러 후보를 순서대로 본다
#  · 보안등(tn_pubr_public_scrty_lmp_api)은 전국 184만 건이라 API로 받지 않는다
#    (1,000건/페이지 = 1,840요청, 개발계정 일일 한도 초과) → 포털에서 구·군별 CSV로 받음
#  · 여성안심(tn_pubr_public_female_safety_...)은 부산 25건뿐이라 2026-08-23 수집 제외 결정
TARGETS = {
    '자전거대여소': ('tn_pubr_public_bcycl_lend_api', ['rdnmadr', 'lnmadr', 'institutionNm']),
    '주차장': ('tn_pubr_prkplce_info_api', ['rdnmadr', 'lnmadr', 'institutionNm']),
}


def load_key():
    """.env에서 DATA_KEY 읽기. 없으면 즉시 중단(키를 코드에 두지 않는다)."""
    for line in open(os.path.join(ROOT, '.env'), encoding='utf-8'):
        if line.startswith('DATA_KEY='):
            return line.split('=', 1)[1].strip()
    raise SystemExit('.env 에 DATA_KEY 가 없습니다')


def fetch_page(endpoint, key, page):
    q = urllib.parse.urlencode({'serviceKey': key, 'pageNo': page,
                                'numOfRows': PAGE_SIZE, 'type': 'json'})
    with urllib.request.urlopen(f'{API}{endpoint}?{q}', timeout=30) as r:
        body = json.loads(r.read().decode('utf-8'))
    head = body.get('header', {})
    if head.get('resultCode') != '00':
        raise SystemExit(f"API 오류: {head.get('resultCode')} {head.get('resultMsg')}")
    b = body['body']
    items = b.get('items') or {}
    item = items.get('item') if isinstance(items, dict) else items
    if item is None:
        item = []
    if isinstance(item, dict):
        item = [item]
    return item, int(b.get('totalCount', 0))


def is_busan(row, addr_fields):
    for f in addr_fields:
        v = (row.get(f) or '').strip()
        if v:
            if v.startswith('부산'):
                return True
            # 첫 비어있지 않은 주소가 부산이 아니면 다른 지역으로 본다
            return False
    return False


def collect(name):
    endpoint, addr_fields = TARGETS[name]
    key = load_key()
    page, total, rows = 1, None, []
    while True:
        item, total = fetch_page(endpoint, key, page)
        if not item:
            break
        rows.extend(item)
        print(f'  {name}: {len(rows)}/{total}')
        if len(rows) >= total:
            break
        page += 1
        time.sleep(0.2)          # 포털 부하 배려
    busan = [r for r in rows if is_busan(r, addr_fields)]

    out = os.path.join(BASE, f'{name}_부산광역시_api.csv')
    header = list(rows[0].keys()) if rows else []
    with open(out, 'w', encoding='utf-8-sig', newline='') as f:
        w = csv.DictWriter(f, fieldnames=header)
        w.writeheader()
        w.writerows(busan)
    print(f'=> {out}  전국 {len(rows)} → 부산 {len(busan)}')
    return len(busan)


if __name__ == '__main__':
    names = sys.argv[1:] or list(TARGETS)
    for n in names:
        if n not in TARGETS:
            raise SystemExit(f'알 수 없는 대상: {n} (가능: {", ".join(TARGETS)})')
        collect(n)
