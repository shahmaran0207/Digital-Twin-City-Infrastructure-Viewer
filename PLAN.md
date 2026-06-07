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
- [ ] `setting.gradle` → `settings.gradle` 파일명 교정 + `rootProject.name` 설정
- [ ] `build.gradle` 의존성 정리
  - [ ] lombok: `compileOnly` + `annotationProcessor`로 교정 (현재 implementation만 — Gradle 빌드 깨짐)
  - [ ] MyBatis 제거 (JPA로 일원화 — 현재 둘 다 선언돼 있고 MyBatis는 미사용)
  - [ ] hibernate-spatial 중복 선언 정리 (버전 명시 1개만)
  - [ ] springdoc-openapi 추가 (API 문서 자동화)
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
- [ ] Gradle 빌드 성공 확인 (`gradlew build`)

## 0-3. 백엔드 도메인 재작성 (신규 스키마 정합)
- [ ] `FacilityTypeEntity` — `digital_twin.facility_type` 매핑 (code PK, name, nameKo, category, categoryKo)
- [ ] `FacilityEntity` — `digital_twin.facility` 매핑
  - [ ] geom GENERATED 컬럼 → `@Column(insertable=false, updatable=false)` 읽기 전용 처리
  - [ ] props jsonb 매핑 방식 결정 (hypersistence-utils vs String 보관)
  - [ ] 기존 `BaseFacilityEntity`/`SafetyCctvEntity`/`SafetyCctvRepository` 삭제
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

# Phase 1. 데이터 기반 구축 ✅ 완료

- [x] 부산시 공공데이터 수집 (`data/` 14종)
- [x] 데이터 1차 가공 (`data/process_data.py` → `processed/facility_all.csv`, 200,610행)
  - lat/lon 헤더 뒤바뀜 보정, 좌표 오류 복구 109건/제거 135건, ITS CCTV shapefile 추출
- [x] 스키마 재설계: 동일 구조 13개 테이블 → **통합 `facility` + `facility_type` 룩업** (`digital_twin` 스키마)
- [x] 마이그레이션 작성·적재·검증 (`migrations/` — geom GENERATED + GIST 인덱스)
- [x] PostGIS 3.6.2 설치 (로컬 PG18, 5432) / `.env` 외부화 / gitignore 정비
- [ ] ~~행정경계 레이어~~ 보류: LSMD zip은 지적재조사지구로 판명 — Phase 4에서 시군구 경계 필요 여부 재결정

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

# Phase 5. 대시보드 ⬜

- [ ] 차트 라이브러리 선정 (Recharts 우선 검토)
- [ ] 패널 1: 카테고리/유형별 시설물 수 (stats API)
- [ ] 패널 2: 시군구별 분포 (바 차트)
- [ ] 패널 3: 위기레벨 요약 — 등급별 격자 수, 위험 상위 구역 목록
- [ ] 지도 연동: 대시보드 항목 클릭 → 해당 구역/시설로 카메라 이동
- [ ] 대시보드 ↔ 레이어 필터 상태 동기화

# Phase 6. 품질·배포·마무리 ⬜

- [ ] 최종 성능 패스: 초기 로딩, 레이어 전환, 메모리 — 측정치 기록
- [ ] 시연 시나리오 작성 (발표 동선: 전체 뷰 → 레이어 → 상세 → 위기레벨 → 대시보드)
- [ ] README 완성: 아키텍처 다이어그램, 스크린샷/GIF, 실행 방법, 데이터 출처·가공 내역
- [ ] 보안 최종 점검: 비밀정보 히스토리 확인, Ion 토큰 교체 완료 확인
- [ ] (선택) 배포: 프론트 정적 호스팅 + 백엔드/DB 호스팅 여부 결정

---

## 진행 순서 (확정)

| 순위 | 작업 | 비고 |
|---|---|---|
| **0** | **Phase 0 전면 재설계+리팩터링** | 현재 백엔드는 옛 스키마 참조로 동작 불가 — 최우선 |
| 1 | Phase 2 백엔드 API | 0-3에서 만든 골격 위에 확장 |
| 2 | Phase 3-1~3-2 | 수직 슬라이스: 방범 CCTV를 지도에 띄울 때까지 |
| 3 | Phase 3-3~3-4 → 4 → 5 → 6 | 순차 진행, 각 착수 시 세부 계획 md 작성 |

## 세부 계획 파일 목록

작업 착수 시 여기에 링크 추가

| 파일 | 내용 | 상태 |
|---|---|---|
| [migrations/README.md](migrations/README.md) | DB 스키마 재설계 + 마이그레이션/적재 가이드 | ✅ 완료 |
| [data/processed/REPORT.md](data/processed/REPORT.md) | 데이터 1차 가공 리포트 (보정/제거 내역) | ✅ 완료 |
| [plans/phase0-redesign.md](plans/phase0-redesign.md) | Phase 0 설계 원칙 — 아키텍처, API 규칙, 좌표 포맷, 프론트 구조, 컨벤션 | ✅ 완료 |
