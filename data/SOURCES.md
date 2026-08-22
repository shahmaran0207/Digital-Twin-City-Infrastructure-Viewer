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
| ~~어린이보호구역 내 불법주정차 CCTV설치현황_00.csv (41행)~~ → **전국어린이보호구역표준데이터.csv로 대체(2026-06-15)** — 부산 809건, 보호구역 자체 위치 (D절 우선순위1 해결) | https://www.data.go.kr/data/15012891/standard.do | ✅ |

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

---

# E. 범죄예방·자전거 도난방지 확장 (2026-08-20 결정 — Phase 1-C / 4-B)

> 배경: 자전거 도난방지를 시작으로 **범죄예방 레이어 + 필터 기능 + 범죄예측 분석**으로 범위 확장.
> **핵심 제약**: 범죄 발생 **좌표**는 공개되지 않는다(경찰청 통계는 시군구 단위). 따라서
> ① 격자 위험도는 환경 요인 기반 **RTM(Risk Terrain Modeling)** 으로 산출하고,
> ② 그 **가중치**는 시군구×연도 패널 회귀(포아송/음이항)로 정당화한다. → Phase 4-B

## E-1. 자전거 (도난방지 중심)

| 데이터셋 | 출처 | 활용 |
|---|---|---|
| 행정안전부_자전거보관소정보 | https://www.data.go.kr/data/15075533/fileData.do | **분석 중심 좌표.** 보관대수·설치형태(개방형/폐쇄형)·설치연도 → 도난 취약도 |
| 전국자전거대여소표준데이터 | https://www.data.go.kr/data/15017319/standard.do | 공영자전거 대여소 (부산 구·군별 CSV도 존재) |
| 부산광역시_자전거 도로정보 서비스 | https://www.data.go.kr/data/15058484/openapi.do | 자전거도로 노선 — 링크 데이터(H)와 대조 |
| 부산 자전거도로/보관대 현황 | https://www.busan.go.kr/depart/ahbicycle01 · https://www.busan.go.kr/depart/ahbrack01 | 시 자체 현황 (원천 보완용) |

## E-2. 방범·치안 시설 (위험 저감 요인)

| 데이터셋 | 출처 | 활용 |
|---|---|---|
| 전국안전비상벨위치표준데이터 | https://www.data.go.kr/data/15028206/standard.do | 범죄예방 비상벨 — 설치목적·장소유형 포함 |
| 전국안심택배함표준데이터 | https://www.data.go.kr/data/15034534/standard.do | 범죄예방용 무인택배함 |
| 전국보안등정보표준데이터 | https://www.data.go.kr/data/15017320/standard.do | **야간 조도** — 도난·범죄 위험의 핵심 변수 (C절 중복 게재) |
| 지구대·파출소 위치 | 경찰청 공공데이터 https://www.police.go.kr/www/open/publice/publice01.jsp | 대응 거리(접근성) 변수 |
| 여성안심귀갓길 | 서울은 개방(https://data.seoul.go.kr/dataList/OA-21697/S/1/datasetView.do) — **부산은 구·군별 개방 여부 확인 필요** | 미개방 시 제외 |
| 기보유 | 방범CCTV 21,053 / 어린이보호구역 809 | 커버리지 공백 계산 |

## E-3. 범죄 유발 환경 (회귀의 핵심 설명변수)

| 데이터셋 | 출처 | 활용 |
|---|---|---|
| **LOCALDATA 지방행정 인허가데이터** | https://www.localdata.go.kr/ | **가장 값어치 있는 항목.** 유흥주점·단란주점·숙박업·PC방·편의점 등 업종별 점포 좌표 전량 → 야간 상권 밀도 |
| 전국주차장정보표준데이터 | https://www.data.go.kr/data/15012896/standard.do | 주차장 위치/규모 |
| 전국보행자우선도로표준데이터 | https://www.data.go.kr/data/15028202/standard.do | 보행 안전 축 (링크 데이터 보완) |

## E-4. 인구·유동 (정규화 + 연령 구성 변수)

| 데이터셋 | 출처 | 활용 |
|---|---|---|
| SGIS 격자인구(성·연령) | https://sgis.kostat.go.kr/developer/ — `.env`에 `SGIS_ID`/`SGIS_SECRET_KEY` 보유 | 인구 정규화 + **20대 남성 비율** 등 연령 구성 변수 |
| 부산교통공사 역별 승하차 | https://work.humetro.busan.kr/homepage/default/page/subLocation.do?menu_no=1001040401 | 유동인구 대리지표 |
| 버스정류장 전체 | 공공데이터포털/BIMS | 유동 접근성 (기보유 smart_shelter 44개는 일부) |

## E-5. 종속변수(y) 후보

| 데이터셋 | 출처 | 비고 |
|---|---|---|
| 경찰청_범죄 발생 지역별 통계 | https://www.data.go.kr/data/3074462/fileData.do | **시군구 단위** — 격자 단위 지도학습 불가의 원인 |
| 경찰청_범죄 발생 장소별 통계 | https://www.data.go.kr/data/3074463/fileData.do | 장소 유형별 분포 — 가중치 설계 근거 |
| 경찰청 통계자료실 | https://www.police.go.kr/www/open/publice/publice0207.jsp | 다년치 확보(패널 구성용) |

> ⚠️ "범죄유형별 주 가해 연령대" 통계는 **전국 단위 상수**라 지역 변수로 쓸 수 없다.
> 지역의 **연령 구성비**(E-4)를 설명변수로 넣는 것이 통계적으로 올바른 사용법이다.
> 해석 시 **생태학적 오류(ecological fallacy)** 를 반드시 명시할 것 — 지역 상관 ≠ 개인 인과.

## E-6. 네트워크 링크 (자전거/보행/PM — A안: 모드 플래그 통합)

| 데이터셋 | 출처 | 활용 |
|---|---|---|
| **OpenStreetMap** (`highway=cycleway/footway/path/pedestrian`) | https://download.geofabrik.de/asia/south-korea.html | 자전거·보행 네트워크의 **실질적 유일 대안**. `osm2pgrouting` 적용 가능. 라이선스 **ODbL — 출처 표시 + 동일조건 배포 필수** |
| 기보유 표준노드링크 | https://www.its.go.kr/nodelink/nodelinkRef | 차량 전용(보유 node 61,121 / link 86,896) |

**A안 구조**: `road_link`에 모드 허용 플래그(`car_allowed`·`bike_allowed`·`foot_allowed`)를 추가하고 OSM 링크를 같은 테이블에 적재 → 네트워크 1개로 3모드 pgRouting.
**PM(킥보드)**: 전용 네트워크 데이터가 존재하지 않음 → **자전거도로 + 제한속도 이하 차도**로 근사(2026-08-20 결정). 제한속도는 표준노드링크 링크 속성 사용.

## E-7. 수집 시 주의

- 표준데이터는 대부분 **전국본** → 부산 추출 필요 (어린이보호구역 809건 때와 동일 패턴)
- 좌표 컬럼명·순서가 데이터셋마다 다름 → 기존 `process_data.py`의 **값 범위 기반 lon/lat 자동판별** 재사용
- 부가 컬럼은 전부 `props`(jsonb)에 한글 키로 보존 — 스키마 변경 없음
- 신규 유형은 `facility_type`에 행 추가만 하면 API·필터 UI에 자동 반영 (코드 변경 0줄)
