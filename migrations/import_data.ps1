# =====================================================================
# 마이그레이션 실행 + 가공 데이터 적재 스크립트
#   1) V1, V2 마이그레이션 실행
#   2) data/processed/facility_all.csv -> digital_twin.facility 적재
#      (재실행 시 facility를 비우고 다시 적재 - 멱등)
#
# 사전 조건: data/process_data.py 실행으로 facility_all.csv 생성되어 있어야 함
# 사용법:   .\migrations\import_data.ps1
# =====================================================================

$ErrorActionPreference = 'Stop'

# DB 접속 정보: 프로젝트 루트 .env에서 로드 (없으면 기본값)
$DotEnv = @{}
$DotEnvPath = Join-Path $PSScriptRoot '..\.env'
if (Test-Path $DotEnvPath) {
    Get-Content $DotEnvPath | ForEach-Object {
        if ($_ -match '^\s*([^#][^=]*)=(.*)$') {
            $DotEnv[$Matches[1].Trim()] = $Matches[2].Trim()
        }
    }
}
function Get-EnvOrDefault { param($Key, $Default)
    if ($DotEnv.ContainsKey($Key) -and $DotEnv[$Key]) { $DotEnv[$Key] } else { $Default }
}

$PgHost = Get-EnvOrDefault 'DB_HOST' 'localhost'
$PgPort = Get-EnvOrDefault 'DB_PORT' '5432'
$PgUser = Get-EnvOrDefault 'DB_USER' 'postgres'
$PgDb   = Get-EnvOrDefault 'DB_NAME' 'postgres'
$env:PGPASSWORD        = Get-EnvOrDefault 'DB_PASSWORD' ''
$env:PGCLIENTENCODING  = 'UTF8'

if (-not $env:PGPASSWORD) {
    Write-Error "DB_PASSWORD가 없습니다. 프로젝트 루트에 .env 파일을 만드세요 (.env.example 참고)."
}

$MigrationDir = $PSScriptRoot
$ProcessedDir = Join-Path $MigrationDir '..\data\processed'
$CsvPath      = Join-Path $ProcessedDir 'facility_all.csv'

if (-not (Test-Path $CsvPath)) {
    Write-Error "가공 CSV가 없습니다: $CsvPath`n먼저 'py data/process_data.py' 를 실행하세요."
}

# psql 실행파일 위치: PATH 우선, 없으면 PostgreSQL 기본 설치 경로에서 탐색
$Psql = (Get-Command psql -ErrorAction SilentlyContinue).Source
if (-not $Psql) {
    $cand = Get-ChildItem 'C:\Program Files\PostgreSQL\*\bin\psql.exe' -ErrorAction SilentlyContinue |
            Sort-Object FullName -Descending | Select-Object -First 1
    if ($cand) { $Psql = $cand.FullName }
}
if (-not $Psql) { Write-Error 'psql 실행파일을 찾을 수 없습니다 (PATH 또는 C:\Program Files\PostgreSQL\*\bin).' }

function Invoke-Psql {
    param([string[]]$PsqlArgs)
    & $Psql -h $PgHost -p $PgPort -U $PgUser -d $PgDb -v ON_ERROR_STOP=1 @PsqlArgs
    if ($LASTEXITCODE -ne 0) { Write-Error "psql 실패 (exit $LASTEXITCODE)" }
}

# EWKT CSV 를 geometry 컬럼에 직접 \copy 하는 공통 적재 함수
#   (PostGIS geometry 입력 함수가 'SRID=4326;...' EWKT 를 파싱)
function Import-Csv-Table {
    param([string]$Table, [string]$Columns, [string]$FileName)
    $path = Join-Path $ProcessedDir $FileName
    if (-not (Test-Path $path)) {
        Write-Error "가공 CSV가 없습니다: $path`n먼저 'py data/process_sim.py' 를 실행하세요."
    }
    Invoke-Psql @('-c', "TRUNCATE digital_twin.$Table RESTART IDENTITY CASCADE")
    $copy = "\copy digital_twin.$Table ($Columns) FROM '$path' WITH (FORMAT csv, HEADER true, NULL '')"
    Invoke-Psql @('-c', $copy)
}

Write-Host '== V1: 스키마/테이블 생성 =='
Invoke-Psql @('-f', (Join-Path $MigrationDir 'V1__init_schema.sql'))

Write-Host '== V2: facility_type 시드 =='
Invoke-Psql @('-f', (Join-Path $MigrationDir 'V2__seed_facility_type.sql'))

# V3~V7: 시뮬레이션/경계 테이블 DDL (건물·노드링크·대피장소·격자인구·읍면동·DEM)
#   테이블 적재는 가공 재작업(process_data.py) 완료 후 별도 단계에서 수행
Write-Host '== V3~V7: 시뮬레이션/경계 테이블 DDL =='
foreach ($v in @('V3__building.sql','V4__road_network.sql','V5__shelter_population.sql','V6__admin_emd.sql','V7__dem.sql')) {
    Write-Host "   - $v"
    Invoke-Psql @('-f', (Join-Path $MigrationDir $v))
}

Write-Host '== facility 적재 =='
Invoke-Psql @('-c', 'TRUNCATE digital_twin.facility RESTART IDENTITY')
$copyCmd = "\copy digital_twin.facility (facility_type, source_id, sigungu, name, lon, lat, props) FROM '$CsvPath' WITH (FORMAT csv, HEADER true, NULL '')"
Invoke-Psql @('-c', $copyCmd)

Write-Host '== facility 적재 결과 =='
Invoke-Psql @('-c', @'
SELECT t.code, t.name, t.name_ko, t.category, count(f.id) AS cnt
FROM digital_twin.facility_type t
LEFT JOIN digital_twin.facility f ON f.facility_type = t.code
GROUP BY t.code, t.name, t.name_ko, t.category
ORDER BY t.code;
'@)

# ---------------------------------------------------------------------------
# 시뮬레이션/경계 테이블 적재 (EWKT CSV → geometry 컬럼 직접 \copy)
#   사전 조건: py data/process_sim.py 실행으로 building/road_node/road_link/admin_emd.csv 생성
# ---------------------------------------------------------------------------
Write-Host '== building 적재 =='
Import-Csv-Table 'building' 'source_id, sigungu, name, addr, main_use, struct, floors_above, floors_below, height_m, height_est, total_area, props, geom' 'building.csv'
# 원본 shapefile 의 self-intersection 등 무효 폴리곤을 위상 보정 (폴리곤만 추출 후 MultiPolygon 유지)
Invoke-Psql @('-c', "UPDATE digital_twin.building SET geom = ST_Multi(ST_CollectionExtract(ST_MakeValid(geom), 3)) WHERE NOT ST_IsValid(geom)")

Write-Host '== road_node / road_link 적재 =='
Import-Csv-Table 'road_node' 'node_id, node_type, node_name, geom' 'road_node.csv'
Import-Csv-Table 'road_link' 'link_id, f_node, t_node, cost, reverse_cost, lanes, road_rank, road_type, max_spd, length_m, road_name, props, geom' 'road_link.csv'

Write-Host '   - pgRouting source/target 부여 (f_node/t_node → road_node.id)'
Invoke-Psql @('-c', @'
UPDATE digital_twin.road_link l SET source = n.id
  FROM digital_twin.road_node n WHERE l.f_node = n.node_id;
UPDATE digital_twin.road_link l SET target = n.id
  FROM digital_twin.road_node n WHERE l.t_node = n.node_id;
'@)

Write-Host '== admin_emd 적재 =='
Import-Csv-Table 'admin_emd' 'emd_cd, emd_ko_nm, sigungu, geom' 'admin_emd.csv'
Invoke-Psql @('-c', "UPDATE digital_twin.admin_emd SET geom = ST_Multi(ST_CollectionExtract(ST_MakeValid(geom), 3)) WHERE NOT ST_IsValid(geom)")

Write-Host '== 시뮬레이션/경계 테이블 검증 (건수 / SRID / 유효성) =='
Invoke-Psql @('-c', @'
SELECT 'building'  AS tbl, count(*) AS cnt,
       count(*) FILTER (WHERE NOT ST_IsValid(geom)) AS invalid,
       count(DISTINCT ST_SRID(geom)) AS srids, min(ST_SRID(geom)) AS srid
FROM digital_twin.building
UNION ALL
SELECT 'road_node', count(*), 0, count(DISTINCT ST_SRID(geom)), min(ST_SRID(geom))
FROM digital_twin.road_node
UNION ALL
SELECT 'road_link', count(*),
       count(*) FILTER (WHERE source IS NULL OR target IS NULL),
       count(DISTINCT ST_SRID(geom)), min(ST_SRID(geom))
FROM digital_twin.road_link
UNION ALL
SELECT 'admin_emd', count(*),
       count(*) FILTER (WHERE NOT ST_IsValid(geom)),
       count(DISTINCT ST_SRID(geom)), min(ST_SRID(geom))
FROM digital_twin.admin_emd
ORDER BY tbl;
'@)
