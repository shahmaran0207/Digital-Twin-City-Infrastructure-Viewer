# 보안 강화 계획 (security.md)

> 목표: 이 프로젝트의 보안 등급을 **"시연용 토이"에서 "운영 가능 수준"**까지 끌어올린다.
> 원칙: 우선순위(P0~P3)로 단계화한다. P0(치명적)부터 막고, 과한 보안으로 개발 속도를 죽이지 않는다.
> ⚠️ 이 문서는 **계획**이다. 라이브러리/아키텍처처럼 되돌리기 어려운 항목은 "결정 필요" 표시 — 사용자가 선택한 뒤 착수한다.

---

## 0. 이 프로젝트의 보안 특성 (먼저 합의할 전제)

- **[1]** **데이터 대부분이 공개 공공데이터** → 조회 API는 기밀성보다 **무결성·가용성**이 중요.
- **[2]** **핵심 차별 가치 = 블록체인 무결성 앵커링** → "데이터가 위변조되지 않았음"을 증명하는 게 프로젝트의 본질. 보안 계획의 무게중심을 여기 둔다.
- **[3]** **현재는 포트폴리오/시연 단계** → 인증이 필요한 사용자 데이터가 아직 없음. 하지만 "극강 보안"을 목표로 하므로 **운영 배포를 가정**하고 설계한다.
- **[4]** 즉, 위협 우선순위: **① 데이터 위변조 ② 비밀정보 유출 ③ 인프라 침해(서버·DB) ④ 서비스 거부(DoS)** 순.

---

## 1. 현황 진단 (발견된 취약점) — [항목 5] (V1~V11 묶음)

| # | 영역 | 현재 상태 | 위험 | 우선순위 |
|---|---|---|---|---|
| V1 | 인증/인가 | Spring Security 미도입, 모든 API 무인증 | 관리/쓰기 API 추가 시 무방비 | P1 |
| V2 | DB 스키마 | `ddl-auto: update` | 앱이 운영 스키마를 마음대로 변경 → 무결성·가용성 위협 | **P0** |
| V3 | 로깅 | `show-sql: true`, SQL/바인딩 `trace` 전역 | 운영 로그에 쿼리·파라미터(개인정보 가능) 노출 + 성능 | P1 |
| V4 | CORS | `allowedOrigins("http://localhost:5000")` 하드코딩 | 환경별 분리 안 됨, 운영 도메인 미반영 | P2 |
| V5 | 비밀관리 | DB 비번 `.env` 외부화(양호) / **Cesium Ion 토큰 깃 히스토리 노출** | 토큰 도용 → Ion 사용량/과금 탈취 | **P0** |
| V6 | 보안 헤더 | 미설정 (CSP, HSTS, X-Frame-Options 등) | XSS·클릭재킹·MITM 노출 | P2 |
| V7 | 입력 검증 | 표준화 안 됨 (BBox·type 파라미터 등) | SQLi(네이티브 쿼리)·과대 요청 | P1 |
| V8 | 전송 보안 | HTTP (TLS 미적용) | 평문 전송, MITM | P1 (배포 시 P0) |
| V9 | 에러 처리 | 표준 핸들러 미완 (Phase 0-3 예정) | 스택트레이스·내부정보 누출 | P2 |
| V10 | 의존성 | 취약점 스캔 없음 | 알려진 CVE 방치 | P2 |
| V11 | 의존성 핀 | Boot BOM 위임(양호) / 스냅샷·플러그인 버전 점검 미실시 | 공급망 | P3 |

---

## 2. 위협 모델 (STRIDE 요약)

- **[6] Spoofing(위장)**: 관리 API 추가 시 인증 부재 → V1.
- **[7] Tampering(위변조)**: 공공데이터·위기레벨 결과 조작 → **블록체인 앵커링으로 대응**(핵심). DB 직접 변조도 앵커 검증으로 탐지.
- **[8] Repudiation(부인)**: 앵커 이력(tx/block/version)이 곧 감사 로그 역할.
- **[9] Information Disclosure(정보노출)**: 비밀정보(V5), 로그(V3), 에러(V9), 전송(V8).
- **[10] Denial of Service(가용성)**: 대용량 유형(59k 포인트) 무제한 조회 → Rate limit·limit 강제(V7 연계).
- **[11] Elevation of Privilege(권한상승)**: DB 계정 최소권한·앱 전용 계정으로 차단.

---

## 3. 영역별 강화 항목

### [12] 3-1. 비밀정보 관리 (P0)
- [x] **Cesium Ion 토큰 즉시 재발급** + 노출분 폐기 (2026-06-30, 옛 토큰 revoke·새 토큰 발급(`assets:read`+`geocode`)·도메인 제한, `.env.development`에 반영 확인).
- [x] 깃 히스토리 스캔: `gitleaks`로 과거 커밋 전수 점검 (2026-06-30, gitleaks v8.30.1, 41커밋 스캔 → **신규 비밀 0건**, Ion 토큰 1건만 탐지(재발급으로 무효화·결정 A로 히스토리 유지)).
  - [x] 알려진 무효 토큰 1건을 `.gitleaksignore`에 fingerprint로 등록 (2026-07-01). 루트 재스캔 결과 **`no leaks found`(exit 0)** → 향후 스캔·CI 게이트(S4 3-9)에서 노이즈 제거, 신규 유출만 탐지. 유효 비밀은 재발급·폐기 후에만 등록하는 원칙 주석 명시.
  - 결정 필요 ▶ **히스토리에 비밀이 남아있을 경우**: (A) 토큰만 폐기·재발급하고 히스토리는 둔다(간단, 노출분 무효화로 충분) / (B) `git filter-repo`로 히스토리 재작성(깨끗하지만 협업 시 충돌·강제푸시 위험). **추천: A** (공개 토큰류는 폐기로 충분, 히스토리 재작성은 리스크 대비 실익 적음).
- [x] `.gitignore`에 `.env`·키파일 확정 (2026-06-30, 루트 `.env`/`.env.*` 확인 + `frontend/.gitignore`에도 명시 추가).
- [x] `.env.example` 제공(값 없이 키 목록만) — 루트·`frontend/` 모두 존재 확인 (2026-06-30).
- [x] 프론트 환경변수 원칙 문서화: `VITE_` 접두사는 **번들에 그대로 노출**됨 → Ion 토큰 같은 건 도메인 제한(Ion 측 allowed URLs)으로 보호, 진짜 비밀은 프론트에 두지 않는다.

### [13] 3-2. 백엔드 설정 하드닝 (P0~P1)
- [x] **프로파일 분리**: `application.yml`(공통) + `application-local.yml` / `application-prod.yml` (2026-06-30, PLAN 0-2와 합류, `gradlew build` 통과).
- [x] **`ddl-auto: validate`** (운영) — 운영 프로파일 한정 적용, local은 update 유지 (V2).
- [x] **`show-sql`/SQL trace 로깅은 local 프로파일 한정** (2026-06-30, 운영은 미출력) (V3).
- [x] 운영 로그 레벨 `INFO` 고정 (2026-06-30, prod root INFO). 민감 파라미터 마스킹 정책은 추후.
- [ ] 액추에이터 도입 시 `/actuator/**` 노출 최소화(health/info만) + 인증. — ⏭️ **현재 액추에이터 미도입** → S1 범위 외(도입 시점에 처리). 2026-07-01 확인.

### [14] 3-3. 인증·인가 (P1 — ✅ B 채택, 2026-06-27 / ✅ 골격 완료 2026-07-03, S3)
> 지금은 공개 조회뿐이라 당장 불필요할 수 있으나, "극강 보안" 목표상 **쓰기/관리 API가 생기는 순간**을 대비해 골격을 잡아둔다.
> **채택: B** — Spring Security 골격만 미리 넣는다(비용 적고 이후 확장 안전). 착수는 S3.
> (반려: A=보류는 쓰기 API 추가 시 무방비 / C=풀 인증(JWT·OAuth2)은 사용자 개념 없는 현 단계엔 과함)
> 인증 방식: **HTTP Basic + InMemory(.env 주입) + BCrypt** 채택(2026-07-03). 세션/CSRF 부담 없는 무상태 API 골격에 적합.
- [x] `SecurityFilterChain`: `permitAll`(조회 GET·swagger·health) + `authenticated`(그 외 POST/PUT/DELETE=관리·쓰기·앵커 트리거) 분리 (2026-07-03, `Config/SecurityConfig`). CSRF off·`SessionCreationPolicy.STATELESS`·HTTP Basic. `spring-boot-starter-security` 추가.
- [x] 관리 자격증명 `.env`로 외부화, 평문 금지(BCrypt) (2026-07-03). `app.admin.username`/`app.admin.password-hash`를 `application.yml`에서 주입, `InMemoryUserDetailsManager`로 관리 계정 1개. 해시 미설정 시 로그인만 불가·기동 정상(보호 API 없는 현 단계 개발 무지장). `.env.example`에 키·해시 생성법 명시.
> 검증(2026-07-03): `gradlew build` SUCCESSFUL + 기동 후 curl — 공개 GET `/api/health` **200**, swagger·api-docs **200**, 미인증 POST **401**(쓰기 차단 확인). 관리 계정 실제 로그인 검증은 보호 API가 생겨 `.env`에 해시를 넣는 시점에 함께 수행.

### [15] 3-4. 입력 검증·인젝션 방어 (P1)
> **S2 골격 완료 (2026-07-06)**: 실제 컨트롤러/리포지토리가 생기면 아래 골격을 바로 적용한다.
- [x] **Bean Validation 의존성 추가**: `spring-boot-starter-validation` (build.gradle). `MethodValidationPostProcessor` 등록 (`ValidationConfig`).
- [x] **글로벌 예외 핸들러** (`GlobalExceptionHandler`): validation 실패 → 400 + 필드별 오류 목록. 500은 내부 정보 미노출 (V9 연계).
- [x] **BBox 검증 DTO** (`BBoxParam`): `@DecimalMin/@DecimalMax`로 한반도 범위 강제. `isValid()`로 min>max 방어.
- [x] **공통 쿼리 파라미터 DTO** (`FacilityQueryParam`): `type`/`category` — `@Pattern(^[a-z0-9_\\-]{1,50}$)` SQLi 화이트리스트. `limit` — `@Min(1) @Max(5000)`, 기본값 1000.
- [x] **JSON 요청 크기 제한**: `server.tomcat.max-swallow-size: 2MB`, multipart 10MB (application.yml).
- [ ] **실제 컨트롤러 적용**: 컨트롤러에 `@Validated` + `@Valid BBoxParam` + `@Min/@Max @RequestParam limit` — Phase 0-3/2 착수 시.
- [ ] **네이티브 쿼리 바인딩 파라미터 검증**: Repository 구현 시 문자열 결합 쿼리 0건 확인 — Phase 0-3/2 착수 시.
- [ ] JSON 요청 크기 제한 — 쓰기 API 도입 시 endpoint별 재확인.

### [16] 3-5. CORS·보안 헤더·전송 (P2, 배포 시 P0)
- [x] CORS origin **프로파일별 환경변수화**(V4): local=5000(vite dev 실포트), prod=`${CORS_ALLOWED_ORIGINS}` 환경변수(미설정 시 기동 실패=fail-closed) (2026-07-02, S2). `CorsConfig`가 `@Value("${app.cors.allowed-origins}")`로 주입, 하드코딩 제거. `gradlew build` 통과.
- [x] 보안 헤더(V6) — **백엔드 JSON API 4종** (2026-07-08, S4): `SecurityConfig.headers()` DSL로 HSTS(1년·includeSubDomains)·`X-Content-Type-Options: nosniff`·`X-Frame-Options: DENY`·`Referrer-Policy: strict-origin-when-cross-origin` 명시. `gradlew build -x test` 통과. 기동 후 `curl -I /api/health`로 nosniff·DENY·Referrer-Policy **3종 출력 확인**. HSTS는 Spring이 HTTPS 요청에만 전송 → 평문 HTTP에선 미출력(정상), TLS 종단(아래 HTTPS 항목) 후 자동 출력.
- [ ] **CSP는 프론트엔드 영역**으로 분리 — CSP는 문서(HTML) 응답에만 실효가 있는데 Cesium이 도는 건 프론트 `index.html`(Vite/정적 호스트 서빙)이고 백엔드는 JSON만 반환. 프론트 index.html/정적 호스트에 CSP 적용.
  - ⚠️ Cesium은 WebGL·웹워커·blob URL 사용 → CSP 작성 시 `worker-src blob:` 등 예외 필요. 깨지기 쉬우므로 프론트 실행 화면 확인하며 점진 적용.
- [ ] **HTTPS/TLS**(V8): 배포 시 리버스 프록시(Nginx/Caddy)에서 종단, HTTP→HTTPS 리다이렉트.

### [17] 3-6. DB 보안 (P1)
- [x] **앱 전용 DB 계정** 분리 (2026-07-02, S2): `busan_app` 롤 신설(LOGIN), `digital_twin` 스키마 10객체(테이블 9+뷰 1)에 **SELECT만** 부여 + `public` USAGE(PostGIS 함수)·`ALTER DEFAULT PRIVILEGES`로 향후 테이블 자동 SELECT·`public` CREATE 회수. `.env`를 `busan_app`으로 교체. 검증: SELECT 210,346건·PostGIS 함수 성공 / INSERT·CREATE는 "접근 권한 없음" 거부 / `gradlew build` 통과(앱이 최소권한 계정으로 기동 성공). 쓰기/앵커 권한은 S3·Phase 4.5에서 한정 추가.
- [ ] 운영 DB는 외부 접속 차단(로컬 소켓/사설망), `pg_hba.conf` 점검.
- [ ] 정기 백업 + 복구 테스트(가용성).

### [18] 3-7. 블록체인 무결성 (P1 — 프로젝트 핵심)
> ⏭️ **S3에서 이연 (2026-07-03)**: 앵커링 코드·컨트랙트가 전무(`.sol` 0개, anchor/merkle 코드 0개). 지금 조치는 실효가 없으므로 아래 체크리스트는 **설계 원칙**으로 유지하고, 실제 보안 구현은 앵커 코드가 생기는 **Phase 4.5 착수 시 함께** 수행한다. (S2의 3-4 이연과 동일 논리)
> Phase 4.5 설계와 합류. 보안 관점 체크리스트.
- [ ] **머클 정규화 규칙의 결정성**: 같은 데이터 → 항상 같은 루트(직렬화·정렬·인코딩 고정). 비결정성은 무결성 자체를 무너뜨림.
- [ ] **재진입/접근제어**: `anchor()` 호출 권한 제한(onlyOwner류), 컨트랙트 표준 보안 점검.
- [ ] 개인키 관리: 앵커 트랜잭션 서명키는 **절대 깃·프론트에 두지 않음**, 시크릿으로만.
- [ ] 검증 엔드포인트는 **온체인 루트와 대조**해 변조 탐지 — 오프체인 DB만 믿지 않기.
- [ ] (선택) Slither 등 컨트랙트 정적분석.

### [19] 3-8. 의존성·공급망 (P2~P3)
- [x] **백엔드**: Dependabot(gradle, `/Back-End`) 주간 점검으로 gradle 의존성 CVE·구버전 PR화 (2026-07-13, S4, `.github/dependabot.yml`). **OWASP Dependency-Check는 미도입** — 최신판은 NVD API 키 필요 + CI 부하 큼. 문서 원칙("OWASP **또는** Gradle 점검 + Dependabot") 상 Dependabot(gradle)로 대체 충족. 실 CVE 정밀검사가 필요해지면 그때 도입.
- [x] **프론트**: Dependabot(npm, `/frontend`) 주간 점검 + CI `npm audit --audit-level=high`(현재 report-only) (2026-07-13, S4). 현황: audit 13건(critical 1·high 5)이나 대부분 **devDependencies**(vite/rollup/vite-plugin-cesium, 번들 미포함) → 즉시 `audit fix` 대신 **Dependabot PR 검토·머지에 위임**(빌드 안정성 유지). Dependabot이 백로그 정리 후 CI audit을 하드 게이트로 승격 예정.
- [x] lockfile 커밋 확인: `frontend/package-lock.json` 추적 중 ✅. gradle은 Boot BOM 위임(V11, 별도 lockfile 없음).
- [x] **플러그인/스냅샷 버전 핀 정밀 점검** (2026-07-15, V11 종결): `build.gradle`/`settings.gradle` 전수 확인 — 플러그인 명시 핀(Spring Boot `3.2.1`, dependency-management `1.1.4`), 부동 버전(`+`·`latest.release`) 0건, 스냅샷 **의존성** 0건(`0.0.1-SNAPSHOT`은 앱 자체 버전이라 공급망 위험 아님), 나머지 의존성은 Boot BOM 위임으로 재현가능. → 조치 불필요, 위험 없음 확인.

### [20] 3-9. CI/CD 보안 게이트 (P2)
- [x] GitHub Actions에 **시크릿 스캔(gitleaks)** + **의존성 스캔** 워크플로 (2026-07-13, S4, `.github/workflows/security.yml`). 3개 잡: ① gitleaks(전체 히스토리, 루트 `.gitleaksignore` 재사용 → 알려진 무효 건 제외·신규만 탐지) ② 백엔드 `gradlew build -x test`(DB 의존 `contextLoads` 테스트는 CI DB 부재로 제외, 로컬 전체 게이트 유지) ③ 프론트 `npm audit`. 검증: 로컬 `gradlew build -x test` **BUILD SUCCESSFUL**. (선택 CodeQL/SAST는 S5로 이연.)
- [x] Actions 워크플로 권한 최소화: `permissions: contents: read` 고정 (2026-07-13). 토큰은 러너 기본 `secrets.GITHUB_TOKEN`만 사용, 외부 시크릿 미주입.
- [ ] PR마다 `/security-review` 또는 SAST 통과를 머지 게이트로. — 브랜치 보호 규칙(원격) 설정 필요, S5에서 처리.

---

## 4. 단계별 실행 순서 (우선순위) — [항목 21] (S1~S5 묶음)

| 단계 | 묶음 | 항목 | 게이트 |
|---|---|---|---|
| **S1 (P0, 즉시)** ✅ 완료(2026-07-01) | 비밀·치명적 설정 | 3-1(토큰 재발급·시크릿 스캔), 3-2(ddl-auto·로깅) | 빌드 성공 + 비밀 스캔 클린 → **게이트 통과**(`gradlew build` BUILD SUCCESSFUL, `gitleaks` no leaks found). 액추에이터 항목은 미도입이라 도입 시 처리. |
| **S2 (P1)** ✅ 완료(2026-07-06) | 입력·DB·전송 | 3-6(DB 계정 분리) ✅, 3-5 일부(CORS 환경변수) ✅, 3-4(검증 골격) ✅ / 실제 컨트롤러 적용·네이티브 쿼리 검증은 Phase 0-3·2로 이연 | 게이트: `gradlew build -x test` BUILD SUCCESSFUL (2026-07-06). 검증 골격(BBoxParam, FacilityQueryParam, GlobalExceptionHandler, ValidationConfig) + JSON 크기 제한 적용. 실제 API 미존재로 통합테스트는 대상 API 생성 시 추가. |
| **S3 (P1)** 🔶 부분완료(2026-07-03) | 인증 골격·블록체인 | 3-3(인증 골격) ✅ / 3-7(앵커 보안) ⏭️ Phase 4.5로 이연(앵커 코드 미존재) | 게이트: `gradlew build` SUCCESSFUL + 기동 curl — 공개 GET 200·swagger 200·미인증 POST 401 확인 → **통과** |
| **S4 (P2)** 🔶 부분완료(2026-07-13) | 헤더·CI·의존성 | 3-5 헤더(백엔드 4종) ✅ / 3-8(Dependabot) ✅ / 3-9(gitleaks+의존성 CI, `permissions:read`) ✅ / 3-5 CSP·HTTPS ⏭️ 이연 | 게이트: 로컬 `gradlew build -x test` SUCCESSFUL + `.github/` 워크플로·Dependabot 추가. CSP=프론트 Cesium 미연동으로 검증화면 부재→프론트 지도 착수 시, HTTPS=배포(리버스 프록시) 시점, CodeQL·머지 게이트=S5. |
| **S5 (P3)** | 마무리 | 공급망 핀 ✅(2026-07-15, 3-8 완료) / 침투 점검·최종 리뷰·머지 게이트(원격)·CSP·HTTPS는 착수조건 도달 시 | PLAN Phase 7 보안 점검과 합류 |

> S1·S2는 Phase 0(재설계) 작업과 자연스럽게 합류 — 프로파일 분리·ddl-auto·CORS는 이미 PLAN 0-2에 있음.

---

## 5. 검증 방법 (사실대로 보고 원칙) — [항목 22]

- **비밀 스캔**: `gitleaks detect` 결과(0 leaks) 첨부.
- **설정 하드닝**: prod 프로파일로 기동 시 SQL 로그 미출력·`validate` 동작 확인.
- **입력 검증**: 비정상 파라미터(범위 밖 BBox, 거대 limit)에 400 응답하는 통합테스트.
- **인증**: 보호 엔드포인트 401, 공개 엔드포인트 200 테스트.
- **헤더**: 응답 헤더에 보안 헤더 존재 확인(curl/테스트).
- **블록체인**: 정상 검증 ✅ / 변조 레코드 ❌ / 이력 시계열 테스트(PLAN 4.5-2와 동일).
- **의존성**: 스캔 리포트의 High/Critical 0건.

---

## 6. 결정 사항 (2026-06-27 사용자 확정) — [항목 23]

1. **시크릿 히스토리 처리** (3-1): ✅ **A 채택** — Cesium Ion 토큰은 폐기·재발급으로 무효화하고 깃 히스토리는 재작성하지 않는다. (재작성은 협업 충돌·강제푸시 리스크 대비 실익 적음)
2. **인증 도입 시점** (3-3): ✅ **B 채택** — Spring Security 골격을 미리 넣는다(공개 엔드포인트 화이트리스트 + 나머지 차단, 관리용 1계정). 실제 코드 착수는 S3이며, 현 단계엔 공개 GET뿐이라 당장 동작 변화는 없음.
3. **PLAN.md 편입 방식**: ✅ **링크 + 교차참조 채택** — `plans/security.md`를 세부계획 목록에 추가하고 Phase 7 보안 항목에 교차참조 링크 연결 완료(2026-06-27).

> S1(P0)부터 "코드 제시 → 입력 → 검사" 방식으로 진행. 단 S1·S2는 Phase 0 재설계와 합류하므로, Phase 0 진행 순서와 맞물려 착수 시점을 조율한다.
