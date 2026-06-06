# -*- coding: utf-8 -*-
"""
data 폴더 원천 CSV/SHP 1차 가공 스크립트

- 전 CSV 공통: lat/lon 헤더가 뒤바뀐 문제 보정 (3번째 컬럼=경도, 4번째 컬럼=위도)
- 좌표 오류 복구: 소수점 누락(129034935→129.034935), 소수점 중복(35.080.175→35.080175), lon/lat 역전
- 복구 불가 행 제거 (결측 / 파싱 불가 / 부산 범위 밖)
- 결측 id / facility_type 채움
- ITS CCTV shapefile → facility_type 12로 추출 (name, url 포함)
- 출력: processed/facility_all.csv (UTF-8) + processed/REPORT.md

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

# 부산 좌표 범위
LON_MIN, LON_MAX = 128.5, 129.5
LAT_MIN, LAT_MAX = 34.8, 35.7

# (파일명, facility_type 코드)
DATASETS = [
    ('부산광역시_차선정보_20220630.csv', 0),
    ('부산광역시_안전표지 정보.csv', 1),
    ('부산광역시_노면방향표시 정보_20220630.csv', 2),
    ('부산광역시_노면문자표시 정보_20220630.csv', 3),
    ('부산광역시_철주정보_20220630.csv', 4),
    ('부산광역시_부착대 정보_20220630.csv', 5),
    ('부산광역시_방범용CCTV 정보_20241231(공공데이터포털).csv', 6),
    ('부산광역시_안전지대 정보_20220630.csv', 7),
    ('부산광역시_교차로 정보.csv', 8),
    ('15분 도시공원_00.csv', 9),
    ('스마트 버스쉘터 설치 현황.csv', 10),
    ('어린이보호구역 내 불법주정차 CCTV설치현황_00.csv', 11),
]
ITS_ZIP = ('부산광역시 교통정보서비스센터 보유 ITS CCTV 현황.zip', 'tl_tracffic_cctv_info', 12)


def in_lon(v): return LON_MIN < v < LON_MAX
def in_lat(v): return LAT_MIN < v < LAT_MAX


def try_parse(s):
    """좌표 문자열 파싱. 흔한 입력 오류 복구 시도. 실패 시 None."""
    s = s.strip()
    if not s:
        return None
    try:
        return float(s)
    except ValueError:
        pass
    # 소수점 2개 이상: 첫 소수점만 유지 (35.080.175 -> 35.080175)
    if s.count('.') >= 2:
        head, _, tail = s.partition('.')
        cand = head + '.' + tail.replace('.', '')
        try:
            return float(cand)
        except ValueError:
            return None
    return None


def repair_coord(x, y, stats):
    """(lon, lat) 후보값 보정. 성공 시 (lon, lat), 실패 시 None."""
    if x is None or y is None:
        return None
    # 소수점 누락 복구: 129034935 -> 129.034935 / 35100546 -> 35.100546
    if x > 1000:
        d = str(int(x))
        x2 = float(d[:3] + '.' + d[3:]) if d.startswith('12') else None
        if x2 is not None and in_lon(x2):
            x = x2
            stats['repaired'] += 1
    if y > 1000:
        d = str(int(y))
        y2 = float(d[:2] + '.' + d[2:]) if d.startswith('3') else None
        if y2 is not None and in_lat(y2):
            y = y2
            stats['repaired'] += 1
    # lon/lat 역전 복구
    if in_lat(x) and in_lon(y):
        x, y = y, x
        stats['swapped'] += 1
    if in_lon(x) and in_lat(y):
        return (x, y)
    return None


def process_csv(filename, ftype):
    raw = open(os.path.join(BASE, filename), 'rb').read()
    enc = 'utf-8-sig' if raw[:3] == b'\xef\xbb\xbf' else 'cp949'
    reader = csv.reader(raw.decode(enc).splitlines())
    next(reader)  # header: id, sigun_gu, lat, lon, geom, facility_type (lat/lon 뒤바뀜)
    rows = [r for r in reader if r and any(c.strip() for c in r)]

    stats = {'file': filename, 'ftype': ftype, 'total': len(rows), 'kept': 0,
             'repaired': 0, 'swapped': 0, 'dropped': 0, 'id_filled': 0,
             'ft_filled': 0, 'ft_mismatch': 0, 'drop_lines': []}

    # 결측 id 채움용: 기존 최대 id
    max_id = 0
    for r in rows:
        s = r[0].strip()
        if s.isdigit():
            max_id = max(max_id, int(s))

    out = []
    for i, r in enumerate(rows):
        # 컬럼: [0]=id, [1]=sigun_gu, [2]=경도(헤더 lat), [3]=위도(헤더 lon)
        x = try_parse(r[2]) if len(r) > 2 else None
        y = try_parse(r[3]) if len(r) > 3 else None
        coord = repair_coord(x, y, stats)
        if coord is None:
            stats['dropped'] += 1
            if len(stats['drop_lines']) < 5:
                stats['drop_lines'].append(f"line {i + 2}: {r}")
            continue
        lon, lat = coord

        sid = r[0].strip()
        if not sid:
            max_id += 1
            sid = str(max_id)
            stats['id_filled'] += 1

        ft_raw = r[5].strip() if len(r) > 5 else ''
        if not ft_raw:
            stats['ft_filled'] += 1
        elif ft_raw != str(ftype):
            stats['ft_mismatch'] += 1

        sigungu = r[1].strip() if len(r) > 1 else ''
        out.append((ftype, sid, sigungu, '', f'{lon:.7f}', f'{lat:.7f}', ''))

    stats['kept'] = len(out)
    return out, stats


def process_its_cctv():
    import shapefile
    zpath, base, ftype = ITS_ZIP
    with zipfile.ZipFile(os.path.join(BASE, zpath)) as z:
        sf = shapefile.Reader(
            shp=io.BytesIO(z.read(base + '.shp')),
            dbf=io.BytesIO(z.read(base + '.dbf')),
            shx=io.BytesIO(z.read(base + '.shx')),
            encoding='utf-8')
        stats = {'file': zpath, 'ftype': ftype, 'total': len(sf), 'kept': 0,
                 'repaired': 0, 'swapped': 0, 'dropped': 0, 'id_filled': 0,
                 'ft_filled': len(sf), 'ft_mismatch': 0, 'drop_lines': []}
        out = []
        for rec in sf.iterRecords():
            cid, name, lon, lat, url = rec['id'], rec['name'], rec['lng'], rec['lat'], rec['url']
            if not (in_lon(lon) and in_lat(lat)):
                stats['dropped'] += 1
                continue
            props = json.dumps({'url': url}, ensure_ascii=False)
            out.append((ftype, str(cid), '', name, f'{lon:.7f}', f'{lat:.7f}', props))
        stats['kept'] = len(out)
        return out, stats


def main():
    all_rows = []
    all_stats = []
    for filename, ftype in DATASETS:
        rows, stats = process_csv(filename, ftype)
        all_rows.extend(rows)
        all_stats.append(stats)
        print(f"[{ftype:>2}] {filename}: {stats['total']} -> {stats['kept']} "
              f"(복구 {stats['repaired']}, 역전보정 {stats['swapped']}, 제거 {stats['dropped']})")

    rows, stats = process_its_cctv()
    all_rows.extend(rows)
    all_stats.append(stats)
    print(f"[12] {stats['file']}: {stats['total']} -> {stats['kept']}")

    # 통합 CSV (DB 임포트용, UTF-8)
    out_csv = os.path.join(OUT_DIR, 'facility_all.csv')
    with open(out_csv, 'w', encoding='utf-8', newline='') as f:
        w = csv.writer(f)
        w.writerow(['facility_type', 'source_id', 'sigungu', 'name', 'lon', 'lat', 'props'])
        w.writerows(all_rows)
    print(f"\n=> {out_csv} ({len(all_rows)} rows)")

    # 가공 리포트
    report = os.path.join(OUT_DIR, 'REPORT.md')
    with open(report, 'w', encoding='utf-8') as f:
        f.write('# 데이터 1차 가공 리포트\n\n')
        f.write('원천: `data/` CSV 12종 + ITS CCTV shapefile. 출력: `facility_all.csv`\n\n')
        f.write('## 공통 보정\n\n')
        f.write('- **lat/lon 헤더 뒤바뀜 보정**: 원천 CSV의 `lat` 컬럼이 실제 경도(129.x), `lon` 컬럼이 실제 위도(35.x)였음 → 올바르게 교정\n')
        f.write('- 좌표 오류 복구: 소수점 누락(`129034935`→`129.034935`), 소수점 중복(`35.080.175`→`35.080175`), 행 단위 lon/lat 역전\n')
        f.write(f'- 부산 범위(경도 {LON_MIN}~{LON_MAX}, 위도 {LAT_MIN}~{LAT_MAX}) 밖이거나 복구 불가한 행 제거\n')
        f.write('- 결측 id는 파일 내 최대 id 이후 순번으로 부여, 결측 facility_type은 파일별 코드로 채움\n\n')
        f.write('## 파일별 결과\n\n')
        f.write('| 코드 | 파일 | 원본 행 | 적재 행 | 좌표복구 | 역전보정 | 제거 | id채움 | ft채움 |\n')
        f.write('|---|---|---|---|---|---|---|---|---|\n')
        for s in all_stats:
            f.write(f"| {s['ftype']} | {s['file']} | {s['total']} | {s['kept']} | {s['repaired']} | "
                    f"{s['swapped']} | {s['dropped']} | {s['id_filled']} | {s['ft_filled']} |\n")
        f.write('\n## 제거된 행 샘플\n\n')
        for s in all_stats:
            if s['drop_lines']:
                f.write(f"### {s['file']} (제거 {s['dropped']}건)\n```\n")
                for l in s['drop_lines']:
                    f.write(l + '\n')
                f.write('```\n')
        f.write('\n## 기타 발견 사항\n\n')
        f.write('- `LSMD_CONT_ZB001_부산.zip`은 행정구역 경계가 아니라 **지적재조사사업지구 등 기타경계**(117개 조각 폴리곤, EPSG:5186)임. '
                '행정경계 레이어가 필요하면 별도 원천(시군구 경계 SHP) 확보 필요 → 임포트 대상에서 제외\n')
        f.write('- `스마트 버스쉘터`의 sigun_gu에 구가 아닌 `부산시` 값 존재 (원천 그대로 유지)\n')
        f.write('- `부산광역시_교차로 정보.csv` 일부 행 sigun_gu 공백 (NULL로 적재)\n')
    print(f"=> {report}")


if __name__ == '__main__':
    main()
