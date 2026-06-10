# 데이터 가공 재작업 설계 (Phase 1-R)

> 2026-06-09 작성. PLAN.md 140~144행 "데이터 가공 재작업"의 세부 설계.
> 배경: 새 원천(원본 컬럼 보존) 재수집 완료 → 기존 `process_data.py`(구버전 가정)를 폐기하고 재작성.

## 결정 사항 (사용자 확정)

| 항목 | 결정 |
|---|---|
| 작업 범위 | facility + 시뮬레이션 테이블 **전부** (단, 이번 실행은 1~4단계) |
| props 구성 | 원천 컬럼 **전부 보존** (좌표·명칭 컬럼만 제외, 한글 키 그대로) |
| DEM 래스터(5단계) | **Phase 5로 미룸** (raster2pgsql 별도 작업) |
| shelter / population_grid | **보류** — 원천 파일 미확보, DDL 골격만 유지 |

## 원천 → 테이블 매핑 (실측 기준)

### facility (포인트 13종) — `processed/facility_all.csv`
- **좌표 판별**: 헤더 라벨 신뢰 불가(노면문자표시는 헤더가 `위도,경도` 역순). 끝 2컬럼 중
  **값 ∈ (128.5,129.5) → lon / 값 ∈ (34.8,35.7) → lat** 로 자동 배정 (두 범위는 안 겹침).
- **props**: 좌표 2컬럼 + 명칭 컬럼을 제외한 나머지 원천 컬럼을 한글 키 그대로 jsonb. 빈 값은 제외.
- **name**: 명칭성 컬럼이 있는 유형만 채움(공원명·정류소명·시설명·CCTV name 등).
- 도시공원(9)은 신규본 `부산광역시_15분 도시공원_20251119.csv` 사용, 구가공본 `15분 도시공원_00.csv` 제외.
- 어린이보호구역(11)은 구가공본 41행뿐 — 그대로 적재 + 한계 기록(원본 재확보는 미해결 숙제).
- ITS CCTV(12)는 SHP, **인코딩 utf-8**(cp949 아님), 필드 id·name·lng·lat·url → props={url}.

| code | 파일 | 인코딩 | 좌표 위치 |
|---|---|---|---|
| 0 차선 | 부산광역시_차선정보_20220630.csv | cp949 | 끝2 (경도,위도) |
| 1 안전표지 | 부산광역시_안전표지 정보.csv | cp949 | 끝2 (경도,위도) |
| 2 노면방향 | 부산광역시_노면방향표시 정보_20220630.csv | cp949 | 끝2 (경도,위도) |
| 3 노면문자 | 부산광역시_노면문자표시 정보_20220630.csv | cp949 | 끝2 (**위도,경도** 역순) |
| 4 철주 | 부산광역시_철주정보_20220630.csv | cp949 | 끝2 (경도,위도) |
| 5 부착대 | 부산광역시_부착대 정보_20220630.csv | cp949 | 끝2 (경도,위도) |
| 6 방범CCTV | 부산광역시_방범용CCTV 정보_20241231(공공데이터포털).csv | cp949 | 끝2 (**위도,경도**) |
| 7 안전지대 | 부산광역시_안전지대 정보_20220630.csv | cp949 | 끝2 (경도,위도) |
| 8 교차로 | 부산광역시_교차로 정보.csv | cp949 | 끝2 (경도,위도) |
| 9 도시공원 | 부산광역시_15분 도시공원_20251119.csv | cp949 | 끝2 (x,y=경도,위도) |
| 10 스마트쉘터 | 스마트 버스쉘터 설치 현황.csv | cp949 | 끝2 (x,y=경도,위도) |
| 11 어린이보호구역CCTV | 어린이보호구역 내 불법주정차 CCTV설치현황_00.csv | cp949 | 끝2 (x,y) |
| 12 ITS CCTV | (zip) tl_tracffic_cctv_info.shp | utf-8 | lng,lat 필드 |

### building — `processed/building.csv` (EWKT)
- 원천 `AL_D162_26_20260115.shp` (폴리곤 234,446건), prj 기반 **EPSG:5186 → 4326**.
- A0~A39 매핑: A0→source_id, A3+A6→addr, A12→name, A24→total_area, A28→struct,
  A30→main_use, A32→floors_above, A33→floors_below, A37→height_m,
  height_est = (A37>0 ? A37 : A32×3.3). 나머지 A*는 props.
- geom: MultiPolygon EWKT (`SRID=4326;MULTIPOLYGON(...)`).

### road_node / road_link — `processed/road_node.csv`, `road_link.csv` (EWKT)
- 원천 `MOCT_NODE.shp`(117만)/`MOCT_LINK.shp`(155만) 전국본, prj 기반 **EPSG:5186 → 4326**.
- **부산 추출**: 변환 후 좌표가 부산 BBox 안인 노드만 → 그 노드(F/T)에 연결된 링크만.
- source/target: node_id → road_node.id 매핑(가공 시 채움) 또는 적재 후 DB에서 부여.
  cost = LENGTH(없으면 geom 길이), reverse_cost는 일단 cost와 동일(일방통행 정보 없음).
- 나머지 필드(ROAD_NO·ROAD_USE 등)는 props.

### admin_emd — `processed/admin_emd.csv` (EWKT)
- 원천 `emd.shp`(5,065건 전국), **prj 없음 → EPSG:5179 가정 → 4326**.
- 부산(`EMD_CD` 앞 2자리 `26`)만 추출. sigungu는 코드 앞5자리 매핑 또는 후속 보완.
- geom: MultiPolygon EWKT. 시군구 경계는 `admin_sigungu` 뷰(DB dissolve)로 자동 파생.

## 적재 경로
- psycopg 미설치 → **psql `\copy`로 통일**.
- 포인트(facility)는 lon/lat 컬럼 → geom은 GENERATED.
- 폴리곤·라인(building/road/admin)은 **EWKT를 CSV에 담아** geometry 컬럼에 직접 `\copy`
  (PostGIS geometry 입력 함수가 EWKT 파싱). `import_data.ps1`에 단계 추가.

## 스크립트 구성
- `data/process_data.py` — facility 가공(CSV12 + ITS) → `facility_all.csv` (기존 파일 재작성).
- `data/process_sim.py` — building/road/admin SHP 가공(pyproj 의존) → 각 EWKT CSV (신규).
  - 분리 이유: facility는 자주 돌리는 핵심·가벼움 / sim은 무겁고 pyproj 의존·드물게 실행.

## 진행 단계 (각 단계 뒤 적재·건수 검증 게이트)
1. **facility 재생성** (CSV12+ITS) → 적재 → 유형별 건수 검증  ★백엔드 즉시 의존
2. **building** 23만 → EWKT CSV → 적재
3. **road_node/link** 부산 추출 → 적재 → 토폴로지(source/target)
4. **admin_emd** 부산 추출 → 적재 (+ sigungu 뷰 확인)
5. ~~DEM raster2pgsql~~ → Phase 5
6. ~~shelter/population_grid~~ → 데이터 확보 후

## 검증 기준
- 적재 건수 = 가공 출력 행수(부산 범위/복구불가 제거분 제외)와 일치.
- facility: 부산 좌표 CHECK 제약 통과(범위 밖이면 적재 자체가 실패).
- geom 자동 생성 확인(facility), EWKT 적재분은 `ST_IsValid`/SRID=4326 확인.
- 가공 리포트 `processed/REPORT.md` 갱신(파일별 원본행→적재행, 제거/보정 내역).
