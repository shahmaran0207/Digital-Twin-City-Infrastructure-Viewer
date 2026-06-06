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
$CsvPath      = Join-Path $MigrationDir '..\data\processed\facility_all.csv'

if (-not (Test-Path $CsvPath)) {
    Write-Error "가공 CSV가 없습니다: $CsvPath`n먼저 'py data/process_data.py' 를 실행하세요."
}

function Invoke-Psql {
    param([string[]]$PsqlArgs)
    & psql -h $PgHost -p $PgPort -U $PgUser -d $PgDb -v ON_ERROR_STOP=1 @PsqlArgs
    if ($LASTEXITCODE -ne 0) { Write-Error "psql 실패 (exit $LASTEXITCODE)" }
}

Write-Host '== V1: 스키마/테이블 생성 =='
Invoke-Psql @('-f', (Join-Path $MigrationDir 'V1__init_schema.sql'))

Write-Host '== V2: facility_type 시드 =='
Invoke-Psql @('-f', (Join-Path $MigrationDir 'V2__seed_facility_type.sql'))

Write-Host '== facility 적재 =='
Invoke-Psql @('-c', 'TRUNCATE digital_twin.facility RESTART IDENTITY')
$copyCmd = "\copy digital_twin.facility (facility_type, source_id, sigungu, name, lon, lat, props) FROM '$CsvPath' WITH (FORMAT csv, HEADER true, NULL '')"
Invoke-Psql @('-c', $copyCmd)

Write-Host '== 적재 결과 =='
Invoke-Psql @('-c', @'
SELECT t.code, t.name, t.name_ko, t.category, count(f.id) AS cnt
FROM digital_twin.facility_type t
LEFT JOIN digital_twin.facility f ON f.facility_type = t.code
GROUP BY t.code, t.name, t.name_ko, t.category
ORDER BY t.code;
'@)
