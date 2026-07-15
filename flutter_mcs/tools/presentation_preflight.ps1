[CmdletBinding()]
param(
    [int]$TimeoutSeconds = 90
)

$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$composeFile = Join-Path (Split-Path -Parent $projectRoot) 'mcs\docker-compose-kafka.yml'

if (-not (Test-Path -LiteralPath $composeFile)) {
    throw "Kafka Compose file not found: $composeFile"
}

Write-Host 'Checking Docker...'
docker info --format '{{.ServerVersion}}' | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw 'Docker Desktop is not running. Start Docker Desktop and run this script again.'
}

Write-Host 'Starting Kafka services...'
docker compose -f $composeFile up -d
if ($LASTEXITCODE -ne 0) {
    throw 'Docker Compose could not start the Kafka services.'
}

Write-Host 'Waiting for Kafka to accept broker requests...'
$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
$kafkaReady = $false

do {
    docker exec mcs-kafka kafka-topics --bootstrap-server localhost:9092 --list 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        $kafkaReady = $true
        break
    }
    Start-Sleep -Seconds 2
} while ((Get-Date) -lt $deadline)

if (-not $kafkaReady) {
    docker compose -f $composeFile ps
    throw "Kafka was not ready within $TimeoutSeconds seconds."
}

$topics = docker exec mcs-kafka kafka-topics --bootstrap-server localhost:9092 --list
if ($topics -notcontains 'transaction-completed') {
    Write-Host 'Creating transaction-completed topic...'
    docker exec mcs-kafka kafka-topics `
        --bootstrap-server localhost:9092 `
        --create `
        --if-not-exists `
        --topic transaction-completed `
        --partitions 1 `
        --replication-factor 1 | Out-Null
}

$backendAvailable = Test-NetConnection localhost -Port 8080 -InformationLevel Quiet -WarningAction SilentlyContinue

Write-Host ''
Write-Host 'Presentation dependencies are ready.' -ForegroundColor Green
Write-Host 'Kafka:    localhost:9092 (ready)'
Write-Host 'Kafka UI: http://localhost:8090'
if ($backendAvailable) {
    Write-Host 'Backend: http://localhost:8080 (reachable)'
} else {
    Write-Warning 'Backend is not reachable on port 8080. Start it before opening the Flutter app.'
}
