$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()

Set-Location (Join-Path $PSScriptRoot '..\..')

Write-Host '=== 1/4 Estado de los servicios ==='
docker compose ps postgres-master postgres-replica api
if ($LASTEXITCODE -ne 0) { throw 'docker compose ps falló' }

Write-Host '=== 2/4 El backend comprueba dos roles físicos ==='
$health = Invoke-RestMethod -Uri 'http://localhost:8080/health'
$health | ConvertTo-Json -Depth 8

if (-not $health.physicallySeparated) {
    throw 'El backend no confirmó separación física'
}
if ($health.writer.inRecovery -ne $false) {
    throw 'writePool no apunta al master'
}
if ($health.reader.inRecovery -ne $true) {
    throw 'readPool no apunta a la réplica'
}
if ($health.writer.serverAddress -eq $health.reader.serverAddress) {
    throw 'Los dos pools resolvieron la misma dirección'
}

Write-Host '=== 3/4 Escritura mediante writePool ==='
$body = @{ pacienteId = 7777; frecuenciaCardiaca = 79 } |
    ConvertTo-Json
$write = Invoke-RestMethod `
    -Method Post `
    -Uri 'http://localhost:8080/api/signos-vitales' `
    -ContentType 'application/json' `
    -Body $body
$write | ConvertTo-Json -Depth 5

if ($write.pool -ne 'WRITE_MASTER') {
    throw 'El endpoint de escritura no declaró WRITE_MASTER'
}

Write-Host '=== 4/4 Lectura replicada mediante readPool ==='
$found = $false
for ($attempt = 1; $attempt -le 20; $attempt++) {
    $dashboard = Invoke-RestMethod `
        -Uri 'http://localhost:8080/api/dashboard/signos-vitales'
    $found = @($dashboard.rows | Where-Object {
        [long]$_.paciente_id -eq 7777
    }).Count -gt 0
    if ($dashboard.pool -eq 'READ_REPLICA' -and $found) { break }
    Start-Sleep -Seconds 1
}

if (-not $found) {
    throw 'readPool no recibió la fila escrita en el master'
}

Write-Host 'OK: writePool escribió y readPool leyó la fila replicada.' -ForegroundColor Green
