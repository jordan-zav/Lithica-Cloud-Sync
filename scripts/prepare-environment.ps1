param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Explorer', 'Mapper', 'GeoModeller', 'GeoTech', 'Atlas', 'CloudSync')]
    [string]$Product,
    [Parameter(Mandatory = $true)]
    [ValidateSet('Windows', 'Android', 'QGIS')]
    [string]$Target,
    [Parameter(Mandatory = $true)]
    [string]$ProjectRoot
)

$ErrorActionPreference = 'Stop'
$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot).TrimEnd('\')
$buildsRoot = if ($env:LITHICA_BUILDS_ROOT) {
    [System.IO.Path]::GetFullPath($env:LITHICA_BUILDS_ROOT).TrimEnd('\')
} else {
    'D:\LithicaBuilds'
}
$driveRoot = [System.IO.Path]::GetPathRoot($buildsRoot)
if (-not (Test-Path -LiteralPath $driveRoot)) {
    throw "No existe la unidad de temporales $driveRoot. Configure LITHICA_BUILDS_ROOT en una unidad local."
}

$productRoot = Join-Path $buildsRoot $Product
$sharedRoot = Join-Path $buildsRoot 'Shared'
$logRoot = Join-Path $productRoot 'logs'
$reportPath = Join-Path $logRoot 'environment-last.txt'
$createdPaths = @(
    $productRoot,
    (Join-Path $productRoot 'temp'),
    $logRoot,
    $sharedRoot,
    (Join-Path $sharedRoot 'pub-cache'),
    (Join-Path $sharedRoot 'gradle')
)
New-Item -ItemType Directory -Force -Path $createdPaths | Out-Null

$messages = [System.Collections.Generic.List[string]]::new()
function Add-Result {
    param([string]$Status, [string]$Message)
    $line = "[$Status] $Message"
    $messages.Add($line)
    Write-Host $line
}
function Stop-Preparation {
    param([string]$Message)
    Add-Result -Status 'ERROR' -Message $Message
    $messages | Set-Content -LiteralPath $reportPath -Encoding UTF8
    throw $Message
}

Add-Result -Status 'OK' -Message "Temporales preparados en $productRoot."
Add-Result -Status 'OK' -Message "Cache compartida preparada en $sharedRoot."

if ($Product -eq 'CloudSync') {
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
    if (-not $qgis) {
        Stop-Preparation 'No se encontro QGIS. Instale QGIS o configure QGIS_BIN con la ruta de qgis-bin.exe.'
    }
    Add-Result -Status 'OK' -Message "QGIS: $qgis"
} else {
    $flutterCandidates = @(
        (Join-Path $sharedRoot 'flutter-sdk'),
        $env:FLUTTER_ROOT
    )
    $flutterRoot = $flutterCandidates |
        Where-Object { $_ -and (Test-Path -LiteralPath (Join-Path $_ 'bin\flutter.bat')) } |
        Select-Object -First 1
    if (-not $flutterRoot) {
        $flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
        if ($flutterCommand) {
            $flutterRoot = Split-Path -Parent (Split-Path -Parent $flutterCommand.Source)
        }
    }
    if (-not $flutterRoot) {
        Stop-Preparation 'No se encontro Flutter. Ejecute PREPARAR_REPO.bat antes de usar LITHICA.bat.'
    }
    Add-Result -Status 'OK' -Message "Flutter: $flutterRoot"

    if ($Target -eq 'Android') {
        $androidSdk = if ($env:ANDROID_SDK_ROOT -and (Test-Path -LiteralPath $env:ANDROID_SDK_ROOT)) {
            $env:ANDROID_SDK_ROOT
        } elseif ($env:ANDROID_HOME -and (Test-Path -LiteralPath $env:ANDROID_HOME)) {
            $env:ANDROID_HOME
        } else {
            $localSdk = Join-Path $env:LOCALAPPDATA 'Android\Sdk'
            if (Test-Path -LiteralPath $localSdk) { $localSdk }
        }
        if (-not $androidSdk) {
            Stop-Preparation 'No se encontro Android SDK. Instale Android Studio o configure ANDROID_SDK_ROOT.'
        }
        Add-Result -Status 'OK' -Message "Android SDK: $androidSdk"
    }

    if ($Target -eq 'Windows') {
        $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
        $visualStudio = $null
        if (Test-Path -LiteralPath $vswhere) {
            $visualStudio = (& $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath) |
                Select-Object -First 1
        }
        if (-not $visualStudio -and (Get-Command cl.exe -ErrorAction SilentlyContinue)) {
            $visualStudio = 'Detectado mediante cl.exe'
        }
        if (-not $visualStudio) {
            Stop-Preparation 'No se encontro Visual Studio con Desktop development with C++. Instale ese workload para compilar Windows.'
        }
        Add-Result -Status 'OK' -Message "Visual Studio C++: $visualStudio"
    }
}

if ($Product -eq 'GeoModeller') {
    $pythonVersion = $null
    $pyLauncher = Get-Command py -ErrorAction SilentlyContinue
    if ($pyLauncher) {
        $previousErrorAction = $ErrorActionPreference
        try {
            $ErrorActionPreference = 'SilentlyContinue'
            foreach ($version in @('3.12', '3.11', '3.10')) {
                & $pyLauncher.Source "-$version" --version *> $null
                if ($LASTEXITCODE -eq 0) { $pythonVersion = $version; break }
            }
        } finally {
            $ErrorActionPreference = $previousErrorAction
        }
    }
    if (-not $pythonVersion) {
        $python = Get-Command python -ErrorAction SilentlyContinue
        if ($python) {
            $versionText = (& $python.Source --version 2>&1) -join ''
            if ($versionText -match 'Python 3\.(10|11|12)') { $pythonVersion = "3.$($matches[1])" }
        }
    }
    if (-not $pythonVersion) {
        Stop-Preparation 'GeoModeller requiere Python 3.10, 3.11 o 3.12 para GemPy.'
    }
    if (-not (Test-Path -LiteralPath (Join-Path $ProjectRoot 'backend\requirements.txt'))) {
        Stop-Preparation 'Falta backend\requirements.txt en GeoModeller.'
    }
    Add-Result -Status 'OK' -Message "Python compatible: $pythonVersion"
}

if ($Product -in @('GeoTech', 'Atlas') -and $Target -eq 'Windows') {
    $oauthPath = Join-Path $ProjectRoot 'local_secrets\google-desktop-oauth.json'
    if (-not $env:LITHICA_GOOGLE_DESKTOP_CLIENT_SECRET -and -not (Test-Path -LiteralPath $oauthPath)) {
        Stop-Preparation "Falta OAuth de escritorio: $oauthPath"
    }
    Add-Result -Status 'OK' -Message 'OAuth de escritorio disponible.'
}

if ($Product -eq 'Atlas') {
    $projectsRoot = Split-Path -Parent $ProjectRoot
    $knowledgeBase = Join-Path $projectsRoot 'PetroPyQAPF\knowledge_base\minerals\minerales'
    if (-not (Test-Path -LiteralPath $knowledgeBase)) {
        Add-Result -Status 'WARN' -Message 'PetroPyQAPF no esta presente; solo se deshabilitan herramientas auxiliares de catalogacion.'
    } else {
        Add-Result -Status 'OK' -Message "Base de conocimiento auxiliar: $knowledgeBase"
    }
}

$messages | Set-Content -LiteralPath $reportPath -Encoding UTF8
Write-Host "Reporte de entorno: $reportPath"
exit 0
