# 전체 계획 (PLAN.md)

> 문서 체계
> - **README.md** — 프로젝트의 가장 큰 틀 (메인 기준, CONTEXT.md와 다를 경우 README 우선)
> - **CONTEXT.md** — 프로젝트 컨텍스트 / 초기 플랜
> - **PLAN.md (이 문서)** — 전체 계획 + 진행 상태
> - **세부 계획** — 작업 단위별로 별도 md 파일 생성 (하단 목록에 링크)
>
> 진행 원칙: **확장성·유지보수성 우선.** 모든 구조 결정은 "시설물 유형/기능이 늘어나도 코드가 늘지 않는가"를 기준으로 판단

---

## 목표 (README 기준)

3D 공간 위에 시설물 / 장비 / 인프라 정보를 시각화하고,
**필터링 + 상세조회 + 위기레벨 색상 표시**까지 제공하는 서비스

---

---

## ⚠️ 작업 방식 규칙 (AI 반드시 준수 — 2026-06-15 합의)

> Phase 0 이후 모든 코드 작업에 적용. (.kiro/korean-language.md "진행 방식"의 Phase 0 운영 세칙)

- **AI가 직접 처리해도 되는 것** = 사소·기계적 정리: 파일명 교정, 파일 이동/삭제, 깨진 설정 파일 수선, 문서(PLAN/README 등) 갱신.
- **반드시 "코드 제시 → 사용자 직접 입력 → AI 검사 → 다음"으로 진행할 것** = 학습 대상 코드: `build.gradle` 이하 빌드 설정, 엔티티/리포지토리/서비스/컨트롤러/DTO, 프론트 컴포넌트 등 로직 코드.
  - AI는 이런 파일을 **직접 수정하지 않는다.** 대상 경로 + 넣을 위치 + 코드 덩어리(한 번에 파일/메서드 하나)를 제시만 한다.
  - 사용자가 입력 후 알리면 AI가 실제 파일을 읽어 검사(오타·누락·정합성)하고 통과해야 다음 덩어리로 간다.
- **예외**: 사용자가 "이건 네가 해줘"라고 명시하면 그 항목만 AI가 직접 수정.

---

# Phase 0. 전면 재설계 + 리팩터링 ⬜ ★ 0순위

> 목표: 이후 모든 기능이 올라갈 **뼈대를 완성**한다. 기능 추가 없이 구조만 완벽하게.
> 완료 기준: 백엔드 기동 → 신규 스키마 조회 E2E 통과 + 프론트 빌드/린트 클린

## 0-1. 설계 원칙 확정 (코드 작성 전 결정 사항) ✅ → [plans/phase0-redesign.md](plans/phase0-redesign.md)
- [x] 백엔드 아키텍처 스타일 확정: 레이어드 + `global`/`domain` 패키지 구분, 소문자 패키지명
- [x] API 설계 규칙 확정: 복수형 kebab-case / 단건 envelope 없음·목록은 `count·truncated·items` 래퍼 / RFC 7807 ProblemDetail + `code` 필드 / 페이징 미도입(`limit` 규약)
- [x] 좌표 데이터 전달 포맷 확정: 포인트 = 일반 JSON(lon/lat), 폴리곤(위기레벨 격자) = GeoJSON
- [x] 프론트 상태관리/폴더 구조 확정: feature 단위 구조 + TanStack Query 도입
- [x] 네이밍/컨벤션 문서화: 커밋 `type: 제목`, 브랜치 main + feature/*, 코드 스타일 표 작성

## 0-2. 백엔드 프로젝트 기반 정비
- [x] `setting.gradle` → `settings.gradle` 파일명 교정 + `rootProject.name` 설정 (2026-06-15, 깨진 `-Encoding UTF8` 꼬리 제거)
- [x] `build.gradle` 의존성 정리 (2026-06-20)
  - [x] lombok: `compileOnly` + `annotationProcessor`로 교정 (버전은 Boot BOM 위임)
  - [x] MyBatis 제거 (JPA로 일원화 — starter·core 2줄 삭제)
  - [x] hibernate-spatial 중복 선언 정리 (`org.hibernate.orm:hibernate-spatial` 1줄, 버전 생략)
  - [x] springdoc-openapi 추가 (`springdoc-openapi-starter-webmvc-ui:2.3.0`)
  - [x] MyBatis 제거로 빌드 막던 옛 `safety_cctv` 의존 6개 파일 삭제 (FacilityPointDTO/BaseFacilityEntity/SafetyCctvEntity/SafetyCctvRepository/FacilityService/FacilityController) — 어차피 0-3 재작성 대상. 남은 코드: Application/CorsConfig/HealthController
- [ ] 패키지 구조 재편: `com.Busan.CityView` → `com.busan.cityview` (Java 컨벤션) + 구조 확정
  ```
  com.busan.cityview
  ├─ global/        # config(Cors, OpenAPI), exception(ErrorCode, GlobalExceptionHandler), common(BaseResponse 등)
  └─ domain/
     └─ facility/   # controller / service / repository / entity / dto
  ```
- [ ] 설정 파일 재구성
  - [ ] `application.yml` 공통 + `application-local.yml` 분리 (프로파일 기반)
  - [ ] `ddl-auto: update` → `validate` (스키마 변경은 migrations로만)
  - [ ] show-sql/trace 로깅 → local 프로파일 한정
- [x] Gradle 빌드 성공 확인 (`gradlew build`) — 2026-06-20 BUILD SUCCESSFUL (test 포함)

## 0-3. 백엔드 도메인 재작성 (신규 스키마 정합)
- [ ] `FacilityTypeEntity` — `digital_twin.facility_type` 매핑 (code PK, name, nameKo, category, categoryKo)
- [ ] `FacilityEntity` — `digital_twin.facility` 매핑
  - [ ] geom GENERATED 컬럼 → `@Column(insertable=false, updatable=false)` 읽기 전용 처리
  - [ ] props jsonb 매핑 방식 결정 (hypersistence-utils vs String 보관)
  - [x] 기존 `BaseFacilityEntity`/`SafetyCctvEntity`/`SafetyCctvRepository` 삭제 (2026-06-20, 0-2 빌드 통과 과정에서 선행 제거)
- [ ] `FacilityRepository` — `findByFacilityType`, 카테고리 조인 조회, BBox 네이티브 쿼리 골격
- [ ] DTO 재설계: `FacilityPointResponse`(목록용 경량), `FacilityDetailResponse`(상세용), `FacilityTypeResponse`
- [ ] 공통 응답/예외: `ErrorCode` enum + `GlobalExceptionHandler`(@RestControllerAdvice) + 404/400 표준 응답
- [ ] 기존 API 호환 복구: `GET /api/facilities?type=safety_cctv` 동작 (기존 `/safety-cctv` 엔드포인트 대체)
- [ ] 단위/통합 테스트 기반: `@DataJpaTest`(로컬 DB 또는 Testcontainers 결정), 컨트롤러 슬라이스 테스트 1개 이상
- [ ] **검증 게이트**: 기동 → `/api/health` → `/api/facilities?type=safety_cctv` 12,085건 응답 확인

## 0-4. 프론트엔드 재설계
- [ ] 폴더 구조 재편 (feature 단위)
  ```
  src/
  ├─ app/          # App, 라우팅(필요 시), 전역 Provider
  ├─ shared/       # api 클라이언트(fetch 래퍼, 에러 처리), types, 상수(색상 팔레트 등), hooks
  ├─ features/
  │  ├─ map/       # Cesium Viewer 래퍼, 카메라 제어, 레이어 렌더러
  │  ├─ layers/    # 레이어 패널, on/off 상태
  │  └─ facility/  # 상세 팝업, 타입 정의
  └─ main.tsx
  ```
- [ ] API 클라이언트 레이어: base URL 환경변수화, 공통 에러 처리, 백엔드 DTO와 1:1 타입 정의 (`shared/types`)
- [ ] 기존 `api/test.ts`(health 핑) → 정식 health 체크 모듈로 대체 또는 제거
- [ ] 환경변수 정리: `VITE_API_BASE_URL` 실제 사용 (현재 8000 포트로 잘못 지정 → 8030 교정), 프록시 설정과 역할 정리
- [ ] Tailwind CSS 도입 + 기본 레이아웃 골격 (좌측 패널 / 지도 / 우측 영역)
- [ ] ESLint 통과 + `tsc -b` 클린 빌드 확인
- [ ] Cesium Ion 토큰 재발급 (히스토리 노출분 폐기) 후 `.env.development` 갱신

## 0-5. 개발 환경 재현성
- [ ] `docker-compose.yml`: PostGIS 컨테이너 (신규 참여자/PC 교체 대비) — 로컬 PG18과 병행 가능하게 포트 분리
- [ ] 루트 README 실행 가이드: DB 준비 → 가공 → 마이그레이션 → 백엔드 → 프론트 순서 한 번에
- [ ] (선택) GitHub Actions: 백엔드 build + 프론트 lint/build CI

---

# Phase 1. 데이터 기반 구축 ✅ (1-R 재구축 완료, 2026-06-15)

- [x] 부산시 공공데이터 수집 (`data/` 14종)
- [x] 데이터 1차 가공 (`data/process_data.py` → `processed/facility_all.csv`, 200,610행)
  - lat/lon 헤더 뒤바뀜 보정, 좌표 오류 복구 109건/제거 135건, ITS CCTV shapefile 추출
- [x] 스키마 재설계: 동일 구조 13개 테이블 → **통합 `facility` + `facility_type` 룩업** (`digital_twin` 스키마)
- [x] 마이그레이션 작성·적재·검증 (`migrations/` — geom GENERATED + GIST 인덱스)
- [x] PostGIS 3.6.2 설치 (로컬 PG18, 5432) / `.env` 외부화 / gitignore 정비
- [x] CSV 인코딩 UTF-8 BOM 통일 (2026-06-07)
  - 원천 CSV 12종 CP949 → UTF-8 BOM (깃허브에서 한글이 한자로 깨지던 문제 해결)
  - 가공 출력 `facility_all.csv`도 UTF-8 BOM으로 (엑셀에서 한글 깨지던 문제 해결)
  - 검증: 변환 전후 가공 결과 SHA256 해시 일치 (무손실), DB 적재는 HEADER 스킵으로 영향 없음
  - ⚠️ **정정(2026-06-08)**: 이 통일은 구버전 대상. 1-R 원천 재수집(2026-06-07)으로 **원천 12종은 다시 CP949(BOM 없음)** 상태 → 가공 재작업은 CP949로 읽어야 함 (1-R 구조분석 참고)
- [ ] ~~행정경계 레이어~~ 보류: LSMD zip은 지적재조사지구로 판명 — Phase 4에서 시군구 경계 필요 여부 재결정

## 1-R. 데이터 재구축 — 원천 데이터 교체 ✅ (2026-06-07 착수 ~ 2026-06-15 완료)

> 배경: 현재 `data/` 원천 CSV는 이전 가공 과정에서 컬럼이 축소된 버전
> (예: 노면방향표시 원본의 동명·리명·도로명·교차로명 제거, geom은 빈 placeholder).
> **실제 데이터를 새로 확보해 테이블 설계와 가공을 처음부터 다시 한다.**

- [x] 원천 데이터 출처 조사 → [data/SOURCES.md](data/SOURCES.md) (2026-06-07)
  - 교통안전시설 8종 = 공공데이터포털 "교통시설물관리시스템" 시리즈, 방범CCTV·버스쉘터는 최신 버전 존재
  - `_00` 접미사 2종(15분 도시공원, 어린이보호구역 CCTV)은 출처 미확정 — Big-데이터웨이브 추정
- [x] 실제 원천 데이터 재수집 — **11종 완료** (2026-06-07, 원본 컬럼 보존 확인 / 어린이보호구역 제외)
  - 방범CCTV 12,168 → **21,060행**으로 증가 + 장비종류·시설명칭 컬럼 추가, 교차로는 지번·코드 포함 12컬럼
  - ⚠️ **정정(2026-06-08)**: 어린이보호구역 CCTV는 원본 교체 실패 — 실제로는 **구가공본(컬럼 축소, 41행)뿐**임을 구조 분석에서 확인
- [x] **어린이보호구역 CCTV 원본 재확보** — 전국어린이보호구역표준데이터(15012891)로 **대체 완료(2026-06-15)**: 전국본→부산 **809건** 가공(보호구역 자체 위치, 구 단속CCTV 가공본 40건 대체). 좌표 위도/경도 컬럼 명시·시군구는 주소에서 추출, `facility_type` code 11을 `child_protection_zone`(어린이보호구역)으로 변경. **DB 재적재 완료(2026-06-15)**: facility 210,346, code 11 어린이보호구역 809건 적재 확인
- [x] 실시간 API·추가 데이터셋 조사 (2026-06-07) → [data/SOURCES.md](data/SOURCES.md) B·C·D절
  - 실시간: BIMS 버스위치, 링크소통(속도), ITS CCTV 영상, 에어코리아, 기상청, 재난문자, 조위, EV충전기 등
  - 정적 추가: GIS건물통합정보(3D), DEM, 표준노드링크, 시군구 경계, 대피장소, 격자인구 등
- [x] 시뮬레이션용 추가 데이터 다운로드 (2026-06-07, zip 그대로 `data/`에 보관)
  - `한반도.zip` — 브이월드 DEM 90m (5m 공개DEM은 추후 교체 검토)
  - `AL_D162_26_*.zip` ×2시점, `AL_D164_26_*.zip` ×2시점 — NSDI 건물통합정보 부산(코드 26) 추정
  - `[2026-01-13]NODELINKDATA.zip` — 표준노드링크 전국본
  - `emd_20230729.zip` — 읍면동 경계 (시군구 경계는 폐기됨 → 읍면동 dissolve로 생성 예정)
  - 지진해일 대피장소: 파일 미제공 → **표준데이터 OpenAPI 활용신청 완료** (호출은 미검증)
- [x] **zip 내용물 검증** (2026-06-08): 좌표계·컬럼·구성 확인 완료
  - 건물 D162(EPSG:5186, 23만)·D164(3.4만) 동일 스키마 → **D162(전체) + 최신본 20260115 채택**, 컬럼 A0~A39 역추정 완료(층수=A32·용도=A30·높이=A37 결측多)
  - 노드링크 EPSG:5186 전국본(부산 추출 필요), 읍면동 prj누락(5179 추정), ITS CCTV EPSG:4326
- [ ] ~~(보류) API 키 검증~~: DATA_KEY **활용신청 승인은 확인(2026-06-08)**. 실제 호출은 실시간 연동 시 미리보기로 — 보류
- [x] **새 원천 데이터 구조 분석** (2026-06-08): CSV 12종 헤더·인코딩·좌표·결측 파악
  - ⚠️ 원천 12종 실제 **CP949(BOM 없음)** — 99~102행의 "UTF-8 BOM 통일"은 1-R 재수집으로 무효화됨(가공은 CP949로 읽어야)
  - ⚠️ 좌표 헤더 순서가 파일마다 다름(경도먼저/위도먼저/x·y) → **값 범위로 lon/lat 판별** 필요
  - 어린이보호구역 CCTV는 구가공본(41건)뿐 — 원본 재확보 미해결
- [x] **테이블 재설계** (2026-06-08): 새 데이터 기준 스키마 확정 + 마이그레이션 작성·DDL 적용 완료
  - 통합 `facility` 유지 / 부가정보 **전부 props(jsonb)** + GIN 인덱스 (유형 늘어도 스키마 불변)
  - **시뮬레이션/경계 별도 테이블 7종**: `building`·`road_node`/`road_link`·`shelter`·`population_grid`·`admin_emd`(+시군구 뷰)·`dem_raster`
  - 마이그레이션 **V3~V7 신규 작성**, `pgrouting`·`postgis_raster` 확장 설치 + 빈 DB DDL 적용 검증 통과 (적재는 가공 후)
- [x] **데이터 가공 재작업** ✅ (1~4단계 완료, 2026-06-10) → [plans/data-rebuild.md](plans/data-rebuild.md)
  - 결정: 범위 = facility + 시뮬레이션 테이블 전체 / props = 원천 컬럼 전부 보존(한글 키) / DEM·shelter·population_grid 보류
  - [x] **1단계 facility 가공** (2026-06-09): `process_data.py` 재작성 — 좌표는 헤더 무시·값 범위로 lon/lat 자동판별(파일별 순서 제각각), props는 좌표·명칭 제외 전 컬럼 한글 키 보존 → `facility_all.csv` **209,578행** 재생성
    - 제거 59건 = 빈좌표(차선38)·범위밖 대만좌표(노면11)·소수점중복(방범CCTV7), 전부 원천 오류 (REPORT.md 기록)
  - [x] **2단계 building** (2026-06-10): `AL_D162_26_20260115.shp` **234,446** 폴리곤(EPSG:5186→4326) → `building.csv` (EWKT MultiPolygon, `process_sim.py`)
  - [x] **3단계 road_node/link** (2026-06-10): 표준노드링크 전국본 → 부산 추출 — node **61,121**(BBox 내) / link **86,896**(양끝 노드 모두 부산), source/target 적재 후 전건 부여
  - [x] **4단계 admin_emd** (2026-06-10): `emd.shp` 부산(코드26) **192**건 추출(prj누락 EPSG:5179→4326) + `admin_sigungu` dissolve 뷰
- [x] **DB 재적재 + 검증** ✅ (2026-06-10, 어린이보호구역 대체 반영 2026-06-15): facility 210,346 / building 234,446 / road_node 61,121 / road_link 86,896 / admin_emd 192 적재. 전 테이블 SRID=4326·ST_IsValid 통과(building 68·emd 3건 ST_MakeValid 보정)·부산 좌표 범위 확인. `import_data.ps1`에 EWKT \copy + source/target 부여 단계 추가
- [x] 영향 범위 반영: Phase 0-3 엔티티/DTO가 새 스키마와 정합하는지 확인 (2026-06-15) — 기존 `BaseFacilityEntity`/`SafetyCctvEntity`/`SafetyCctvRepository`/`FacilityPointDTO`(MyBatis `@Alias` 의존)는 전부 옛 `DigitalTwin.safety_cctv` 참조라 **새 스키마와 전혀 정합 안 됨** → Phase 0-3에서 전량 신규 작성으로 해소

# Phase 2. 백엔드 API ⬜ (Phase 0 완료 후)

## 2-1. 조회 API
- [ ] `GET /api/facility-types` — 유형 목록 (코드/이름/한글명/카테고리/건수 포함 여부 결정)
- [ ] `GET /api/facilities?type={name}` — 유형별 포인트 (경량 DTO, 직렬화 성능 측정)
- [ ] `GET /api/facilities?category={name}` — 카테고리 단위 조회
- [ ] `GET /api/facilities/{id}` — 상세 (props 포함)
- [ ] `GET /api/facilities/in-bbox` — 화면 영역 조회 (`ST_MakeEnvelope && geom`, 대용량 유형 대응)
  - [ ] type 필터 동시 적용, 최대 건수 제한(limit) + 초과 시 응답에 표시
- [ ] OpenAPI 문서 자동 생성 확인 (`/swagger-ui`)

## 2-2. 통계 API (대시보드 대비)
- [ ] `GET /api/stats/summary` — 유형/카테고리별 건수
- [ ] `GET /api/stats/by-sigungu` — 시군구별 집계 (sigungu 인덱스 활용)

## 2-3. 성능·품질
- [ ] 유형별 응답 시간 측정표 작성 (특히 차선 59k, 안전표지 57k)
- [ ] 느린 유형 대응 결정: BBox 강제 / 좌표 정밀도 축소 / gzip 압축 / 캐싱(@Cacheable) 중 택
- [ ] 통합 테스트: 엔드포인트별 정상/에러 케이스
- [ ] 실데이터 검증: 적재 건수와 API 응답 건수 대조 (13개 유형 전수)

# Phase 3. 프론트엔드 3D 뷰어 ⬜

## 3-1. 기본 지도
- [x] React + Vite + Cesium(Resium) 셋업, 프록시 연결
- [ ] 부산 초기 카메라 (시청 중심, 고도/각도 튜닝) + 카메라 이동 유틸 (`flyTo` 래퍼)
- [ ] 지형/건물: Cesium World Terrain + OSM Buildings 적용, Ion 무료 티어 사용량 확인
- [ ] 뷰어 옵션 정리 (불필요 위젯 제거, 성능 옵션: requestRenderMode 검토)

## 3-2. 레이어 렌더링 (핵심 난제: 유형당 최대 59k 포인트)
- [ ] 렌더링 PoC 비교 후 결정 (세부 계획 md 작성):
  - A. Entity + 클러스터링 (소량 유형용)
  - B. PointPrimitiveCollection 일괄 (대량 유형용)
  - C. BBox 단위 동적 로딩 (카메라 이동 이벤트 연동)
- [ ] 유형별 전략 매트릭스 확정 (예: ≤15k → B 일괄, >15k → C)
- [ ] 카테고리 5종 색상 팔레트 + 유형별 아이콘/포인트 스타일 정의 (`shared/constants`)
- [ ] 레이어 패널: 카테고리 → 유형 2단 트리, on/off 토글, 유형별 건수 표시
- [ ] 레이어 상태 관리 (켜진 레이어 set, 로딩/에러 상태)
- [ ] 동시 다레이어 표시 성능 측정 (FPS, 메모리) → 한계치 문서화

## 3-3. 상세조회
- [ ] 픽킹(클릭 → 시설물 식별) 구현 — Primitive 방식에서도 동작하게 id 매핑
- [ ] 상세 팝업 컴포넌트: 유형/시군구/좌표/props 표시
- [ ] ITS CCTV: props.url 실시간 영상 링크 (새 창 or iframe 임베드 검토)
- [ ] 선택 하이라이트 + 선택 해제 UX

## 3-4. UI/레이아웃
- [ ] 전체 레이아웃: 좌측 레이어 패널 / 중앙 지도 / 우측 상세·대시보드 슬롯
- [ ] 반응형 최소 대응 (시연 환경 해상도 기준)
- [ ] 로딩 인디케이터, 에러 토스트 공통화

# Phase 4. 위기레벨 시스템 ⬜

## 4-1. 분석 설계 (세부 계획 md 필수)
- [ ] 격자 크기 비교 (250m vs 500m) — `ST_SquareGrid` 샘플 생성 후 시각 밀도 확인
- [ ] 점수 산식 v1 확정:
  - CCTV 커버리지: 방범 CCTV 반경 N m (N 결정: 50/100m) 버퍼 밖 = 공백
  - 교차로 밀도: 격자 내 교차로 수 정규화
  - 어린이보호구역: 폴리곤 부재 → 단속 CCTV 포인트 반경 300m 버퍼로 근사 (한계 명시)
- [ ] 가중치 + 등급 컷오프(🟢🟡🔴) 결정, 산식 문서화 (대시보드/발표 설명용)

## 4-2. 구현
- [ ] `migrations/V3__risk_grid.sql`: 격자 생성 + 점수 계산 + MATERIALIZED VIEW (재계산 = REFRESH)
- [ ] 점수 분포 검증 (등급별 격자 수가 유의미하게 나뉘는지, 전부 🟢이면 산식 조정)
- [ ] `GET /api/risk-grid` — GeoJSON 폴리곤 + 등급 + 요소별 점수
- [ ] Cesium 오버레이: 반투명 색상 폴리곤 렌더링, 레이어 패널에 통합
- [ ] 격자 클릭 → 점수 상세(요소별 기여도) 팝업
- [ ] REFRESH(재계산) → 블록체인 앵커 훅 연결 (Phase 4.5-2 `AnchorService` 호출)

# Phase 4.5. 블록체인 데이터 무결성 앵커링 ⬜ (로컬 체인, 테스트넷 교체 가능)

> 목표: 공공데이터(facility)와 위기레벨 결과의 위변조 방지 + 감사 이력.
> 데이터셋 머클 루트를 로컬 EVM 컨트랙트에 기록하고, 개별 레코드를
> 머클 증명으로 검증. 위기레벨은 재계산마다 앵커해 변조 불가능한 시계열 이력 축적.
> 범위: 메인넷·실제 토큰 없음. 로컬 체인 "기록 → 검증 → 변조감지" 데모까지.

## 4.5-1. 설계 + 로컬 체인 셋업
- [ ] 앵커링 대상·카데던스 확정: facility(적재 시) + risk-grid(REFRESH 시) → [plans/blockchain.md](plans/blockchain.md)
- [ ] 머클 규칙 문서화: 레코드 정규화 → keccak256 → 머클 루트/증명
- [ ] 로컬 EVM 셋업: Hardhat 노드(포트/체인ID 고정), docker-compose 병행
- [ ] 컨트랙트 `DataAnchor.sol`: anchor(bytes32 root, string datasetId, uint version) + 이벤트 + 이력 조회
  - [ ] 테스트넷 교체 가능하게 네트워크/주소 설정 외부화
  - [ ] Hardhat 테스트 (기록·조회·이력 누적·중복 방지)

## 4.5-2. 백엔드 연동
- [ ] web3j 의존성 + 컨트랙트 래퍼 생성
- [ ] `MerkleService`: 데이터셋 → 머클 루트/증명 생성 (재현 가능한 정규화 규칙)
- [ ] `AnchorService`: 루트 계산 → anchor 트랜잭션 → tx/block/version 저장
- [ ] API: `GET /api/anchors`(이력), `GET /api/facilities/{id}/proof`(증명), 검증 엔드포인트
- [ ] 통합 테스트: 정상 검증 / 변조 레코드 검증 실패 / 이력 시계열 조회

## 4.5-3. 프론트 검증 UI
- [ ] 무결성 배지/패널: 최신 앵커(루트·tx·블록·버전·타임스탬프)
- [ ] 상세 팝업 "무결성 검증" 버튼 → 머클 증명으로 ✅/❌
- [ ] 위기레벨 앵커 이력 타임라인 (언제 어떤 루트로 기록됐는지)
- [ ] (데모) 변조 시뮬레이션 토글 → 검증 실패 시연

## 4.5-4. (선택) 테스트넷 실전 데모
- [ ] Sepolia 등 공용 테스트넷에 동일 컨트랙트 배포 → faucet 가스로 1회 실거래 시연

# Phase 5. 시뮬레이션 ⬜ → [plans/simulation.md](plans/simulation.md)

> 디지털 트윈의 핵심 차별 기능: "만약 ~라면" 시나리오 시각화.
> 후보 5종 조사 완료 — **✅ C안(전체 5종) 채택** (2026-06-07 사용자 결정). 구현 순서: 그림자 → 침수 → CCTV → 교통우회 → 대피

## 5-1. 범위 확정 + 데이터 준비
- [x] 채택안 결정: **C안** — 별도 테이블(building, road_node/link, shelter, population_grid) 1-R 재설계에 반영
- [ ] 시뮬레이션 입력 데이터 확보·적재: DEM(침수), 건물(그림자·차폐), 노드링크(교통·대피), 대피장소, 격자인구
- [ ] PostGIS raster + pgRouting 익스텐션 설치 확인

## 5-2. 구현 (C안 — 5종 전부, 난이도 순)
- [ ] **일조/그림자**: Cesium `viewer.shadows` + 시간 슬라이더 (난이도 하, 데이터 불요)
- [ ] **침수 (bathtub)**: 수위 슬라이더 → DEM 임계값 영역 표시. PostGIS 래스터 폴리곤화 또는 클라이언트 폴리곤 (난이도 하~중)
  - [ ] 침수흔적도(safemap WMS)와 비교 검증, 기상청 강우 API 연동 검토
- [ ] **CCTV 커버리지**: ST_Buffer+화각 부채꼴, 감시 공백 도출 — Phase 4 위기레벨과 연계 (난이도 하)
- [ ] **교통 우회**: pgRouting `pgr_dijkstra`, 링크 차단 전/후 경로 비교 (난이도 중)
- [ ] **대피**: 격자인구 → 최근접 대피장소 경로/도달시간 (난이도 중~상)
  - [ ] 침수 시뮬레이션과 연계: 해일 수위 → 침수 구역 → 대피 경로 시나리오

## 5-3. 공통 UX
- [ ] 시나리오 패널 (파라미터 입력: 수위/시간/차단 링크 선택)
- [ ] 시뮬레이션 결과 레이어 on/off — 기존 레이어 패널에 통합
- [ ] 결과 요약 카드 (침수 면적, 영향 시설물 수 등 — 대시보드 연계)

# Phase 6. 대시보드 ⬜

- [ ] 차트 라이브러리 선정 (Recharts 우선 검토)
- [ ] 패널 1: 카테고리/유형별 시설물 수 (stats API)
- [ ] 패널 2: 시군구별 분포 (바 차트)
- [ ] 패널 3: 위기레벨 요약 — 등급별 격자 수, 위험 상위 구역 목록
- [ ] 패널 4: 시뮬레이션 결과 요약 (Phase 5 연계 — 침수 영향 시설 수 등)
- [ ] 지도 연동: 대시보드 항목 클릭 → 해당 구역/시설로 카메라 이동
- [ ] 대시보드 ↔ 레이어 필터 상태 동기화

# Phase 7. 품질·배포·마무리 ⬜

- [ ] 최종 성능 패스: 초기 로딩, 레이어 전환, 메모리 — 측정치 기록
- [ ] 시연 시나리오 작성 (발표 동선: 전체 뷰 → 레이어 → 상세 → 위기레벨 → 대시보드)
- [ ] README 완성: 아키텍처 다이어그램, 스크린샷/GIF, 실행 방법, 데이터 출처·가공 내역
- [ ] 보안 최종 점검: 비밀정보 히스토리 확인, Ion 토큰 교체 완료 확인 → 세부 계획 [plans/security.md](plans/security.md) (단계 S5 = 이 점검과 합류)
- [ ] (선택) 배포: 프론트 정적 호스팅 + 백엔드/DB 호스팅 여부 결정

---

## 진행 순서 (확정)

| 순위 | 작업 | 비고 |
|---|---|---|
| **0** | **Phase 0 전면 재설계+리팩터링** | 현재 백엔드는 옛 스키마 참조로 동작 불가 — 최우선 |
| 1 | Phase 2 백엔드 API | 0-3에서 만든 골격 위에 확장 |
| 2 | Phase 3-1~3-2 | 수직 슬라이스: 방범 CCTV를 지도에 띄울 때까지 |
| 3 | Phase 3-3~3-4 → 4 → 4.5(블록체인 앵커링) → 5(시뮬레이션) → 6 → 7 | 순차 진행, 각 착수 시 세부 계획 md 작성 (4.5는 4의 위기레벨 결과를 앵커하므로 4 직후) |

## 세부 계획 파일 목록

작업 착수 시 여기에 링크 추가

| 파일 | 내용 | 상태 |
|---|---|---|
| [migrations/README.md](migrations/README.md) | DB 스키마 재설계 + 마이그레이션/적재 가이드 | ✅ 완료 |
| [data/processed/REPORT.md](data/processed/REPORT.md) | 데이터 1차 가공 리포트 (보정/제거 내역) | ✅ 완료 |
| [plans/phase0-redesign.md](plans/phase0-redesign.md) | Phase 0 설계 원칙 — 아키텍처, API 규칙, 좌표 포맷, 프론트 구조, 컨벤션 | ✅ 완료 |
| [data/SOURCES.md](data/SOURCES.md) | 데이터 출처 총정리 — 보유분 출처 + 실시간 API + 추가 데이터셋 + 수집 우선순위 | ✅ 작성 |
| [plans/simulation.md](plans/simulation.md) | 시뮬레이션 기능 설계 — 후보 5종, 필요 데이터, 난이도, 추천 조합 A/B/C | ✅ 작성 (채택안 결정 대기) |
| [plans/data-rebuild.md](plans/data-rebuild.md) | 데이터 가공 재작업 설계 — 원천→테이블 매핑, 좌표 자동판별, props 규칙, 단계별 진행 | ✅ 1~4단계 완료 (5·6 보류) |
| [plans/blockchain.md](plans/blockchain.md) | 블록체인 무결성 앵커링 설계 — 앵커 대상·카데던스, 머클 규칙, 컨트랙트/web3j 연동, 검증 UI | ⬜ 착수 시 작성 (Phase 4.5) |
| [plans/security.md](plans/security.md) | 보안 강화 계획 — 현황 진단(취약점 11종), STRIDE 위협모델, 영역별 하드닝, 우선순위 단계(S1~S5) | ✅ 작성 (S1~S2는 Phase 0과 합류) |
