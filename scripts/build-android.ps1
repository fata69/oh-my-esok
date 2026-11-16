#Requires -Version 7.0
<#
.SYNOPSIS
Build and verify a local signed Oh My Esok candidate without GitHub Actions.
.DESCRIPTION
Activate the project's Flutter and Android SDK in this session first. Supply
the signing variables described in docs/RELEASING.md via the process environment.
They are consumed and removed before any child process starts. Compilation runs
unsigned; passwords go into the environment of the apksigner child only.
This script never publishes or posts a QA status.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# Capture in this PowerShell process only. Do this before Git, Flutter, Gradle,
# dependencies or metadata tools can inherit the caller's signing environment.
$signingNames = @(
    'OH_MY_ESOK_KEYSTORE',
    'OH_MY_ESOK_STORE_PASSWORD',
    'OH_MY_ESOK_KEY_ALIAS',
    'OH_MY_ESOK_KEY_PASSWORD'
)
$signing = @{}
foreach ($name in $signingNames) {
    $signing[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
    Remove-Item -LiteralPath "Env:$name" -ErrorAction SilentlyContinue
}
$previousUnsignedMode = [Environment]::GetEnvironmentVariable('OH_MY_ESOK_UNSIGNED_BUILD', 'Process')
$passwordVariables = @('OH_MY_ESOK_SIGN_STORE_PASSWORD', 'OH_MY_ESOK_SIGN_KEY_PASSWORD')
foreach ($name in $passwordVariables) {
    Remove-Item -LiteralPath "Env:$name" -ErrorAction SilentlyContinue
}

function Invoke-Checked {
    param([string]$Executable, [string[]]$Arguments)
    & $Executable @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Executable failed (exit $LASTEXITCODE)."
    }
}

function Sign-Apk {
    param([string]$Java, [string[]]$Arguments)
    $start = [Diagnostics.ProcessStartInfo]::new($Java)
    $start.UseShellExecute = $false
    foreach ($argument in $Arguments) {
        $start.ArgumentList.Add($argument)
    }
    # Do not allow injected JVM options or place passwords in the parent environment.
    foreach ($name in @('JDK_JAVA_OPTIONS', 'JAVA_TOOL_OPTIONS', '_JAVA_OPTIONS')) {
        [void]$start.Environment.Remove($name)
    }
    $start.Environment[$passwordVariables[0]] = $signing['OH_MY_ESOK_STORE_PASSWORD']
    $start.Environment[$passwordVariables[1]] = $signing['OH_MY_ESOK_KEY_PASSWORD']
    try {
        $signer = [Diagnostics.Process]::Start($start)
    } finally {
        foreach ($name in $passwordVariables) {
            [void]$start.Environment.Remove($name)
        }
        $signing.Clear()
    }
    try {
        $signer.WaitForExit()
        if ($signer.ExitCode -ne 0) {
            throw "apksigner sign failed (exit $($signer.ExitCode))."
        }
    } finally {
        $signer.Dispose()
    }
}

Push-Location (Split-Path -Parent $PSScriptRoot)
try {
    foreach ($name in $signingNames) {
        if ([string]::IsNullOrWhiteSpace($signing[$name])) {
            throw "Set $name in the build process environment before invoking this script."
        }
    }
    if (-not [IO.Path]::IsPathFullyQualified($signing['OH_MY_ESOK_KEYSTORE']) -or
        -not (Test-Path -LiteralPath $signing['OH_MY_ESOK_KEYSTORE'] -PathType Leaf)) {
        throw 'OH_MY_ESOK_KEYSTORE must be an existing absolute keystore path outside the checkout.'
    }
    $repoRoot = (Get-Location).Path
    $keyPath = (Resolve-Path -LiteralPath $signing['OH_MY_ESOK_KEYSTORE']).Path
    if ($keyPath.StartsWith($repoRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Keep the release keystore outside the checkout and its build output.'
    }
    if (Invoke-Checked git @('status', '--porcelain')) {
        throw 'Build a release candidate from a clean checkout.'
    }
    $sourceCommit = (Invoke-Checked git @('rev-parse', 'HEAD')).Trim()
    $sdkRoot = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { $env:ANDROID_SDK_ROOT }
    if (-not $sdkRoot) { throw 'Set ANDROID_HOME to the project Android SDK.' }
    if (-not $env:JAVA_HOME) { throw 'Set JAVA_HOME to the trusted project JDK.' }
    $buildTools = Join-Path $sdkRoot 'build-tools/36.0.0'
    $aapt = Join-Path $buildTools 'aapt.exe'
    $zipalign = Join-Path $buildTools 'zipalign.exe'
    $apksigner = Join-Path $buildTools 'lib/apksigner.jar'
    $java = Join-Path $env:JAVA_HOME 'bin/java.exe'
    foreach ($binary in @($aapt, $zipalign, $apksigner, $java)) {
        if (-not (Test-Path -LiteralPath $binary -PathType Leaf)) {
            throw "Required JDK or Android Build Tools 36.0.0 file is missing: $binary"
        }
    }
    $env:OH_MY_ESOK_UNSIGNED_BUILD = 'true'
    Invoke-Checked flutter @('--version')
    Invoke-Checked flutter @('pub', 'get', '--enforce-lockfile')
    Invoke-Checked flutter @('analyze', '--no-pub')
    Invoke-Checked flutter @('test', '--no-pub', '--reporter', 'expanded')
    $unsignedApk = Join-Path $repoRoot 'build/app/outputs/flutter-apk/app-release.apk'
    if (Test-Path -LiteralPath $unsignedApk -PathType Leaf) {
        Remove-Item -LiteralPath $unsignedApk
    }
    Invoke-Checked flutter @(
        'build', 'apk', '--release', '--no-pub',
        '--target-platform', 'android-arm,android-arm64,android-x64'
    )
    if ((Invoke-Checked git @('rev-parse', 'HEAD')).Trim() -ne $sourceCommit -or
        (Invoke-Checked git @('status', '--porcelain'))) {
        throw 'The checkout changed while building. Resolve it and rebuild.'
    }

    if (-not (Test-Path -LiteralPath $unsignedApk -PathType Leaf)) {
        throw 'The unsigned universal APK is missing from the Flutter build output.'
    }
    # A valid existing signature means this artifact did not come from unsigned mode.
    $PSNativeCommandUseErrorActionPreference = $false
    & $java -jar $apksigner verify $unsignedApk *> $null
    if ($LASTEXITCODE -eq 0) {
        throw 'Unsigned compilation produced a signed APK. Refusing to replace or trust its signature.'
    }
    Invoke-Checked $zipalign @('-c', '-P', '16', '4', $unsignedApk)
    $staging = Join-Path $repoRoot ('build/local-signing/' + [guid]::NewGuid())
    New-Item -Path $staging -ItemType Directory -Force | Out-Null
    $signedApk = Join-Path $staging 'app-release-signed.apk'

    # No Flutter/Gradle/dependency code runs after this point. Run the official
    # jar directly so the keystore path and alias are not parsed by cmd.exe.
    Sign-Apk -Java $java -Arguments @(
        '-jar', $apksigner, 'sign',
        '--ks', $keyPath, '--ks-key-alias', $signing['OH_MY_ESOK_KEY_ALIAS'],
        '--ks-pass', 'env:OH_MY_ESOK_SIGN_STORE_PASSWORD',
        '--key-pass', 'env:OH_MY_ESOK_SIGN_KEY_PASSWORD',
        '--out', $signedApk, $unsignedApk
    )
    Invoke-Checked $zipalign @('-c', '-P', '16', '4', $signedApk)
    Invoke-Checked python @(
        'scripts/release_metadata.py', '--apk', $signedApk,
        '--output', 'dist', '--aapt', $aapt, '--apksigner', $apksigner, '--java', $java,
        '--source-commit', $sourceCommit
    )
} finally {
    foreach ($name in ($signingNames + $passwordVariables)) {
        Remove-Item -LiteralPath "Env:$name" -ErrorAction SilentlyContinue
    }
    if ($null -eq $previousUnsignedMode) {
        Remove-Item -LiteralPath 'Env:OH_MY_ESOK_UNSIGNED_BUILD' -ErrorAction SilentlyContinue
    } else {
        $env:OH_MY_ESOK_UNSIGNED_BUILD = $previousUnsignedMode
    }
    $signing.Clear()
    Pop-Location
}
