param([string]$Profile)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$source = Join-Path $projectRoot 'lithica_drive_sync'
$profilesRoot = Join-Path $env:APPDATA 'QGIS\QGIS3\profiles'

New-Item -ItemType Directory -Force -Path $profilesRoot | Out-Null
$profiles = @(Get-ChildItem -LiteralPath $profilesRoot -Directory -ErrorAction SilentlyContinue)
if ([string]::IsNullOrWhiteSpace($Profile)) {
    if ($profiles.Count -eq 0) {
        $Profile = 'default'
    } elseif ($profiles.Count -eq 1) {
        $Profile = $profiles[0].Name
    } else {
        for ($index = 0; $index -lt $profiles.Count; $index++) {
            Write-Host "[$($index + 1)] $($profiles[$index].Name)"
        }
        $selection = Read-Host 'Selecciona el perfil de QGIS'
        if ($selection -notmatch '^\d+$' -or [int]$selection -lt 1 -or [int]$selection -gt $profiles.Count) {
            throw 'Seleccion de perfil invalida.'
        }
        $Profile = $profiles[[int]$selection - 1].Name
    }
}

$pluginRoot = Join-Path $profilesRoot "$Profile\python\plugins\lithica_drive_sync"
New-Item -ItemType Directory -Force -Path $pluginRoot | Out-Null
Copy-Item -Path (Join-Path $source '*') -Destination $pluginRoot -Recurse -Force

$qgis = if ($env:QGIS_BIN -and (Test-Path -LiteralPath $env:QGIS_BIN)) {
    $env:QGIS_BIN
} else {
    $command = Get-Command qgis-bin.exe -ErrorAction SilentlyContinue
    if ($command) { $command.Source }
}
if (-not $qgis) {
    $qgis = Get-ChildItem -Path (Join-Path $env:ProgramFiles 'QGIS *\bin\qgis-bin.exe') -File -ErrorAction SilentlyContinue |
        Sort-Object FullName -Descending |
        Select-Object -First 1 -ExpandProperty FullName
}
if (-not $qgis) { throw 'No se encontro QGIS. Configure QGIS_BIN o agregue QGIS al PATH.' }

Write-Host "Plugin instalado en: $pluginRoot"
Start-Process -FilePath $qgis
