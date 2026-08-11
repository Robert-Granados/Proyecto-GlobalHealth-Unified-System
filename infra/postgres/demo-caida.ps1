$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()

Set-Location (Join-Path $PSScriptRoot '..\..')

function Restore-Master {
    docker compose start postgres-master | Out-Null
}

Write-Host 'GLOBALHEALTH - CHAOS DEMO DESDE EL BACKEND' -ForegroundColor Cyan
Write-Host 'writePool -> DB_WRITE_URL -> postgres-master:5432'
Write-Host 'readPool  -> DB_READ_URL  -> postgres-replica:5432'
Write-Host 'No existe fallback entre pools.'

try {
    Write-Host "`n[1/5] Topología verificada por la aplicación:" -ForegroundColor Green
    Invoke-RestMethod 'http://localhost:8080/health' |
        ConvertTo-Json -Depth 8

    Write-Host "`n[2/5] Dashboard leído mediante readPool:" -ForegroundColor Green
    Invoke-RestMethod 'http://localhost:8080/api/dashboard/signos-vitales' |
        ConvertTo-Json -Depth 5

    Write-Host "`n[3/5] Deteniendo exclusivamente el master..." -ForegroundColor Red
    docker compose stop postgres-master
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo detener postgres-master' }

    Write-Host "`n[4/5] La escritura debe fallar con pool WRITE_MASTER:" -ForegroundColor Red
    $writeFailed = $false
    try {
        $body = @{ pacienteId = 9999; frecuenciaCardiaca = 82 } |
            ConvertTo-Json
        Invoke-RestMethod `
            -Method Post `
            -Uri 'http://localhost:8080/api/signos-vitales' `
            -ContentType 'application/json' `
            -Body $body | Out-Null
    }
    catch {
        $writeFailed = $true
        Write-Host "OK esperado: $($_.Exception.Message)" -ForegroundColor Green
    }
    if (-not $writeFailed) {
        throw 'El endpoint escribió aunque el master estaba detenido'
    }

    Write-Host "`n[5/5] La lectura sigue disponible desde readPool:" -ForegroundColor Green
    $readHealth = Invoke-RestMethod 'http://localhost:8080/health/read'
    $dashboard = Invoke-RestMethod 'http://localhost:8080/api/dashboard/signos-vitales'
    $readHealth | ConvertTo-Json -Depth 6
    $dashboard | ConvertTo-Json -Depth 5

    if ($readHealth.reader.inRecovery -ne $true -or
        $dashboard.pool -ne 'READ_REPLICA') {
        throw 'La lectura no provino de la réplica'
    }

    Write-Host "`nRESULTADO: escritura caída y dashboard disponible." -ForegroundColor Green
}
finally {
    Write-Host 'Restaurando master...'
    Restore-Master
}
