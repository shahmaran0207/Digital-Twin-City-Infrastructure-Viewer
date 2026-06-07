# 원천 데이터 출처 목록

> 2026-06-07 조사·작성. `data/` 폴더 원천 파일들의 출처 + 디지털 트윈 확장에 쓸 수 있는 실시간 API·추가 데이터셋 정리.
> Phase 1-R(데이터 재구축)과 시뮬레이션 기능([plans/simulation.md](../plans/simulation.md)) 설계의 기준 문서.

---

# A. 보유 데이터 출처 (재수집 완료분 포함)

## ① 교통안전시설물 8종 — 공공데이터포털 "부산광역시_교통시설물관리시스템" 시리즈

2026-06-07 원본 컬럼 보존 버전으로 재다운로드 완료. 원본 컬럼: 번호, 시군구명, 동명, 리명, 도로명, 교차로명, 경도, 위도 (교차로는 지번·구코드·동코드·리코드 추가 12컬럼).

| 파일 | 다운로드 페이지 | 재수집 |
|---|---|---|
| 부산광역시_교차로 정보.csv (2,149행) | https://www.data.go.kr/data/15084050/fileData.do | ✅ |
| 부산광역시_노면문자표시 정보_20220630.csv (16,673행) | https://www.data.go.kr/data/15084051/fileData.do | ✅ |
| 부산광역시_노면방향표시 정보_20220630.csv (21,868행) | https://www.data.go.kr/data/15084053/fileData.do | ✅ |
| 부산광역시_부착대 정보_20220630.csv (12,033행) | https://www.data.go.kr/data/15084054/fileData.do | ✅ |
| 부산광역시_안전지대 정보_20220630.csv (3,537행) | https://www.data.go.kr/data/15084055/fileData.do | ✅ |
| 부산광역시_안전표지 정보.csv (57,527행) | https://www.data.go.kr/data/15084056/fileData.do | ✅ |
| 부산광역시_차선정보_20220630.csv (59,306행) | https://www.data.go.kr/data/15084057/fileData.do | ✅ |
| 부산광역시_철주정보_20220630.csv (14,050행) | https://www.data.go.kr/data/15084058/fileData.do | ✅ |

## ② 단독 데이터셋

| 파일 | 다운로드 페이지 | 재수집 |
|---|---|---|
| 부산광역시_방범용CCTV 정보 (21,060행 — 구버전 12,168행 대비 증가, 장비종류·시설명칭 컬럼 추가) | https://www.data.go.kr/data/15082060/fileData.do | ✅ |
| 스마트 버스쉘터 설치 현황.csv (44행, 원본 10컬럼) | https://www.data.go.kr/data/15154539/fileData.do | ✅ |
| 부산광역시_15분 도시공원_20251119.csv (1,137행, 원본 9컬럼 — 공원종류·면적·상세주소 포함) | 부산 플랫폼 계열 (Big-데이터웨이브 추정) | ✅ |
| ITS CCTV (SHP zip) | 부산 교통정보서비스센터 https://its.busan.go.kr/ · API: https://www.data.go.kr/data/15034450/openapi.do | 기존 보유 |
| 어린이보호구역 내 불법주정차 CCTV설치현황_00.csv (41행) | **⚠️ 미재수집 — 보유본이 가공본(컬럼 축소)뿐. 원본 재확보 필요** | ❌ |

## ③ 미사용 파일

| 파일 | 출처 | 비고 |
|---|---|---|
| LSMD_CONT_ZB001_부산.zip | 국가공간정보포털/브이월드 연속지적 SHP | 기타경계(지적재조사지구)로 판명 → 미사용 |

---

# B. 실시간/준실시간 Open API 후보 (2026-06-07 조사)

> 전부 공공데이터포털(data.go.kr) 회원가입 + 활용신청으로 인증키 발급 (대부분 자동승인).

## 교통

| API | URL | 내용 / 활용 |
|---|---|---|
| 부산버스정보시스템(BIMS) | https://www.data.go.kr/data/15092750/openapi.do | 정류소·노선·**버스 도착예정/위치** — 지도 위 버스 실시간 표시 |
| 부산 링크소통정보 | https://www.data.go.kr/data/15120905/openapi.do | 링크별 **속도·교통량** (실시간 소통) — 도로 색상(정체) 표시, 교통 시뮬레이션 기준값 |
| 부산 연계소통정보 | https://www.data.go.kr/data/15121039/openapi.do | 수집원 포함 링크 소통정보 (JSON) |
| 부산 링크현황정보 | https://www.data.go.kr/data/15120899/openapi.do | 링크 ID·도로명 메타 — 소통정보와 조인용 |
| 부산 ITS CCTV 현황 | https://www.data.go.kr/data/15034450/openapi.do | CCTV 위치+**실시간 영상 URL** |
| 부산 도시철도 열차시각표 | https://www.data.go.kr/data/15000522/openapi.do | 역별 도착 시각표 (※ 실시간이 아닌 계획 시각표) |
| 부산 공영주차장 정보 | https://www.data.go.kr/data/15004683/openapi.do | 주차장 위치·구획수 (실시간 가능면수 포함 여부 신청 후 확인 필요) |
| 한국교통안전공단 주차정보 | https://www.data.go.kr/data/15099883/openapi.do | 전국 주차장 + 일부 실시간 주차정보 |

## 환경·기상

| API | URL | 내용 / 활용 |
|---|---|---|
| 에어코리아 대기오염정보 | https://www.data.go.kr/data/15073861/openapi.do | 측정소별 실시간 PM10/PM2.5/O3 — 대기질 히트맵 |
| 에어코리아 측정소정보 | https://www.data.go.kr/data/15073877/openapi.do | 측정소 위치(TM좌표) — 부산 측정소 매핑용 |
| 기상청 단기예보 조회 | https://www.data.go.kr/data/15084084/openapi.do | **초단기실황**(기온·강수량, 매시) + 예보, 5km 격자, 자동승인 — 강우 연동 침수 시뮬레이션 입력 |
| 환경부 전기차 충전기 상태 | https://www.data.go.kr/data/15076352/openapi.do | 충전소 위치+**실시간 충전기 상태(5분 갱신)** |

## 재난·안전

| API | URL | 내용 / 활용 |
|---|---|---|
| 행안부 긴급재난문자 | https://www.data.go.kr/data/15134001/openapi.do | 재난문자 발령 (지역코드 필터) — 재난 알림 패널 |
| 해양조사원 조석예보 | https://www.data.go.kr/data/15038991/openapi.do | 부산 연안 조위 예보 — 해안 침수 시뮬레이션 입력 |
| 바다누리 해양정보 Open API | https://www.khoa.go.kr/oceangrid/khoa/takepart/openapi/openApiKey.do | 실시간 조위·수온 등 (별도 키 발급) |
| TAAS 사고다발지역 | https://www.data.go.kr/data/15057467/openapi.do · http://taas.koroad.or.kr/api/selectApiIntroduce.do | 보행자/어린이/결빙 등 사고다발지역 11종 — 위기레벨 산식 입력 |

---

# C. 추가 정적 데이터셋 후보 (2026-06-07 조사)

## 3D·지형·경계 (디지털 트윈 기반)

| 데이터셋 | 출처 | 형식 / 활용 |
|---|---|---|
| GIS건물통합정보 | https://www.data.go.kr/data/15083092/fileData.do · 오픈마켓 http://data.nsdi.go.kr/dataset/12623 · 브이월드 https://www.vworld.kr/dtmk/dtmk_ntads_s002.do?svcCde=NA&dsId=5 | SHP (건물 폴리곤+층수+용도) — **건물 3D 압출(extrusion) 렌더링**, viewshed 차폐 |
| 수치표고모델(DEM) | 국토정보플랫폼 https://map.ngii.go.kr (5m/1m, 로그인+전용 전송SW 필요) · 90m: http://data.nsdi.go.kr/dataset/20001 | 래스터 — **침수 시뮬레이션 핵심**, 지형 분석 |
| 행정구역 시군구 경계 | https://www.data.go.kr/data/15125045/fileData.do (EPSG:5186) | SHP — 시군구 통계 시각화 (Phase 4 보류건 해결) |
| 행정동 경계 | https://github.com/vuski/admdongkor (EPSG:5179, 매년 갱신) | GeoJSON — 동 단위 통계 |
| 국가표준노드링크 | https://www.its.go.kr/nodelink/nodelinkRef · https://www.data.go.kr/data/15025526/fileData.do | SHP (전국 도로 노드·링크) — **교통 시뮬레이션(경로 탐색) 핵심**, 링크소통정보와 조인 |

## 교통 시설

| 데이터셋 | 출처 | 활용 |
|---|---|---|
| 부산 버스 정류소 정보(SHP) | https://www.data.go.kr/data/15084251/fileData.do | 정류소 레이어 (BIMS API와 조인) |
| 전국 버스정류장 위치정보 | https://www.data.go.kr/data/15067528/fileData.do | CSV 대안 |
| 부산 신호등 현황 | https://data.busan.go.kr/bdip/opendata/detail.do?publicdatapk=3079345 | 신호등 레이어 — 교차로와 연계 |
| 전국주차장정보표준데이터 | https://www.data.go.kr/data/15012896/standard.do | 주차장 레이어 (부산분 필터) |
| 전국무인교통단속카메라표준데이터 | https://www.data.go.kr/data/15028200/standard.do | 단속카메라 레이어 — 기존 어린이보호구역 CCTV의 상위 데이터 후보 |

## 안전·재난 (위기레벨·시뮬레이션 입력)

| 데이터셋 | 출처 | 활용 |
|---|---|---|
| 전국어린이보호구역표준데이터 | https://www.data.go.kr/data/15012891/standard.do | **보호구역 위치+지정시설** — 현재 근사 버퍼 방식 대체 가능 |
| 전국교통사고다발지역표준데이터 | https://www.data.go.kr/data/15029185/standard.do | 사고다발 폴리곤 — 위기레벨 입력 |
| 전국지진해일긴급대피장소표준데이터 | https://www.data.go.kr/data/15025449/standard.do | 대피장소 위치+수용인원+해발고도 — **대피 시뮬레이션** |
| 침수흔적도 | 생활안전지도 https://safemap.go.kr/opna/data/dataView.do?objtId=212 (WMS/API) · 부산 도시침수 재해정보지도 https://www.busan.go.kr/depart/disastermap | 과거 침수 이력 — 침수 시뮬레이션 검증/배경 |
| 부산시 침수위험 복합 데이터 | https://aihub.or.kr/aihubdata/data/view.do?dataSetSn=71793 | 수영강·온천천·동천 침수 수치모델 (연구용, 용량 큼) |
| 전국보안등정보표준데이터 | https://www.data.go.kr/data/15017320/standard.do | 야간 안전 분석 — CCTV 공백과 결합 |

## 인구·생활

| 데이터셋 | 출처 | 활용 |
|---|---|---|
| SGIS 격자 인구 (통계청) | https://sgis.kostat.go.kr/developer/ (API, 키 발급) | 100m~1km **격자 인구** — 대피 시뮬레이션·위기레벨 가중치 |
| 전국전기차충전소표준데이터 | https://www.data.go.kr/data/15013115/standard.do | 충전소 레이어 (실시간 API와 조인) |

---

# D. 수집 우선순위 제안

| 순위 | 항목 | 이유 |
|---|---|---|
| 1 | 어린이보호구역 CCTV 원본 재확보 (또는 표준데이터로 대체) | 1-R 마지막 미수집분 |
| 2 | 시군구 경계 SHP | Phase 4 보류건, 통계 시각화 즉시 필요 |
| 3 | GIS건물통합정보(부산) + DEM | 3D 건물·침수 시뮬레이션의 기반 — 용량 크므로 미리 확보 |
| 4 | 표준노드링크(부산 추출) | 교통 시뮬레이션 기반 |
| 5 | 링크소통정보 + BIMS + 기상청 API 키 발급 | 자동승인이라 비용 없음, 실시간 데모 효과 큼 |
| 6 | 지진해일 대피장소 + SGIS 격자인구 | 대피 시뮬레이션 채택 시 |
