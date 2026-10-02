# -*- coding: utf-8 -*-
"""정적 배포용 GeoJSON 내보내기 (Phase 4-B 프론트 연동)

왜 정적인가: 이 데이터는 100% 읽기 전용이다. 마이그레이션을 다시 돌릴 때만 바뀐다.
      즉 API는 "고정된 데이터셋에 대한 함수"라 빌드 시점에 파일로 구울 수 있다.
      그러면 지도가 서버 없이 항상 즉시 작동한다 — 무료 서버는 전부 쉰다
      (Render 15분 슬립 / Supabase 1주 미사용 정지 / Oracle 유휴 회수).
      백엔드는 Swagger 시연용으로 따로 올린다. (PLAN.md "배포" 절)

DB 접속: `.env`의 DB_* 값을 읽어 psql을 호출한다. psycopg2를 쓰지 않는 이유는
      이 프로젝트 파이썬 스크립트가 모두 외부 의존성 없이 돌기 때문이다
      (적재도 psql \\copy로 한다). 설치 단계를 늘리지 않는다.

출력: frontend/public/data/ — Vite가 빌드 산출물로 그대로 복사한다.
      vulnerability-grid.geojson   격자 13,439 + 속성 17개
      meta.json                    생성 시각·건수·속성 키 사전

속성 키를 2글자로 줄인 이유: 피처가 13,439개라 키 이름이 그대로 13,439번 반복된다.
      긴 이름을 쓰면 파일이 1.5배가 된다. 대신 뜻을 잃지 않도록 meta.json에
      키 사전을 함께 내보낸다 — 파일만 받아도 해독할 수 있다.

실행: py data/export_static.py
"""
import json
import os
import subprocess
import sys
import time

sys.stdout.reconfigure(encoding='utf-8')

BASE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(BASE)
OUT_DIR = os.path.join(ROOT, 'frontend', 'public', 'data')

# 좌표 소수 자릿수. 5자리 ≈ 1m — 250m 격자에 충분하고 6자리보다 파일이 작다
COORD_PRECISION = 5

CRIME_TYPE = 'bike_env_vuln'

# 격자 속성: (짧은 키, SQL 식, 설명)
#   설명은 meta.json에 그대로 실려 프론트·외부 사용자가 키를 해독하는 근거가 된다.
#   이 표가 키 매핑의 단일 출처다 — SQL도 meta.json도 여기서 생성된다.
GRID_PROPS = [
    ('gr', 's.grade',                                '등급 R/Y/G — 분위 기반(상위 10%/다음 20%/나머지)'),
    ('sc', 'round(s.score::numeric, 3)',             '환경 취약도 0~1 = 표적지수 × 환경위험'),
    ('ti', 'round(s.n_target::numeric, 3)',          '표적지수 = 0.15 + 0.85 × max(보관소500m, 0.5×인구)'),
    ('er', 'round(s.env_risk::numeric, 3)',          '환경위험 = 아래 6개 요인의 가중합'),
    # 정규화 요인 0~1 (괄호 안은 환경위험 가중치, 합 1.00)
    ('cl', 'round(s.n_cctv_lack::numeric, 3)',       'CCTV 부재 (0.30) — 실측에서 역인과가 확인된 항목'),
    ('ll', 'round(s.n_light_lack::numeric, 3)',      '보안등 부재 (0.21)'),
    ('nb', 'round(s.n_night_biz::numeric, 3)',       '심야업소 밀도 (0.21) — 상위권을 이끄는 요인'),
    ('pf', 'round(s.n_police_far::numeric, 3)',      '지구대 멂 (0.14)'),
    ('vc', 'round(s.n_vacancy::numeric, 3)',         '야간 공실화 (0.07)'),
    ('bf', 'round(s.n_bell_far::numeric, 3)',        '비상벨 멂 (0.07)'),
    # 원시값 — 팝업에서 사람이 읽을 근거. 정규화값 0.85만 보여주면 뜻을 알 수 없다
    ('rk', 'f.rack_cnt_500m',                        '반경 500m 내 자전거보관소 수'),
    ('bz', 'f.biz_cnt_500m',                         '반경 500m 내 심야업소 수'),
    ('cc', 'f.cctv_cnt_100m',                        '반경 100m 내 방범CCTV 수'),
    ('lt', 'f.light_cnt',                            '격자 내 보안등 수'),
    ('pp', 'round(f.pop_est::numeric, 0)',           '추정 인구 — 행정동 면적 비례 배분(산·농지에도 값이 붙는 한계)'),
    ('pd', 'round(f.police_dist_m::numeric, 0)',     '최근접 지구대·파출소 거리(m)'),
    ('bd', 'round(f.bell_dist_m::numeric, 0)',       '최근접 안전비상벨 거리(m)'),
]


def load_env():
    """.env에서 DB 접속 정보를 읽는다. 값은 출력하지 않는다(비밀번호 노출 방지)."""
    env = {}
    path = os.path.join(ROOT, '.env')
    if not os.path.exists(path):
        sys.exit('.env 가 없다: ' + path)
    with open(path, encoding='utf-8') as fp:
        for line in fp:
            line = line.strip()
            if not line or line.startswith('#') or '=' not in line:
                continue
            key, value = line.split('=', 1)
            env[key.strip()] = value.strip()
    return env


def find_psql():
    """psql 실행 파일 경로. PATH에 없는 환경이라 설치 위치를 함께 뒤진다."""
    candidates = ['psql']
    program_files = os.environ.get('ProgramFiles', r'C:\Program Files')
    pg_root = os.path.join(program_files, 'PostgreSQL')
    if os.path.isdir(pg_root):
        # 최신 메이저 버전부터 — 숫자 디렉터리만 본다
        versions = sorted((d for d in os.listdir(pg_root) if d.isdigit()),
                          key=int, reverse=True)
        candidates += [os.path.join(pg_root, v, 'bin', 'psql.exe') for v in versions]
    for candidate in candidates:
        try:
            subprocess.run([candidate, '--version'], capture_output=True, check=True)
            return candidate
        except (OSError, subprocess.CalledProcessError):
            continue
    sys.exit('psql 을 찾지 못했다. PATH 또는 PostgreSQL 설치 경로를 확인할 것')


def run_psql_to_file(psql, env, sql, out_path):
    """psql이 결과를 파일로 직접 쓰게 한다.

    stdout으로 파이프하지 않는 이유: 한글이 섞인 결과를 파이프로 받으면
    Windows 콘솔 인코딩과 충돌한다(plans 기록된 기존 함정). -o 로 파일에 바로 쓴다.
    """
    proc_env = dict(os.environ)
    proc_env['PGPASSWORD'] = env.get('DB_PASSWORD', '')
    proc_env['PGCLIENTENCODING'] = 'UTF8'
    cmd = [
        psql,
        '-h', env.get('DB_HOST', 'localhost'),
        '-p', env.get('DB_PORT', '5432'),
        '-U', env.get('DB_USER', 'postgres'),
        '-d', env.get('DB_NAME', 'postgres'),
        '-t', '-A',              # 헤더·정렬 없이 값만
        '-v', 'ON_ERROR_STOP=1',
        '-o', out_path,
        '-c', sql,
    ]
    result = subprocess.run(cmd, capture_output=True, text=True, env=proc_env,
                            encoding='utf-8', errors='replace')
    if result.returncode != 0:
        sys.exit('psql 실패:\n' + (result.stderr or '').strip())


def build_grid_sql():
    """격자 FeatureCollection을 DB가 통째로 만들어 돌려주게 한다.

    파이썬에서 조립하지 않는 이유: 13,439개 좌표를 파이썬으로 옮겨 다시 직렬화할
    이유가 없다. PostGIS가 GeoJSON을 만드는 게 가장 짧고 빠르다.
    """
    props = ', '.join("'{0}', {1}".format(key, expr) for key, expr, _ in GRID_PROPS)
    return """
        SELECT json_build_object(
                 'type', 'FeatureCollection',
                 'features', json_agg(
                     json_build_object(
                       'type', 'Feature',
                       'id', g.id,
                       'properties', json_build_object({props}),
                       'geometry', ST_AsGeoJSON(g.geom, {precision})::json
                     )
                 )
               )::text
        FROM digital_twin.risk_grid g
        JOIN digital_twin.risk_grid_score s  ON s.grid_id = g.id
        JOIN digital_twin.risk_grid_factor f ON f.grid_id = g.id
        WHERE s.crime_type = '{crime_type}'
    """.format(props=props, precision=COORD_PRECISION, crime_type=CRIME_TYPE)


def verify_geojson(path):
    """내보낸 파일을 다시 읽어 검사한다. 썼다고 맞는 게 아니다.

    확인: JSON으로 파싱되는지 / FeatureCollection인지 / 피처마다 좌표와 등급이 있는지.
    """
    with open(path, encoding='utf-8') as fp:
        data = json.load(fp)
    if data.get('type') != 'FeatureCollection':
        sys.exit('FeatureCollection 이 아니다: ' + str(data.get('type')))
    features = data.get('features') or []
    if not features:
        sys.exit('피처가 0개다 — 쿼리나 crime_type을 확인할 것')

    grades = {}
    missing_geom = 0
    for feature in features:
        grade = (feature.get('properties') or {}).get('gr')
        grades[grade] = grades.get(grade, 0) + 1
        geometry = feature.get('geometry') or {}
        if geometry.get('type') != 'Polygon' or not geometry.get('coordinates'):
            missing_geom += 1
    if missing_geom:
        sys.exit('폴리곤이 없는 피처 {0}개'.format(missing_geom))
    return len(features), grades


def main():
    env = load_env()
    psql = find_psql()
    os.makedirs(OUT_DIR, exist_ok=True)

    grid_path = os.path.join(OUT_DIR, 'vulnerability-grid.geojson')
    print('격자 내보내기 →', os.path.relpath(grid_path, ROOT))
    run_psql_to_file(psql, env, build_grid_sql(), grid_path)

    count, grades = verify_geojson(grid_path)
    size_mb = os.path.getsize(grid_path) / 1024 / 1024
    print('  피처 {0:,}개 / {1:.2f} MB'.format(count, size_mb))
    for grade in sorted(grades):
        print('    {0} : {1:,}'.format(grade, grades[grade]))

    meta = {
        'generatedAt': time.strftime('%Y-%m-%dT%H:%M:%S%z'),
        'source': 'digital_twin.risk_grid + risk_grid_score + risk_grid_factor',
        'crimeType': CRIME_TYPE,
        'coordPrecision': COORD_PRECISION,
        'gridCount': count,
        'gradeCounts': grades,
        # 키 사전 — 2글자 키의 뜻. 파일만 받아도 해독할 수 있게 함께 내보낸다
        'propertyKeys': {key: desc for key, _, desc in GRID_PROPS},
        # 지표의 성격을 데이터에 박아둔다. "예측"으로 오해되는 것을 막기 위함
        'note': ('절도 발생 예측이 아니다. 실측 대조에서 발생률과 음의 상관(-0.079, n=16)이 나왔고 '
                 '원인은 CCTV의 역인과다. 측정 대상은 "감시·조명 인프라 부족도"이며 '
                 '등급은 분위 기반(R = 상위 10%)이다. 근거: data/analysis/output/REPORT.md'),
    }
    meta_path = os.path.join(OUT_DIR, 'meta.json')
    with open(meta_path, 'w', encoding='utf-8') as fp:
        json.dump(meta, fp, ensure_ascii=False, indent=2)
    print('메타 내보내기 →', os.path.relpath(meta_path, ROOT))

    print('\n완료. 정적 호스트가 gzip을 걸면 실제 전송량은 약 0.6 MB다.')


if __name__ == '__main__':
    main()
