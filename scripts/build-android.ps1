<#
.SYNOPSIS
Build and verify a local signed Oh My Esok candidate without GitHub Actions.
.DESCRIPTION
Activate the project's Flutter and Android SDK in this session first. Supply
the signing variables described in docs/RELEASING.md via the process environment.
This script never publishes or posts a QA status.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

function Invoke-Checked {
    param([string]$Executable, [string[]]$Arguments)
    & $Executable @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Executable failed (exit $LASTEXITCODE)."
    }
}

Push-Location (Split-Path -Parent $PSScriptRoot)
try {
    if (Invoke-Checked git @('status', '--porcelain')) {
        throw 'Build a release candidate from a clean checkout.'
    }
    $sourceCommit = (Invoke-Checked git @('rev-parse', 'HEAD')).Trim()
    $sdkRoot = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { $env:ANDROID_SDK_ROOT }
    if (-not $sdkRoot) { throw 'Set ANDROID_HOME to the project Android SDK.' }
    $buildTools = Join-Path $sdkRoot 'build-tools/36.0.0'
    $aapt = Join-Path $buildTools 'aapt.exe'
    $apksigner = Join-Path $buildTools 'apksigner.bat'
    foreach ($binary in @($aapt, $apksigner)) {
        if (-not (Test-Path -LiteralPath $binary -PathType Leaf)) {
            throw "Android Build Tools 36.0.0 is incomplete: $binary"
        }
    }
    foreach ($name in @(
        'OH_MY_ESOK_KEYSTORE',
        'OH_MY_ESOK_STORE_PASSWORD',
        'OH_MY_ESOK_KEY_ALIAS',
        'OH_MY_ESOK_KEY_PASSWORD'
    )) {
        if (-not [Environment]::GetEnvironmentVariable($name)) {
            throw "Set $name in the build process environment."
        }
    }

    Invoke-Checked flutter @('--version')
    Invoke-Checked flutter @('pub', 'get', '--enforce-lockfile')
    Invoke-Checked flutter @('analyze', '--no-pub')
    Invoke-Checked flutter @('test', '--no-pub', '--reporter', 'expanded')
    Invoke-Checked flutter @('build', 'apk', '--release', '--no-pub')
    if ((Invoke-Checked git @('rev-parse', 'HEAD')).Trim() -ne $sourceCommit -or
        (Invoke-Checked git @('status', '--porcelain'))) {
        throw 'The checkout changed while building. Resolve it and rebuild.'
    }
    Invoke-Checked python @(
        'scripts/release_metadata.py', '--apk', 'build/app/outputs/flutter-apk/app-release.apk',
        '--output', 'dist', '--aapt', $aapt, '--apksigner', $apksigner,
        '--source-commit', $sourceCommit
    )
} finally {
    Pop-Location
}
