$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$workspaceRoot = $scriptRoot
$buildsRoot = if ($env:LITHICA_BUILDS_ROOT) { [System.IO.Path]::GetFullPath($env:LITHICA_BUILDS_ROOT).TrimEnd('\') } else { 'D:\LithicaBuilds' }
$source = Join-Path $scriptRoot "lithica_drive_sync"
$releasesRoot = if ($env:LITHICA_RELEASES_ROOT) { [System.IO.Path]::GetFullPath($env:LITHICA_RELEASES_ROOT).TrimEnd('\') } else { Join-Path $buildsRoot 'Releases' }
$artifacts = Join-Path $releasesRoot "CloudSync\qgis"
$cloudSyncBuildRoot = Join-Path $buildsRoot 'CloudSync'
$stagingRoot = Join-Path $cloudSyncBuildRoot "qgis_plugin_staging"
$stagingPlugin = Join-Path $stagingRoot "lithica_drive_sync"
$metadataPath = Join-Path $source "metadata.txt"
$metadataVersionMatch = Select-String -LiteralPath $metadataPath -Pattern '^version=(.+)$'
if (-not $metadataVersionMatch -or $metadataVersionMatch.Matches.Count -ne 1) {
    throw "metadata.txt must contain exactly one version entry."
}
$pluginVersion = $metadataVersionMatch.Matches[0].Groups[1].Value.Trim()
if ($pluginVersion -notmatch '^\d+\.\d+\.\d+$') {
    throw "Invalid plugin version in metadata.txt: $pluginVersion"
}
$target = Join-Path $artifacts "Lithica Cloud Sync-$pluginVersion.zip"
$temporaryTarget = Join-Path $cloudSyncBuildRoot ("Lithica Cloud Sync-" + [guid]::NewGuid().ToString("N") + ".tmp.zip")

$resolvedBuildRoot = [System.IO.Path]::GetFullPath($cloudSyncBuildRoot).TrimEnd('\')
$resolvedStaging = [System.IO.Path]::GetFullPath($stagingRoot)
if (-not $resolvedStaging.StartsWith("$resolvedBuildRoot\", [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Staging path is outside the Lithica build root."
}

New-Item -ItemType Directory -Path $artifacts, $cloudSyncBuildRoot -Force | Out-Null
if (Test-Path -LiteralPath $stagingRoot) {
    Remove-Item -LiteralPath $stagingRoot -Recurse -Force
}
New-Item -ItemType Directory -Path $stagingPlugin -Force | Out-Null

$excludedNames = @("__pycache__", ".pytest_cache")
Get-ChildItem -LiteralPath $source -Recurse -File |
    Where-Object {
        $relative = $_.FullName.Substring($source.Length).TrimStart("\")
        $parts = $relative -split "[\\/]"
        -not ($parts | Where-Object { $excludedNames -contains $_ })
    } |
    ForEach-Object {
        $relative = $_.FullName.Substring($source.Length).TrimStart("\")
        $destination = Join-Path $stagingPlugin $relative
        $parent = Split-Path -Parent $destination
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
        Copy-Item -LiteralPath $_.FullName -Destination $destination
    }

$licenseSource = Join-Path $scriptRoot "LICENSE"
if (-not (Test-Path -LiteralPath $licenseSource)) {
    throw "The required LICENSE file was not found."
}
$licenseText = Get-Content -LiteralPath $licenseSource -Raw
if (
    $licenseText -notmatch 'GNU GENERAL PUBLIC LICENSE' -or
    $licenseText -notmatch 'Version 3, 29 June 2007' -or
    $licenseText -notmatch 'END OF TERMS AND CONDITIONS'
) {
    throw "LICENSE must contain the complete GNU GPL version 3 text."
}
Copy-Item -LiteralPath $licenseSource -Destination (Join-Path $stagingPlugin "LICENSE")

$dangerPatterns = @(
    "-----BEGIN PRIVATE KEY-----",
    '"type"\s*:\s*"service_account"',
    "ya29\.[A-Za-z0-9_-]{20,}",
    "1//[A-Za-z0-9_-]{20,}"
)
$findings = Get-ChildItem -LiteralPath $stagingPlugin -Recurse -File |
    Select-String -Pattern $dangerPatterns
if ($findings) {
    throw "Packaging stopped because credential material was detected."
}

$baseTarget = $temporaryTarget.Substring(0, $temporaryTarget.Length - 4)
python -c "import shutil; shutil.make_archive(r'$baseTarget', 'zip', r'$stagingRoot')"

$replaced = $false
for ($attempt = 1; $attempt -le 5 -and -not $replaced; $attempt++) {
    try {
        if (Test-Path -LiteralPath $target) {
            Remove-Item -LiteralPath $target -Force
        }
        Move-Item -LiteralPath $temporaryTarget -Destination $target -Force
        $replaced = $true
    } catch {
        if ($attempt -eq 5) {
            throw
        }
        Start-Sleep -Milliseconds 500
    }
}
Remove-Item -LiteralPath $stagingRoot -Recurse -Force

Write-Output $target
