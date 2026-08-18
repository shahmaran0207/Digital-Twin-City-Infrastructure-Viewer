# PostGIS / 공간 쿼리 문법 정리

> 이 프로젝트에서 등장한 PostGIS·공간 SQL 특수 문법을 그때그때 기록한다.
> 일반 SQL에는 없는 문법이라 처음 보면 낯설 수 있어서 이유·동작 방식을 함께 남긴다.

---

## 1. `&&` — geometry 겹침(bounding box overlap) 연산자

```sql
WHERE f.geom && ST_MakeEnvelope(:minLng, :minLat, :maxLng, :maxLat, 4326)
```

### 뭐 하는 건가
두 geometry의 **bounding box(최소 외접 사각형)가 겹치는지** 확인한다.
`true`면 인덱스 후보로 통과, 이후 정밀 비교가 따라올 수 있다.

### 왜 `ST_Intersects` 대신 `&&`를 쓰나
- `&&`는 GIST 인덱스를 **직접** 활용 → 인덱스 스캔으로 후보만 추려냄
- `ST_Intersects`는 정밀 계산이라 느림. 화면 영역 조회처럼 대량 포인트를 걸러야 할 때는 `&&`가 훨씬 빠름
- 포인트 데이터(시설물)는 bounding box = 점 자체이므로 `&&`와 `ST_Intersects` 결과가 동일 → `&&`만으로 충분

### 관련 인덱스 (V1 DDL)
```sql
CREATE INDEX idx_facility_geom ON digital_twin.facility USING GIST (geom);
```
`&&` 연산자가 이 GIST 인덱스를 탄다. 인덱스 없으면 풀스캔.

---

## 2. `ST_MakeEnvelope(minX, minY, maxX, maxY, srid)` — BBox 폴리곤 생성

```sql
ST_MakeEnvelope(:minLng, :minLat, :maxLng, :maxLat, 4326)
```

### 뭐 하는 건가
네 좌표(경도 min/max, 위도 min/max)로 **직사각형 폴리곤**을 만든다.
화면에 보이는 영역을 폴리곤으로 표현해서 `&&`로 시설물을 필터링할 때 쓴다.

### 파라미터 순서
`(minX, minY, maxX, maxY)` = `(minLng, minLat, maxLng, maxLat)`
- X = 경도(Longitude), Y = 위도(Latitude) — **경도가 먼저**

### SRID 4326
WGS84 좌표계 코드. 우리 DB의 `geom` 컬럼과 SRID가 같아야 비교가 성립한다.
(`facility.geom`은 V1 DDL에서 SRID=4326으로 생성)

---

## 3. `GENERATED` 컬럼 — lon/lat → geom 자동 생성

```sql
-- V1 DDL 발췌
geom geometry(Point, 4326) GENERATED ALWAYS AS (ST_SetSRID(ST_MakePoint(lon, lat), 4326)) STORED
```

### 뭐 하는 건가
`lon`, `lat` 컬럼에 값을 넣으면 DB가 자동으로 `geom` 포인트를 계산해서 저장한다.
앱에서 `geom`을 직접 다룰 필요 없이 `lon`/`lat`만 관리하면 된다.

### JPA 매핑에서 빠진 이유
GENERATED 컬럼은 앱에서 쓰기가 불가능하고, 읽기만 필요한데 JPA로 매핑하면
geometry 타입 의존성이 생긴다. 그래서 `FacilityEntity`에서는 매핑을 제외하고,
공간 쿼리가 필요한 경우에만 **네이티브 쿼리**에서 `f.geom`을 직접 참조한다.

---