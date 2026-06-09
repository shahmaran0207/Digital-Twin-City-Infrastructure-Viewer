# DB 마이그레이션

## 구성

| 파일 | 내용 |
|---|---|
| `V1__init_schema.sql` | `digital_twin` 스키마, `facility_type` 룩업, 통합 `facility` 테이블, 인덱스(GIST/GIN) |
| `V2__seed_facility_type.sql` | 시설물 유형 코드 0~12 시드 |
| `V3__building.sql` | `building` — GIS건물통합정보 폴리곤 (그림자/침수 차폐, 3D 압출) |
| `V4__road_network.sql` | `road_node`/`road_link` — 표준노드링크 부산 추출 + `pgrouting` 확장 (교통·대피) |
| `V5__shelter_population.sql` | `shelter`(대피장소)/`population_grid`(격자인구) — 대피 시뮬레이션 입력 |
| `V6__admin_emd.sql` | `admin_emd` 읍면동 경계 + `admin_sigungu` 시군구 dissolve 뷰 |
| `V7__dem.sql` | `dem_raster` — 수치표고모델 + `postgis_raster` 확장 (침수 bathtub) |
| `import_data.ps1` | 마이그레이션 실행(V1~V7) + `data/processed/facility_all.csv` 적재 (재실행 가능) |

> V3~V7은 1-R 테이블 재설계(2026-06-08)에서 추가. `facility`(포인트 시설)와 별도로,
> geometry 타입이 다른 시뮬레이션/경계 데이터(폴리곤·라인·래스터)를 담는다.
> 유형별 부가속성은 `facility.props(jsonb)`에 보관(전부 props 방식) — 유형이 늘어도 스키마 불변.
> 시뮬레이션 테이블 적재는 가공 재작업(`process_data.py`) 후 진행 (현재 DDL만 적용됨).

## 실행 순서

```powershell
# 1. 데이터 가공 (data/processed/facility_all.csv 생성)
py data/process_data.py

# 2. 마이그레이션 + 적재 (psql 필요)
#    DB 접속정보는 프로젝트 루트 .env에서 읽음 (.env.example 참고해 생성)
.\migrations\import_data.ps1
```

## 설계 변경 요약 (기존 → 신규)

| 항목 | 기존 | 신규 |
|---|---|---|
| 스키마 | `"DigitalTwin"` (따옴표 필수) | `digital_twin` |
| 테이블 | 동일 구조 13개 (safety_cctv, cross_road, …) | **통합 `facility` 1개** + `facility_type` 룩업 |
| id | `numeric` 수동 입력 | `bigint IDENTITY` (원천 id는 `source_id`로 보존) |
| geom | 적재 후 수동 `UPDATE … ST_SetSRID` | **GENERATED 컬럼** (lon/lat에서 자동 생성) |
| 인덱스 | PK만 존재 | GIST(geom) + facility_type + sigungu |
| 좌표 검증 | 없음 | CHECK 제약 (부산 범위) |
| 추가 속성 | 없음 | `name`, `props jsonb` (ITS CCTV url 등) |

### facility_type 코드

| 코드 | name | 한글명 | 카테고리 |
|---|---|---|---|
| 0 | traffic_lane | 차선 | 교통 인프라 |
| 1 | safety_sign | 안전표지 | 도로 시설물 |
| 2 | road_direction | 노면방향표시 | 교통 인프라 |
| 3 | road_mark | 노면문자표시 | 교통 인프라 |
| 4 | steel_pole | 철주 | 도로 시설물 |
| 5 | attachment_board | 부착대 | 도로 시설물 |
| 6 | safety_cctv | 방범용 CCTV | 안전·방범 |
| 7 | safety_zone | 안전지대 | 도로 시설물 |
| 8 | cross_road | 교차로 | 교통 인프라 |
| 9 | city_park | 도시공원 | 생활공간 |
| 10 | smart_shelter | 스마트 버스쉘터 | 대중교통 |
| 11 | illegal_parking_cctv | 어린이보호구역 단속 CCTV | 안전·방범 |
| 12 | its_cctv | ITS 교통 CCTV | 교통 인프라 |

기존 테이블명 대비: `road_sign`→`road_mark`(노면문자), `safety_signal`→`safety_sign`(안전표지),
`train_info`→`steel_pole`(철주 오역 교정), `illigeal_cctv`→`illegal_parking_cctv`(오타 교정)

## 백엔드 반영 필요 사항 (별도 작업)

통합 테이블로 바뀌므로 백엔드는 아래처럼 단순해짐:

- `SafetyCctvEntity` → `FacilityEntity` 하나로 통합 (`@Table(name = "facility", schema = "digital_twin")`)
- `SafetyCctvRepository` → `FacilityRepository.findByFacilityType(int code)`
- API: `/api/facilities/safety-cctv` → `/api/facilities?type=safety_cctv` (facility_type 조인)
- 시설물 13종을 엔티티 추가 없이 전부 서비스 가능
