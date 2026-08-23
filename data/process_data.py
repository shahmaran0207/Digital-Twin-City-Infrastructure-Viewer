# -*- coding: utf-8 -*-
"""
facility 포인트 13종 1차 가공 (Phase 1-R 재작업)

설계: plans/data-rebuild.md

- 좌표: 헤더 라벨을 믿지 않고 끝 2컬럼의 '값 범위'로 lon/lat 자동 판별
  (부산 경도 128.5~129.5 / 위도 34.8~35.7 → 두 범위가 겹치지 않음)
- props: 좌표 2컬럼 + source_id/sigungu/name 컬럼을 제외한 나머지 원천 컬럼을
  한글 키 그대로 jsonb 로 보존 (빈 값 제외)
- 출력: processed/facility_all.csv (UTF-8 BOM) + processed/REPORT.md

실행: py data/process_data.py
"""
import csv
import glob
import io
import json
import os
import sys
import zipfile

sys.stdout.reconfigure(encoding='utf-8')
BASE = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.join(BASE, 'processed')
os.makedirs(OUT_DIR, exist_ok=True)

# 부산 좌표 범위 (V1 facility CHECK 제약과 동일)
LON_MIN, LON_MAX = 128.5, 129.5
LAT_MIN, LAT_MAX = 34.8, 35.7

# 파일별 메타: code, file, source_id 컬럼, sigungu 컬럼, name 컬럼 (헤더명 기준, 없으면 None)
# 좌표는 끝 2컬럼에서 자동 판별하므로 명시하지 않는다.
DATASETS = [
    {'code': 0,  'file': '부산광역시_차선정보_20220630.csv',
     'id': '번호', 'sigungu': '시군구명', 'name': None},
    {'code': 1,  'file': '부산광역시_안전표지 정보.csv',
     'id': None, 'sigungu': '시군구명', 'name': None},
    {'code': 2,  'file': '부산광역시_노면방향표시 정보_20220630.csv',
     'id': '번호', 'sigungu': '시군구명', 'name': None},
    {'code': 3,  'file': '부산광역시_노면문자표시 정보_20220630.csv',
     'id': '번호', 'sigungu': '시군구명', 'name': None},
    {'code': 4,  'file': '부산광역시_철주정보_20220630.csv',
     'id': '번호', 'sigungu': '시군구명', 'name': None},
    {'code': 5,  'file': '부산광역시_부착대 정보_20220630.csv',
     'id': '번호', 'sigungu': '시군구명', 'name': None},
    {'code': 6,  'file': '부산광역시_방범용CCTV 정보_20241231(공공데이터포털).csv',
     'id': '관리번호', 'sigungu': '구군', 'name': None},
    {'code': 7,  'file': '부산광역시_안전지대 정보_20220630.csv',
     'id': '번호', 'sigungu': '시군구명', 'name': None},
    {'code': 8,  'file': '부산광역시_교차로 정보.csv',
     'id': '관리번호', 'sigungu': '시군구명', 'name': '교차로명'},
    {'code': 9,  'file': '부산광역시_15분 도시공원_20251119.csv',
     'id': '연번', 'sigungu': '기관', 'name': '공원명'},
    {'code': 10, 'file': '스마트 버스쉘터 설치 현황.csv',
     'id': '연번', 'sigungu': None, 'name': '정류소명'},
    # 어린이보호구역: 전국어린이보호구역표준데이터(15012891)로 대체 — 보호구역 자체 데이터
    #  · 전국본이라 region(주소)로 부산만 필터, 좌표는 위도/경도 컬럼 명시(끝 2컬럼 아님)
    #  · 시군구 컬럼이 없어 도로명주소에서 추출(sigungu_addr)
    {'code': 11, 'file': '전국어린이보호구역표준데이터.csv',
     'id': None, 'sigungu': None, 'name': '대상시설명',
     'lon': '경도', 'lat': '위도', 'region': '소재지도로명주소',
     'sigungu_addr': '소재지도로명주소'},
    # ── Phase 1-C: 범죄예방·자전거 확장 (2026-08-23) ─────────────────────
    #  · 표준데이터는 좌표 컬럼명이 명시적(WGS84위도/경도)이고 끝 2컬럼이 아니라 lon/lat 지정
    #  · 시군구 컬럼이 없어 도로명주소에서 추출
    #  · 포털에서 부산으로 이미 걸러 받았으므로 region(부산 필터) 불필요
    {'code': 13, 'file': '자전거보관소정보_부산광역시.csv',
     'id': '관리번호', 'sigungu': None, 'name': '자전거보관소명',
     'lon': 'WGS84경도', 'lat': 'WGS84위도',
     'sigungu_addr': ['소재지도로명주소', '소재지지번주소']},
    {'code': 15, 'file': '안전비상벨위치정보_부산광역시.csv',
     'id': '관리번호', 'sigungu': None, 'name': '설치위치',
     'lon': 'WGS84경도', 'lat': 'WGS84위도',
     'sigungu_addr': ['소재지도로명주소', '소재지지번주소']},
    # 보안등: 전국본이 184만 건이라 API·전국 CSV 대신 포털에서 구·군별로 받았다 → 16개 파일을 glob으로 합침
    {'code': 16, 'glob': '부산광역시_*_보안등정보.csv',
     'id': None, 'sigungu': None, 'name': '보안등위치명',
     'lon': '경도', 'lat': '위도',
     'sigungu_addr': ['소재지도로명주소', '소재지지번주소']},
    # 아래 2종은 fetch_api.py가 표준데이터 API에서 받아 저장한 것 → 헤더가 API 필드명(영문)
    #  한글 라벨을 임의로 붙이면 실제 의미와 어긋날 위험이 있어 영문 그대로 둔다(props 키도 영문)
    {'code': 14, 'file': '자전거대여소_부산광역시_api.csv',
     'id': None, 'sigungu': None, 'name': 'bcyclLendNm',
     'lon': 'longitude', 'lat': 'latitude',
     'sigungu_addr': ['rdnmadr', 'lnmadr']},
    {'code': 22, 'file': '주차장_부산광역시_api.csv',
     'id': 'prkplceNo', 'sigungu': None, 'name': 'prkplceNm',
     'lon': 'longitude', 'lat': 'latitude',
     'sigungu_addr': ['rdnmadr', 'lnmadr']},
]
# ITS CCTV: shapefile (인코딩 utf-8), 필드 id/name/lng/lat/url
ITS_ZIP = ('부산광역시 교통정보서비스센터 보유 ITS CCTV 현황.zip', 'tl_tracffic_cctv_info', 12)


def in_lon(v):
    return v is not None and LON_MIN < v < LON_MAX


def in_lat(v):
    return v is not None and LAT_MIN < v < LAT_MAX


def to_float(s):
    """숫자 문자열 파싱. 실패 시 None."""
    try:
        return float(s.strip())
    except (ValueError, AttributeError):
        return None


def pick_lon_lat(a, b):
    """끝 2컬럼 값(a, b)에서 (lon, lat) 판별. 부산 범위 밖이면 None."""
    av, bv = to_float(a), to_float(b)
    # 경도(128~129)는 lon, 위도(34~35)는 lat — 순서 무관하게 값으로 배정
    if in_lon(av) and in_lat(bv):
        return (av, bv)
    if in_lon(bv) and in_lat(av):
        return (bv, av)
    return None


def read_csv(path):
    """원천 CSV 읽기 (BOM이면 utf-8-sig, 아니면 cp949). (header, rows) 반환."""
    raw = open(path, 'rb').read()
    enc = 'utf-8-sig' if raw[:3] == b'\xef\xbb\xbf' else 'cp949'
    reader = csv.reader(raw.decode(enc).splitlines())
    header = next(reader)
    rows = [r for r in reader if r and any(c.strip() for c in r)]
    return header, rows


# 부산 16개 구·군. 긴 이름부터 매칭해야 한다('강서구'가 '서구'보다 먼저 걸려야 함)
BUSAN_SIGUNGU = sorted(
    ['중구', '서구', '동구', '영도구', '부산진구', '동래구', '남구', '북구',
     '해운대구', '사하구', '금정구', '강서구', '연제구', '수영구', '사상구', '기장군'],
    key=len, reverse=True)


def sigungu_from_addr(addr):
    """주소에서 부산 구·군 추출.

    split()[1]만 쓰면 세 가지를 놓친다(2026-08-23 발견):
      · '부산광역시 동구망양로 12' — 공백이 빠져 '동구망양로'가 나온다
      · 도로명주소가 빈 행 — 지번주소로 넘어가야 한다(호출부에서 처리)
      · '부산광역시 기장ㅇ군 …' — 원천 주소에 자모(ㅇ)가 끼어든 오타
    그래서 16개 구·군 화이트리스트로 찾고, 실패하면 자모를 제거해 한 번 더 찾는다.
    """
    for sgg in BUSAN_SIGUNGU:
        if sgg in addr:
            return sgg
    # 한글 자모(ㄱ~ㅣ)가 섞인 오타 교정 후 재시도
    cleaned = ''.join(ch for ch in addr if not ('ㄱ' <= ch <= 'ㅣ'))
    if cleaned != addr:
        for sgg in BUSAN_SIGUNGU:
            if sgg in cleaned:
                return sgg
    parts = addr.split()
    return parts[1] if len(parts) >= 2 else ''


def process_csv(meta):
    code, filename = meta['code'], meta['file']
    header, rows = read_csv(os.path.join(BASE, filename))
    ncol = len(header)

    # 헤더명 → 인덱스
    def idx(colname):
        return header.index(colname) if colname and colname in header else None

    id_i, sgg_i, name_i = idx(meta['id']), idx(meta['sigungu']), idx(meta['name'])
    # 좌표 컬럼: 명시(lon/lat)되면 그 컬럼, 아니면 끝 2컬럼 (값 범위로 자동 판별)
    lon_i, lat_i = idx(meta.get('lon')), idx(meta.get('lat'))
    if lon_i is not None and lat_i is not None:
        lon_lat_idx = {lon_i, lat_i}
    else:
        lon_lat_idx = {ncol - 2, ncol - 1}
    # 부산 필터용 주소 컬럼 / 시군구 추출용 주소 컬럼 (전국 표준데이터 대응)
    region_i = idx(meta.get('region'))
    # 시군구 추출용 주소 컬럼: 여러 개를 순서대로 시도한다(도로명주소가 빈 행은 지번주소로)
    sgg_addr_cols = meta.get('sigungu_addr')
    if isinstance(sgg_addr_cols, str):
        sgg_addr_cols = [sgg_addr_cols]
    sgg_addr_idx = [idx(c) for c in (sgg_addr_cols or []) if idx(c) is not None]
    # props 대상: 좌표/source_id/sigungu/name 을 제외한 나머지 컬럼 (주소는 props에 보존)
    skip = set(lon_lat_idx)
    for i in (id_i, sgg_i, name_i):
        if i is not None:
            skip.add(i)
    prop_cols = [(i, header[i]) for i in range(ncol) if i not in skip]

    stats = {'file': filename, 'code': code, 'total': len(rows),
             'kept': 0, 'dropped': 0, 'drop_lines': []}
    considered = 0  # 부산 필터 통과 행 수 (전국본일 때 '원본 행' 기준이 됨)
    out = []
    for n, r in enumerate(rows):
        if len(r) < ncol:
            r = r + [''] * (ncol - len(r))  # 짧은 행 패딩
        # 전국본은 부산 행만 사용 (필터 제외분은 제거 통계에 넣지 않음)
        if region_i is not None and not r[region_i].strip().startswith('부산'):
            continue
        considered += 1
        coord = pick_lon_lat(r[min(lon_lat_idx)], r[max(lon_lat_idx)])
        if coord is None:
            stats['dropped'] += 1
            if len(stats['drop_lines']) < 5:
                stats['drop_lines'].append(f"line {n + 2}: {r}")
            continue
        lon, lat = coord

        source_id = r[id_i].strip() if id_i is not None else ''
        if sgg_i is not None:
            sigungu = r[sgg_i].strip()
        elif sgg_addr_idx:
            sigungu = ''
            for i in sgg_addr_idx:          # 앞 컬럼에서 못 찾으면 다음 주소 컬럼으로
                sigungu = sigungu_from_addr(r[i].strip())
                if sigungu:
                    break
        else:
            sigungu = ''
        name = r[name_i].strip() if name_i is not None else ''

        props = {header[i]: r[i].strip() for i, _ in prop_cols if r[i].strip()}
        props_json = json.dumps(props, ensure_ascii=False) if props else ''

        out.append((code, source_id, sigungu, name,
                    f'{lon:.7f}', f'{lat:.7f}', props_json))
    stats['kept'] = len(out)
    # 전국본은 부산 필터 통과분을 '원본 행'으로 보고 (전국 전체 건수가 아닌)
    if region_i is not None:
        stats['total'] = considered
    return out, stats


# ── 상권정보(소상공인시장진흥공단) → 심야업소 3종 ─────────────────────────
#  파일 하나에서 업종별로 3개 facility_type을 뽑아내므로 process_csv를 쓰지 않는다.
#  · 인코딩: UTF-8 (BOM 없음) — read_csv의 cp949 기본값과 달라 직접 읽는다
#  · 39개 컬럼 전부를 props에 넣으면 9천 행에 코드 컬럼까지 쌓여 비대해지므로 선별한다
SANGGA_FILE = '소상공인시장진흥공단_상가(상권)정보_부산_202606.csv'
SANGGA_GROUPS = {
    # code: (포함할 상권업종소분류명 집합, 제외 근거는 REPORT/커밋 메시지에 기록)
    19: {'일반 유흥 주점', '무도 유흥 주점', '요리 주점'},   # 펜션·전자게임장은 성격이 달라 제외
    20: {'여관/모텔', '호텔/리조트', '그 외 기타 숙박업'},   # 펜션 제외(관광지 분포)
    21: {'PC방'},                                            # 전자 게임장 제외(별 업종)
}
SANGGA_PROPS = ['상권업종대분류명', '상권업종중분류명', '상권업종소분류명', '지점명',
                '행정동명', '법정동명', '도로명주소', '지번주소', '건물명', '층정보']


def process_sangga():
    """상권정보 부산 CSV → code 19/20/21 행 생성. (rows, stats리스트) 반환."""
    path = os.path.join(BASE, SANGGA_FILE)
    code_of = {sub: code for code, subs in SANGGA_GROUPS.items() for sub in subs}

    out = []
    stats = {code: {'file': SANGGA_FILE, 'code': code, 'total': 0, 'kept': 0,
                    'dropped': 0, 'drop_lines': []} for code in SANGGA_GROUPS}
    with open(path, encoding='utf-8') as f:
        for n, r in enumerate(csv.DictReader(f)):
            code = code_of.get((r.get('상권업종소분류명') or '').strip())
            if code is None:
                continue
            st = stats[code]
            st['total'] += 1
            coord = pick_lon_lat(r.get('경도', ''), r.get('위도', ''))
            if coord is None:
                st['dropped'] += 1
                if len(st['drop_lines']) < 3:
                    st['drop_lines'].append(
                        f"line {n + 2}: {r.get('상호명')} / {r.get('경도')},{r.get('위도')}")
                continue
            lon, lat = coord
            props = {k: r[k].strip() for k in SANGGA_PROPS if r.get(k, '').strip()}
            out.append((code, (r.get('상가업소번호') or '').strip(),
                        (r.get('시군구명') or '').strip(), (r.get('상호명') or '').strip(),
                        f'{lon:.7f}', f'{lat:.7f}',
                        json.dumps(props, ensure_ascii=False)))
            st['kept'] += 1
    return out, [stats[c] for c in sorted(stats)]


def process_meta(meta):
    """DATASETS 항목 하나 처리. glob이 지정되면 여러 파일을 한 유형으로 합친다.

    보안등은 포털이 구·군별로만 내려줘서 파일이 16개다(전국본 184만 건 회피).
    파일이 늘어도 DATASETS 항목은 하나로 유지하기 위해 glob을 지원한다.
    """
    pattern = meta.get('glob')
    if not pattern:
        return process_csv(meta)

    files = sorted(glob.glob(os.path.join(BASE, pattern)))
    if not files:
        raise SystemExit(f'파일 없음: {pattern}')
    rows = []
    agg = {'file': f'{pattern} ({len(files)}개 파일)', 'code': meta['code'],
           'total': 0, 'kept': 0, 'dropped': 0, 'drop_lines': []}
    for path in files:
        r, s = process_csv(dict(meta, file=os.path.basename(path)))
        rows.extend(r)
        agg['total'] += s['total']
        agg['kept'] += s['kept']
        agg['dropped'] += s['dropped']
        agg['drop_lines'].extend(s['drop_lines'][:1])   # 파일당 샘플 1건만
    return rows, agg


def process_its():
    import shapefile
    zpath, base, code = ITS_ZIP
    with zipfile.ZipFile(os.path.join(BASE, zpath)) as z:
        sf = shapefile.Reader(
            shp=io.BytesIO(z.read(base + '.shp')),
            dbf=io.BytesIO(z.read(base + '.dbf')),
            shx=io.BytesIO(z.read(base + '.shx')),
            encoding='utf-8')
        stats = {'file': zpath, 'code': code, 'total': len(sf),
                 'kept': 0, 'dropped': 0, 'drop_lines': []}
        out = []
        for rec in sf.iterRecords():
            cid, name, lon, lat, url = (rec['id'], rec['name'],
                                        rec['lng'], rec['lat'], rec['url'])
            if not (in_lon(lon) and in_lat(lat)):
                stats['dropped'] += 1
                continue
            props = json.dumps({'url': url}, ensure_ascii=False) if url else ''
            out.append((code, str(cid), '', name,
                        f'{lon:.7f}', f'{lat:.7f}', props))
        stats['kept'] = len(out)
        return out, stats


def main(only_codes=None):
    """only_codes가 주어지면 그 유형만 가공해 facility_add.csv로 뽑는다(증분 적재용).

    전체 재가공(facility_all.csv)은 DB를 TRUNCATE 후 다시 넣어야 해서 기존 21만 행의
    id가 전부 바뀐다. 나중에 블록체인 앵커링이 레코드 해시를 다루므로 id는 안정적인 게
    좋다 → 신규 유형은 증분으로 append 한다.
    """
    all_rows, all_stats = [], []
    for meta in DATASETS:
        if only_codes and meta['code'] not in only_codes:
            continue
        rows, stats = process_meta(meta)
        all_rows.extend(rows)
        all_stats.append(stats)
        print(f"[{stats['code']:>2}] {stats['file']}: "
              f"{stats['total']} -> {stats['kept']} (제거 {stats['dropped']})")

    if not only_codes or 12 in only_codes:
        rows, stats = process_its()
        all_rows.extend(rows)
        all_stats.append(stats)
        print(f"[12] {stats['file']}: {stats['total']} -> {stats['kept']} "
              f"(제거 {stats['dropped']})")

    # 상권정보: 파일 하나 → code 19/20/21
    if not only_codes or only_codes & set(SANGGA_GROUPS):
        rows, stats_list = process_sangga()
        wanted = only_codes or set(SANGGA_GROUPS)
        rows = [r for r in rows if r[0] in wanted]
        all_rows.extend(rows)
        for s in stats_list:
            if s['code'] in wanted:
                all_stats.append(s)
                print(f"[{s['code']:>2}] 상권정보({s['code']}): "
                      f"{s['total']} -> {s['kept']} (제거 {s['dropped']})")

    if only_codes:
        out_csv = os.path.join(OUT_DIR, 'facility_add.csv')
        with open(out_csv, 'w', encoding='utf-8-sig', newline='') as f:
            w = csv.writer(f)
            w.writerow(['facility_type', 'source_id', 'sigungu', 'name', 'lon', 'lat', 'props'])
            w.writerows(all_rows)
        print(f"\n=> {out_csv} ({len(all_rows)} rows, 증분)")
        for s in all_stats:
            print(f"   code {s['code']}: {s['total']} -> {s['kept']} (제거 {s['dropped']})")
            for l in s['drop_lines']:
                print(f"     {l}")

        # 증분 이력을 REPORT.md 하단에 append (전체 재가공 때만 REPORT를 다시 쓰므로
        # 증분분이 기록되지 않는 빈틈을 메운다)
        report = os.path.join(OUT_DIR, 'REPORT.md')
        with open(report, 'a', encoding='utf-8') as f:
            f.write('\n\n## 증분 적재 이력\n\n')
            f.write(f'`--codes {",".join(str(c) for c in sorted(only_codes))}` 실행 결과 '
                    f'→ `facility_add.csv` ({len(all_rows)}행)\n\n')
            f.write('| 코드 | 파일 | 원본 행 | 적재 행 | 제거 |\n|---|---|---|---|---|\n')
            for s in all_stats:
                f.write(f"| {s['code']} | {s['file']} | {s['total']} | {s['kept']} | {s['dropped']} |\n")
            f.write('\n제거된 행은 전부 원천 좌표 오류(부산 범위 밖):\n\n```\n')
            for s in all_stats:
                for l in s['drop_lines']:
                    f.write(f"[code {s['code']}] {l}\n")
            f.write('```\n')
        print(f"=> {report} (증분 이력 추가)")
        return

    # 통합 CSV (DB \copy 용, UTF-8 BOM — 엑셀 한글 깨짐 방지, psql은 HEADER 스킵)
    out_csv = os.path.join(OUT_DIR, 'facility_all.csv')
    with open(out_csv, 'w', encoding='utf-8-sig', newline='') as f:
        w = csv.writer(f)
        w.writerow(['facility_type', 'source_id', 'sigungu', 'name', 'lon', 'lat', 'props'])
        w.writerows(all_rows)
    print(f"\n=> {out_csv} ({len(all_rows)} rows)")

    # 가공 리포트
    report = os.path.join(OUT_DIR, 'REPORT.md')
    with open(report, 'w', encoding='utf-8') as f:
        f.write('# facility 가공 리포트 (Phase 1-R)\n\n')
        f.write('원천: `data/` CSV 12종 + ITS CCTV shapefile. 출력: `facility_all.csv`\n\n')
        f.write('## 공통 처리\n\n')
        f.write('- **좌표 자동판별**: 끝 2컬럼 중 값이 경도(128.5~129.5)면 lon, 위도(34.8~35.7)면 lat. '
                '헤더 순서가 파일마다 달라(노면문자·방범CCTV는 위도먼저) 라벨을 신뢰하지 않음\n')
        f.write(f'- 부산 범위 밖이거나 파싱 불가한 행 제거\n')
        f.write('- props: 좌표·source_id·sigungu·name 컬럼을 제외한 나머지 원천 컬럼을 한글 키로 보존(빈 값 제외)\n\n')
        f.write('## 파일별 결과\n\n')
        f.write('| 코드 | 파일 | 원본 행 | 적재 행 | 제거 |\n|---|---|---|---|---|\n')
        for s in all_stats:
            f.write(f"| {s['code']} | {s['file']} | {s['total']} | {s['kept']} | {s['dropped']} |\n")
        f.write(f"\n**합계: {len(all_rows)} 행**\n")
        f.write('\n## 제거된 행 샘플\n\n')
        for s in all_stats:
            if s['drop_lines']:
                f.write(f"### {s['file']} (제거 {s['dropped']}건)\n```\n")
                for l in s['drop_lines']:
                    f.write(l + '\n')
                f.write('```\n')
        f.write('\n## 한계 / 미해결\n\n')
        f.write('- 어린이보호구역(code 11): 구 단속CCTV 가공본(41행)을 **전국어린이보호구역표준데이터**(15012891)로 '
                '대체(2026-06-15). 전국본에서 도로명주소가 "부산"인 행만 추출, 좌표는 위도/경도 컬럼 명시, '
                '시군구는 주소에서 추출. 보호구역 자체 위치 데이터라 facility_type도 child_protection_zone(어린이보호구역)으로 변경\n')
    print(f"=> {report}")


if __name__ == '__main__':
    # 사용법:
    #   python process_data.py                 전체 재가공 → processed/facility_all.csv
    #   python process_data.py --codes 13,15   해당 유형만 → processed/facility_add.csv (증분)
    import sys
    codes = None
    if '--codes' in sys.argv:
        codes = {int(c) for c in sys.argv[sys.argv.index('--codes') + 1].split(',')}
    main(codes)
