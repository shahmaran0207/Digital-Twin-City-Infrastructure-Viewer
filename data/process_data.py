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
    {'code': 11, 'file': '어린이보호구역 내 불법주정차 CCTV설치현황_00.csv',
     'id': '연번', 'sigungu': None, 'name': '시설명'},
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


def process_csv(meta):
    code, filename = meta['code'], meta['file']
    header, rows = read_csv(os.path.join(BASE, filename))
    ncol = len(header)

    # 헤더명 → 인덱스
    def idx(colname):
        return header.index(colname) if colname and colname in header else None

    id_i, sgg_i, name_i = idx(meta['id']), idx(meta['sigungu']), idx(meta['name'])
    # 좌표는 끝 2컬럼
    lon_lat_idx = {ncol - 2, ncol - 1}
    # props 대상: 좌표/source_id/sigungu/name 을 제외한 나머지 컬럼
    skip = set(lon_lat_idx)
    for i in (id_i, sgg_i, name_i):
        if i is not None:
            skip.add(i)
    prop_cols = [(i, header[i]) for i in range(ncol) if i not in skip]

    stats = {'file': filename, 'code': code, 'total': len(rows),
             'kept': 0, 'dropped': 0, 'drop_lines': []}
    out = []
    for n, r in enumerate(rows):
        if len(r) < ncol:
            r = r + [''] * (ncol - len(r))  # 짧은 행 패딩
        coord = pick_lon_lat(r[ncol - 2], r[ncol - 1])
        if coord is None:
            stats['dropped'] += 1
            if len(stats['drop_lines']) < 5:
                stats['drop_lines'].append(f"line {n + 2}: {r}")
            continue
        lon, lat = coord

        source_id = r[id_i].strip() if id_i is not None else ''
        sigungu = r[sgg_i].strip() if sgg_i is not None else ''
        name = r[name_i].strip() if name_i is not None else ''

        props = {header[i]: r[i].strip() for i, _ in prop_cols if r[i].strip()}
        props_json = json.dumps(props, ensure_ascii=False) if props else ''

        out.append((code, source_id, sigungu, name,
                    f'{lon:.7f}', f'{lat:.7f}', props_json))
    stats['kept'] = len(out)
    return out, stats


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


def main():
    all_rows, all_stats = [], []
    for meta in DATASETS:
        rows, stats = process_csv(meta)
        all_rows.extend(rows)
        all_stats.append(stats)
        print(f"[{stats['code']:>2}] {stats['file']}: "
              f"{stats['total']} -> {stats['kept']} (제거 {stats['dropped']})")

    rows, stats = process_its()
    all_rows.extend(rows)
    all_stats.append(stats)
    print(f"[12] {stats['file']}: {stats['total']} -> {stats['kept']} "
          f"(제거 {stats['dropped']})")

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
        f.write('- 어린이보호구역 CCTV(code 11): 원본 미확보로 **구가공본 41행**만 적재 '
                '(전국어린이보호구역표준데이터로 대체 검토 — data/SOURCES.md D절)\n')
    print(f"=> {report}")


if __name__ == '__main__':
    main()
