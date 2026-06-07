# Phase 0-1. 설계 원칙 확정

> PLAN.md Phase 0-1의 결정 사항을 기록하는 문서.
> 이후 0-2(백엔드 정비), 0-3(도메인 재작성), 0-4(프론트 재설계)는 전부 이 문서를 기준으로 진행한다.
> 판단 기준: **"시설물 유형/기능이 늘어나도 코드가 늘지 않는가"** (PLAN.md 진행 원칙)

---

## 1. 백엔드 아키텍처 스타일

**결정: 레이어드(Controller → Service → Repository) + 도메인 패키지 구분**

```
com.busan.cityview
├─ global/                      # 도메인과 무관한 횡단 관심사
│  ├─ config/                   #   CorsConfig, OpenApiConfig
│  ├─ exception/                #   ErrorCode(enum), GlobalExceptionHandler
│  └─ common/                   #   공통 응답 래퍼(목록 메타), 공용 유틸
└─ domain/
   └─ facility/                 # 시설물 도메인 (이후 risk, stats 등 도메인 추가 시 형제 패키지로)
      ├─ controller/
      ├─ service/
      ├─ repository/
      ├─ entity/
      └─ dto/
```

- 패키지명은 전부 소문자 (`com.Busan.CityView` → `com.busan.cityview`, Java 컨벤션)
- 새 도메인(위기레벨, 통계)이 생기면 `domain/` 아래 패키지 추가 — 기존 코드 수정 없음
- DTO 변환은 Service 책임. Controller는 HTTP 바인딩/검증만, Repository는 영속성만
- Entity를 Controller 응답으로 직접 노출하지 않는다 (반드시 DTO 경유)

## 2. API 설계 규칙

### URL 네이밍
- 리소스는 **복수형 + kebab-case**: `/api/facilities`, `/api/facility-types`, `/api/risk-grid`
- prefix는 `/api` 고정 (프론트 프록시 기준점)
- 필터는 쿼리 파라미터: `/api/facilities?type=safety_cctv`, `?category=safety`
- 화면 영역 조회는 `/api/facilities/in-bbox?minLon=..&minLat=..&maxLon=..&maxLat=..`

### 응답 포맷
- **성공 단건: envelope 없이 DTO 그대로** — 단순하고 springdoc 문서화가 깔끔함
- **성공 목록: 메타 포함 래퍼 고정** — 대용량 유형(차선 59k)의 limit 초과 표시가 필요하므로

```json
{
  "count": 12085,
  "truncated": false,
  "items": [ { "id": 1, "lon": 129.07, "lat": 35.17 } ]
}
```

### 에러 응답
- **RFC 7807 ProblemDetail 채택** (Spring Boot 3 내장 `ProblemDetail` 사용)
- `ErrorCode` enum으로 코드 일원화, `code` 확장 필드 추가

```json
{
  "type": "about:blank",
  "title": "Not Found",
  "status": 404,
  "detail": "facility 999999 not found",
  "code": "FACILITY_NOT_FOUND"
}
```

### 페이징 규약
- 지도용 포인트 조회는 **페이징 미적용** (Cesium이 전량 또는 BBox 단위로 소비)
- 대신 **limit 규약**: `?limit=N` (서버 상한 존재), 초과 시 `truncated: true`
- 표 형태 조회가 생기면 그때 `page`/`size`/`sort` 표준 파라미터 도입 (현재 미도입)

## 3. 좌표 데이터 전달 포맷

**결정: 포인트는 일반 JSON(lon/lat 숫자 필드), 폴리곤은 GeoJSON**

| 데이터 | 포맷 | 이유 |
|---|---|---|
| 시설물 포인트 (최대 59k건) | `{ "id": 1, "lon": 129.07, "lat": 35.17 }` | Cesium `Cartesian3.fromDegrees(lon, lat)` 직접 소비. GeoJSON 대비 페이로드 절반 이하, 직렬화 비용 최소 |
| 위기레벨 격자 폴리곤 (Phase 4) | GeoJSON `FeatureCollection` | Cesium `GeoJsonDataSource`가 폴리곤을 그대로 로드 |

- 순서는 항상 **lon, lat** (PostGIS `ST_X/ST_Y`, GeoJSON, Cesium 모두 lon 선행 — 원천 CSV의 lat/lon 뒤바뀜 사고 재발 방지 차원에서 명시)
- 좌표 정밀도: 소수 6자리(약 0.1m)면 충분 — 직렬화 시 반올림 여부는 Phase 2-3 성능 측정 후 결정

## 4. 프론트엔드 상태관리 / 폴더 구조

**결정: feature 단위 구조 + TanStack Query 도입**

```
src/
├─ app/          # App, 전역 Provider(QueryClientProvider), 라우팅(필요 시)
├─ shared/
│  ├─ api/       # fetch 래퍼 (base URL 환경변수, 에러 → 예외 변환)
│  ├─ types/     # 백엔드 DTO와 1:1 타입 (FacilityPoint, FacilityDetail, FacilityType)
│  └─ constants/ # 카테고리 색상 팔레트, 유형별 스타일
├─ features/
│  ├─ map/       # Cesium Viewer 래퍼, 카메라 제어, 레이어 렌더러
│  ├─ layers/    # 레이어 패널, on/off 상태
│  └─ facility/  # 상세 팝업
└─ main.tsx
```

- **서버 상태는 TanStack Query**: 레이어 on→off→on 시 캐시 재사용(59k 재요청 방지), 로딩/에러 상태 내장 — 수동 fetch + useState 조합 대비 코드량 감소
- **클라이언트 상태(켜진 레이어 set, 선택된 시설물)는 React 상태로 시작** — 전역 상태 라이브러리(zustand 등)는 props drilling이 실제로 아파질 때 도입
- Cesium 객체(Viewer, PrimitiveCollection)는 React 상태에 넣지 않는다 — ref로 관리 (직렬화 불가·리렌더 유발 방지)

## 5. 네이밍 / 컨벤션

### 커밋 메시지
```
<type>: <제목 — 한국어 가능>

(필요 시 본문)
```
- type: `feat` `fix` `refactor` `docs` `chore` `data` (데이터 가공/적재는 `data`)
- 예: `feat: 시설물 유형별 조회 API 추가`, `refactor: 패키지 구조 com.busan.cityview로 재편`

### 브랜치 전략
- `main` + `feature/*` (예: `feature/phase0-backend`)
- 1인 개발 단계에서는 main 직접 커밋 허용, 단 **빌드 깨진 상태로 커밋 금지** (Phase 0-2 완료 후부터 적용)

### 코드 스타일
| 영역 | 규칙 |
|---|---|
| Java | 패키지 소문자, 클래스 PascalCase, 메서드/필드 camelCase. DTO 접미사: 요청 `~Request`, 응답 `~Response` |
| TypeScript | ESLint 기본 + `tsc -b` 클린 유지. 컴포넌트 PascalCase, 훅 `use~` |
| SQL/DB | 스키마·테이블·컬럼 snake_case (현행 `digital_twin` 유지). 마이그레이션 `V{n}__{설명}.sql` |
| API | URL kebab-case 복수형, 쿼리 파라미터 camelCase (`minLon`), JSON 필드 camelCase |

---

## 결정 요약표

| # | 항목 | 결정 |
|---|---|---|
| 1 | 백엔드 아키텍처 | 레이어드 + `global`/`domain` 패키지, 소문자 패키지명 |
| 2 | URL | 복수형 kebab-case, `/api` prefix, 필터는 쿼리 파라미터 |
| 3 | 응답 envelope | 단건 없음 / 목록은 `count·truncated·items` 래퍼 |
| 4 | 에러 포맷 | RFC 7807 ProblemDetail + `code` 확장 필드 |
| 5 | 페이징 | 미도입, `limit` + `truncated` 규약으로 대응 |
| 6 | 좌표 포맷 | 포인트 = 일반 JSON `lon`/`lat`, 폴리곤 = GeoJSON |
| 7 | 프론트 구조 | feature 단위 (`app`/`shared`/`features`) |
| 8 | 서버 상태 | TanStack Query 도입 |
| 9 | 커밋/브랜치 | `type: 제목`, main + feature/* |
