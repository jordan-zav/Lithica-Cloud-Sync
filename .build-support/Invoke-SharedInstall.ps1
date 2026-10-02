param([Parameter(Mandatory=$true)][scriptblock]$Action)
$ErrorActionPreference = 'Stop'
$root = if ($env:DEV_RESOURCES_ROOT) { $env:DEV_RESOURCES_ROOT } else { 'D:\DevResources' }
$locks = Join-Path $root 'Locks'
New-Item -ItemType Directory -Force -Path $locks | Out-Null
$lease = $null
try {
    while (-not $lease) {
        try { $lease = [IO.File]::Open((Join-Path $locks 'sdk-install.lock'), 'OpenOrCreate', 'ReadWrite', 'None') }
        catch [IO.IOException] { Start-Sleep -Milliseconds 300 }
    }
    & $Action
} finally {
    if ($lease) { $lease.Dispose() }
}
