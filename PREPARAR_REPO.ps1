param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Explorer','Mapper','GeoModeller','GeoTech','Atlas','CloudSync','Suite','Academy')]
    [string]$Product,
    [Parameter(Mandatory = $true)]
    [string]$ProjectRoot,
    [string]$TargetSet = 'None',
    [switch]$CheckOnly
)
$ErrorActionPreference = 'Stop'
$ProjectRoot = [IO.Path]::GetFullPath($ProjectRoot).TrimEnd('\')
$targets = @($TargetSet -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -and $_ -ne 'None' })
$buildsRoot = if ($env:LITHICA_BUILDS_ROOT) { [IO.Path]::GetFullPath($env:LITHICA_BUILDS_ROOT).TrimEnd('\') } else { 'D:\LithicaBuilds' }
$driveRoot = [IO.Path]::GetPathRoot($buildsRoot)
if (-not (Test-Path -LiteralPath $driveRoot -PathType Container)) { throw "No existe $driveRoot. Cree esa unidad o defina LITHICA_BUILDS_ROOT." }
if (-not (Test-Path -LiteralPath $ProjectRoot -PathType Container)) { throw "No existe el repo: $ProjectRoot" }
$productRoot = Join-Path $buildsRoot $Product
$sharedRoot = Join-Path $buildsRoot 'Shared'
$logRoot = Join-Path $productRoot 'logs'
$reportPath = Join-Path $logRoot 'prepare-repo-last.txt'
$envFile = Join-Path $sharedRoot ("lithica-env-$Product.cmd")
New-Item -ItemType Directory -Force -Path @(
    $productRoot,(Join-Path $productRoot 'temp'),(Join-Path $productRoot 'build'),$logRoot,
    $sharedRoot,(Join-Path $sharedRoot 'downloads'),(Join-Path $sharedRoot 'pub-cache'),(Join-Path $sharedRoot 'gradle')
) | Out-Null
$messages = [Collections.Generic.List[string]]::new()
$errors = [Collections.Generic.List[string]]::new()
$warnings = [Collections.Generic.List[string]]::new()
function Add-Status([string]$Status,[string]$Text) {
    $line = "[$Status] $Text"
    $messages.Add($line)
    Write-Host $line
    if ($Status -eq 'ERROR') { $errors.Add($Text) }
    if ($Status -eq 'WARN') { $warnings.Add($Text) }
}
function Find-Flutter {
    $candidates = @(
        (Join-Path $sharedRoot 'flutter-sdk'),$env:FLUTTER_ROOT
    )
    foreach ($candidate in $candidates) {
        if (-not $candidate) { continue }
        if (Test-Path -LiteralPath (Join-Path $candidate 'bin\flutter.bat')) {
            $item = Get-Item -LiteralPath $candidate -Force
            if ($item.LinkType) {
                Add-Status 'WARN' "Se ignoro un enlace de Flutter: $candidate"
                continue
            }
            return [IO.Path]::GetFullPath($candidate).TrimEnd('\')
        }
    }
    $command = Get-Command flutter.bat -ErrorAction SilentlyContinue
    if (-not $command) { $command = Get-Command flutter -ErrorAction SilentlyContinue }
    if ($command) { return Split-Path -Parent (Split-Path -Parent $command.Source) }
    return $null
}
function Install-Flutter {
    $destination = Join-Path $sharedRoot 'flutter-sdk'
    if (Test-Path -LiteralPath $destination) { throw "Quite o renombre el Flutter incompleto: $destination" }
    Add-Status 'INFO' 'Descargando una sola copia compartida de Flutter estable. Puede tardar varios minutos.'
    $manifest = Invoke-RestMethod -Uri 'https://storage.googleapis.com/flutter_infra_release/releases/releases_windows.json'
    $release = $manifest.releases | Where-Object { $_.hash -eq $manifest.current_release.stable } | Select-Object -First 1
    if (-not $release) { throw 'No se pudo resolver Flutter estable.' }
    $archiveUri = $manifest.base_url.TrimEnd('/') + '/' + $release.archive
    $archivePath = Join-Path (Join-Path $sharedRoot 'downloads') ([IO.Path]::GetFileName($release.archive))
    if (-not (Test-Path -LiteralPath $archivePath)) { Invoke-WebRequest -UseBasicParsing -Uri $archiveUri -OutFile $archivePath }
    $stage = Join-Path $sharedRoot ('flutter-stage-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $stage | Out-Null
    try {
        Expand-Archive -LiteralPath $archivePath -DestinationPath $stage -Force
        $expanded = Join-Path $stage 'flutter'
        if (-not (Test-Path -LiteralPath (Join-Path $expanded 'bin\flutter.bat'))) { throw 'SDK Flutter descargado no valido.' }
        Move-Item -LiteralPath $expanded -Destination $destination
    } finally {
        if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force }
    }
    return $destination
}
function Find-AndroidSdk {
    foreach ($candidate in @((Join-Path $sharedRoot 'android-sdk'),$env:ANDROID_SDK_ROOT,$env:ANDROID_HOME)) {
        if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Container)) { return [IO.Path]::GetFullPath($candidate) }
    }
    return $null
}
function Find-JavaHome {
    foreach ($candidate in @((Join-Path $sharedRoot 'jdk-17'),$env:JAVA_HOME)) {
        if ($candidate -and (Test-Path -LiteralPath (Join-Path $candidate 'bin\java.exe'))) { return [IO.Path]::GetFullPath($candidate) }
    }
    return $null
}
function Find-VisualStudio {
    $pf86 = [Environment]::GetEnvironmentVariable('ProgramFiles(x86)')
    if ($pf86) {
        $vswhere = Join-Path $pf86 'Microsoft Visual Studio\Installer\vswhere.exe'
        if (Test-Path -LiteralPath $vswhere) {
            $found = (& $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath) | Select-Object -First 1
            if ($found) { return $found }
        }
    }
    if (Get-Command cl.exe -ErrorAction SilentlyContinue) { return 'PATH:cl.exe' }
    return $null
}
function Find-Qgis {
    if ($env:QGIS_BIN -and (Test-Path -LiteralPath $env:QGIS_BIN)) { return $env:QGIS_BIN }
    foreach ($commandName in @('qgis-bin.exe','qgis-ltr-bin.exe','qgis.exe')) {
        $command = Get-Command $commandName -ErrorAction SilentlyContinue
        if ($command) { return $command.Source }
    }
    $programFiles = [Environment]::GetFolderPath('ProgramFiles')
    $patterns = @(
        (Join-Path $programFiles 'QGIS *\bin\qgis-bin.exe'),
        (Join-Path $programFiles 'QGIS *\bin\qgis-ltr-bin.exe')
    )
    foreach ($drive in Get-PSDrive -PSProvider FileSystem) {
        $patterns += Join-Path $drive.Root 'QGIS\bin\qgis-bin.exe'
        $patterns += Join-Path $drive.Root 'QGIS\bin\qgis-ltr-bin.exe'
    }
    foreach ($pattern in $patterns) {
        $found = Get-ChildItem -Path $pattern -File -ErrorAction SilentlyContinue |
            Sort-Object FullName -Descending | Select-Object -First 1
        if ($found) { return $found.FullName }
    }
    return $null
}
Add-Status 'OK' "Repo: $ProjectRoot"
Add-Status 'OK' "Temporales: $productRoot"
Add-Status 'OK' "Cache compartida: $sharedRoot"
$envLines = [Collections.Generic.List[string]]::new()
$envLines.Add('@echo off')
$envLines.Add('@set "LITHICA_BUILDS_ROOT=' + $buildsRoot + '"')
$envLines.Add('@set "PUB_CACHE=' + (Join-Path $sharedRoot 'pub-cache') + '"')
$envLines.Add('@set "GRADLE_USER_HOME=' + (Join-Path $sharedRoot 'gradle') + '"')
$envLines.Add('@set "ANDROID_USER_HOME=' + (Join-Path $sharedRoot 'android-user-home') + '"')
$envLines.Add('@set "TEMP=' + (Join-Path $productRoot 'system-temp') + '"')
$envLines.Add('@set "TMP=%TEMP%"')
if ($Product -in @('Explorer','Mapper','GeoModeller','GeoTech','Atlas')) {
    $flutterRoot = Find-Flutter
    if (-not (Test-Path -LiteralPath (Join-Path $ProjectRoot 'pubspec.yaml'))){ Add-Status 'ERROR' 'Falta pubspec.yaml.' }
    if (-not $flutterRoot -and -not $CheckOnly) {
        try { $flutterRoot = Install-Flutter } catch { Add-Status 'ERROR' $_.Exception.Message }
    }
    if (-not $flutterRoot) { Add-Status 'ERROR' 'No se encontro Flutter. Ejecute sin --check-only para descargarlo una sola vez.' }
}
if ($flutterRoot) {
    Add-Status 'OK' "Flutter compartido: $flutterRoot"
    $envLines.Add('@set "FLUTTER_ROOT=' + $flutterRoot + '"')
    $envLines.Add('@set "PATH=%FLUTTER_ROOT%\bin;%PATH%"')
}
if ($targets -contains 'Android') {
    $sdk = Find-AndroidSdk
    $java = Find-JavaHome
    if ($sdk) {
        Add-Status 'OK' "Android SDK: $sdk"
        $envLines.Add('@set "ANDROID_SDK_ROOT=' + $sdk + '"')
        $envLines.Add('@set "ANDROID_HOME=' + $sdk + '"')
    } else { Add-Status 'ERROR' 'Falta Android SDK. Instale Android Studio o configure ANDROID_SDK_ROOT.' }
    if ($java) {
        Add-Status 'OK' "JDK: $java"
        $envLines.Add('@set "JAVA_HOME=' + $java + '"')
    } else { Add-Status 'ERROR' 'Falta JDK. Instale Android Studio con JBR o configure JAVA_HOME.' }
    $signingProfile = Join-Path $buildsRoot ("Secrets\$Product\android-signing")
    $signingProperties = Join-Path $signingProfile 'key.properties'
    $envLines.Add('@set "LITHICA_ANDROID_SIGNING_PROFILE=' + $signingProfile + '"')
    if (Test-Path -LiteralPath $signingProperties -PathType Leaf) {
        $storeFileName = $null
        foreach ($line in Get-Content -LiteralPath $signingProperties) {
            if ($line -match '^\s*storeFile\s*=\s*(.+?)\s*$') { $storeFileName = $matches[1]; break }
        }
        if ($storeFileName -and (Test-Path -LiteralPath (Join-Path $signingProfile $storeFileName) -PathType Leaf)) {
            Add-Status 'OK' "Firma Android central: $signingProfile"
        } else {
            Add-Status 'WARN' "key.properties no encuentra su almacen en $signingProfile"
        }
    } else {
        Add-Status 'WARN' "Firma Android pendiente: $signingProfile"
    }
}
if ($targets -contains 'Windows') {
    $vs = Find-VisualStudio
    if ($vs) { Add-Status 'OK' "Visual Studio C++: $vs" }
    else { Add-Status 'ERROR' 'Falta Visual Studio con Desktop development with C++.' }
}
if ($targets -contains 'QGIS') {
    $qgis = Find-Qgis
    if ($qgis) {
        Add-Status 'OK' "QGIS: $qgis"
        $envLines.Add('@set "QGIS_BIN=' + $qgis + '"')
    } else { Add-Status 'ERROR' 'No se encontro QGIS. Instale QGIS manualmente o configure QGIS_BIN para abrir y probar el complemento.' }
}
if ($Product -eq 'GeoModeller') {
    $python = Get-Command py.exe -ErrorAction SilentlyContinue
    if (-not $python) { $python = Get-Command python.exe -ErrorAction SilentlyContinue }
    if ($python) { Add-Status 'OK' "Python: $($python.Source)" } else { Add-Status 'ERROR' 'Falta Python 3.10, 3.11 o 3.12.' }
    if (-not (Test-Path -LiteralPath (Join-Path $ProjectRoot 'backend\requirements.txt'))) { Add-Status 'ERROR' 'Falta backend\requirements.txt.' }
}
if ($Product -in @('Atlas','GeoTech')) {
    $oauth = Join-Path $ProjectRoot 'local_secrets\google-desktop-oauth.json'
    if (-not $env:LITHICA_GOOGLE_DESKTOP_CLIENT_SECRET -and -not (Test-Path -LiteralPath $oauth)) {
        Add-Status 'WARN' 'OAuth de escritorio no esta configurado y no debe subirse a GitHub.'
    } else { Add-Status 'OK' 'OAuth de escritorio disponible.' }
}
if ($Product -eq 'Atlas') {
    $kb = Join-Path (Split-Path -Parent $ProjectRoot) 'PetroPyQAPF\knowledge_base\minerals\minerales'
    if (Test-Path -LiteralPath $kb) { Add-Status 'OK' "Base auxiliar PetroPyQAPF: $kb" }
    else { Add-Status 'WARN' 'PetroPyQAPF ausente; solo afecta herramientas auxiliares de catalogacion.' }
}
if ($Product -in @('Suite','Academy')) { Add-Status 'WARN' 'Este repo aun no tiene aplicacion ejecutable.' }
$envLines | Set-Content -LiteralPath $envFile -Encoding ASCII
$messages | Set-Content -LiteralPath $reportPath -Encoding UTF8
Write-Host "Reporte: $reportPath"
if ($errors.Count -gt 0) {
    Write-Host "Preparacion incompleta: $($errors.Count) error(es), $($warnings.Count) advertencia(s)."
    exit 1
}
Write-Host "Preparacion completa: 0 errores, $($warnings.Count) advertencia(s)."
if (Test-Path -LiteralPath (Join-Path $ProjectRoot 'LITHICA.bat')) { Write-Host 'Ya puede ejecutar LITHICA.bat.' }
exit 0
