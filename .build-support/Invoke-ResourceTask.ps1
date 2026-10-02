param(
    [Parameter(Mandatory = $true)][string]$Product,
    [string]$BatchPath,
    [string]$ScriptPath,
    [System.Collections.IDictionary]$ScriptParameters = @{},
    [object[]]$ExtraArguments = @(),
    [switch]$SharedSetup
)

$ErrorActionPreference = 'Stop'
$root = if ($env:DEV_RESOURCES_ROOT) { $env:DEV_RESOURCES_ROOT } else { 'D:\DevResources' }
$root = [IO.Path]::GetFullPath($root).TrimEnd('\')
if ($Product -notmatch '^[A-Za-z0-9_-]+$') { throw 'Invalid product identifier.' }
$lockRoot = Join-Path $root 'Locks'
New-Item -ItemType Directory -Force -Path $lockRoot | Out-Null

function Open-TaskLock([string]$Name) {
    $path = Join-Path $lockRoot ($Name + '.lock')
    $announced = $false
    while ($true) {
        try { return [IO.File]::Open($path, 'OpenOrCreate', 'ReadWrite', 'None') }
        catch [IO.IOException] {
            if (-not $announced) {
                Write-Host "Esperando a que termine la otra tarea de $Name..."
                $announced = $true
            }
            Start-Sleep -Milliseconds 300
        }
    }
}

# Product locks protect staging, generated files, signing injection and output.
# Independent products use separate locks. Nested commands inherit the lease.
$lease = Open-TaskLock $Product
$setupLease = $null
$buildLease = $null
$saved = @{}
$names = @('DEV_RESOURCES_ROOT','DEV_RESOURCE_PROJECT','DEV_RESOURCE_SESSION_TEMP',
    'LITHICA_BUILDS_ROOT','PETROPY_BUILD_ROOT','TEMP','TMP','LITHICA_FLUTTER_GRADLE_PLUGIN','DEV_RESOURCE_BATCH_PATH',
    'DEV_BUILD_JOBS','CMAKE_BUILD_PARALLEL_LEVEL','PUB_CACHE','GRADLE_USER_HOME',
    'PIP_CACHE_DIR','NUITKA_CACHE_DIR','npm_config_cache','UV_CACHE_DIR','DART_DATA_HOME')
foreach ($name in $names) { $saved[$name] = [Environment]::GetEnvironmentVariable($name, 'Process') }
$runId = [guid]::NewGuid().ToString('N')
$session = Join-Path $root "Sessions\$Product\$runId"
try {
    $entryName = [IO.Path]::GetFileName(($BatchPath + $ScriptPath))
    if ($entryName -match '^(build|compilar|empaquetar|crear_instalador)') {
        $limit = 2
        if ($env:DEV_MAX_PARALLEL_BUILDS) {
            $limit = [int]$env:DEV_MAX_PARALLEL_BUILDS
            if ($limit -lt 1 -or $limit -gt 16) { throw 'DEV_MAX_PARALLEL_BUILDS must be between 1 and 16.' }
        }
        $announced = $false
        while (-not $buildLease) {
            for ($slot=0; $slot -lt $limit; $slot++) {
                try { $buildLease = [IO.File]::Open((Join-Path $lockRoot "build-slot-$slot.lock"), 'OpenOrCreate', 'ReadWrite', 'None'); break }
                catch [IO.IOException] { }
            }
            if (-not $buildLease) {
                if (-not $announced) { Write-Host "Esperando un turno de compilacion (limite: $limit)..."; $announced=$true }
                Start-Sleep -Milliseconds 300
            }
        }
    }
    if ($SharedSetup) { $setupLease = Open-TaskLock 'shared-setup' }
    New-Item -ItemType Directory -Force -Path $session | Out-Null
    $env:DEV_RESOURCES_ROOT = $root
    $env:DEV_RESOURCE_PROJECT = $Product
    $env:DEV_RESOURCE_SESSION_TEMP = $session
    if (-not $env:LITHICA_BUILDS_ROOT) { $env:LITHICA_BUILDS_ROOT = $root }
    if (-not $env:PETROPY_BUILD_ROOT) { $env:PETROPY_BUILD_ROOT = $root }
    $env:TEMP = $session
    $env:TMP = $session
    if (-not $env:DEV_BUILD_JOBS) { $env:DEV_BUILD_JOBS = '2' }
    if (-not $env:CMAKE_BUILD_PARALLEL_LEVEL) { $env:CMAKE_BUILD_PARALLEL_LEVEL = $env:DEV_BUILD_JOBS }
    $env:LITHICA_FLUTTER_GRADLE_PLUGIN = Join-Path $env:LITHICA_BUILDS_ROOT "Shared\flutter-gradle-plugin\$Product"
    if (-not $env:PUB_CACHE) { $env:PUB_CACHE = Join-Path $env:LITHICA_BUILDS_ROOT 'Shared\pub-cache' }
    if (-not $env:GRADLE_USER_HOME) { $env:GRADLE_USER_HOME = Join-Path $env:LITHICA_BUILDS_ROOT 'Shared\gradle' }
    foreach ($cache in @{
        PIP_CACHE_DIR='pip_cache'; NUITKA_CACHE_DIR='nuitka_cache';
        npm_config_cache='npm-cache'; UV_CACHE_DIR='uv-cache'; DART_DATA_HOME='dart-data'
    }.GetEnumerator()) {
        if (-not [Environment]::GetEnvironmentVariable($cache.Key, 'Process')) {
            [Environment]::SetEnvironmentVariable($cache.Key, (Join-Path $root ('Shared\' + $cache.Value)), 'Process')
        }
    }
    $pluginSource = Join-Path $env:LITHICA_BUILDS_ROOT 'Shared\flutter-sdk\packages\flutter_tools\gradle'
    $pluginMarker = Join-Path $env:LITHICA_FLUTTER_GRADLE_PLUGIN 'src\main\scripts\native_plugin_loader.gradle.kts'
    if ($Product -ne 'PetroPyQAPF' -and (Test-Path -LiteralPath $pluginSource) -and -not (Test-Path -LiteralPath $pluginMarker)) {
        New-Item -ItemType Directory -Force -Path $env:LITHICA_FLUTTER_GRADLE_PLUGIN | Out-Null
        Get-ChildItem -LiteralPath $pluginSource -Force |
            Where-Object { $_.Name -notin @('build','.gradle','.kotlin') } |
            ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $env:LITHICA_FLUTTER_GRADLE_PLUGIN -Recurse -Force }
    }
    @{ product=$Product; supervisorPid=$PID; startedUtc=[DateTime]::UtcNow.ToString('o') } |
        ConvertTo-Json | Set-Content -LiteralPath (Join-Path $session 'session.json') -Encoding UTF8
    $global:LASTEXITCODE = 0
    if ($BatchPath) {
        $env:DEV_RESOURCE_BATCH_PATH = $BatchPath
        & $env:ComSpec /d /s /c '"%DEV_RESOURCE_BATCH_PATH%" %DEV_RESOURCE_BATCH_ARGS%'
    } elseif ($ScriptPath) {
        & $ScriptPath @ScriptParameters @ExtraArguments
    } else { throw 'A batch or PowerShell entry point is required.' }
    $result = $global:LASTEXITCODE
} finally {
    # Never prune another session based on its age: a long build may still own it.
    foreach ($name in $names) { [Environment]::SetEnvironmentVariable($name, $saved[$name], 'Process') }
    if ($setupLease) { $setupLease.Dispose() }
    if ($buildLease) { $buildLease.Dispose() }
    $lease.Dispose()
}
if ($BatchPath) { exit $result }
$global:LASTEXITCODE = $result
