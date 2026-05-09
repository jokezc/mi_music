param(
    [string]$DeviceId = "192.168.1.104:38017",
    [string]$ServerUrl = "",
    [string]$Username = "",
    [string]$Password = "",
    [string]$PlaylistName = "",
    [string]$SongName = "",
    [string]$ProjectRoot = ".",
    [string]$LogRoot = "test_logs"
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $false

$resolvedProjectRoot = (Resolve-Path $ProjectRoot).Path
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$outputDir = Join-Path $resolvedProjectRoot (Join-Path $LogRoot $timestamp)
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

$adbLogPath = Join-Path $outputDir "adb_logcat.txt"
$flutterLogPath = Join-Path $outputDir "flutter_test_output.txt"
$flutterStdoutPath = Join-Path $outputDir "flutter_stdout.txt"
$flutterStderrPath = Join-Path $outputDir "flutter_stderr.txt"

Write-Host "日志目录: $outputDir"

Push-Location $resolvedProjectRoot
try {
    & adb -s $DeviceId logcat -c

    $logcatCommand = @"
Set-Location '$resolvedProjectRoot'
adb -s $DeviceId logcat -v time | Tee-Object -FilePath '$adbLogPath'
"@

    $logcatProcess = Start-Process powershell `
        -ArgumentList "-NoLogo", "-NoProfile", "-Command", $logcatCommand `
        -PassThru `
        -WindowStyle Hidden

    Start-Sleep -Seconds 2

    $flutterArgs = @(
        "drive",
        "--driver=test_driver\\integration_test.dart",
        "--target=integration_test\\playback_flow_test.dart",
        "-d",
        $DeviceId,
        "--dart-define=MI_MUSIC_TEST_MODE=true",
        "--dart-define=MI_MUSIC_TEST_FORCE_LOCAL_DEVICE=true"
    )

    if ($ServerUrl.Trim()) {
        $flutterArgs += "--dart-define=MI_MUSIC_TEST_SERVER_URL=$ServerUrl"
    }
    if ($Username.Trim()) {
        $flutterArgs += "--dart-define=MI_MUSIC_TEST_USERNAME=$Username"
    }
    if ($Password.Trim()) {
        $flutterArgs += "--dart-define=MI_MUSIC_TEST_PASSWORD=$Password"
    }
    if ($PlaylistName.Trim()) {
        $flutterArgs += "--dart-define=MI_MUSIC_TEST_PLAYLIST_NAME=$PlaylistName"
    }
    if ($SongName.Trim()) {
        $flutterArgs += "--dart-define=MI_MUSIC_TEST_SONG_NAME=$SongName"
    }

    $flutterProcess = Start-Process flutter `
        -ArgumentList $flutterArgs `
        -WorkingDirectory $resolvedProjectRoot `
        -RedirectStandardOutput $flutterStdoutPath `
        -RedirectStandardError $flutterStderrPath `
        -PassThru `
        -WindowStyle Hidden

    $flutterProcess.WaitForExit()
    $flutterProcess.Refresh()
    $flutterExitCode = $flutterProcess.ExitCode

    $flutterStdout = if (Test-Path $flutterStdoutPath) {
        Get-Content $flutterStdoutPath -Raw
    } else {
        ""
    }
    $flutterStderr = if (Test-Path $flutterStderrPath) {
        Get-Content $flutterStderrPath -Raw
    } else {
        ""
    }

    @($flutterStdout, $flutterStderr) | Set-Content -Path $flutterLogPath

    if ($null -eq $flutterExitCode -or "$flutterExitCode" -eq "") {
        if (($flutterStdout + $flutterStderr) -match "All tests passed") {
            $flutterExitCode = 0
        }
        else {
            $flutterExitCode = 1
        }
    }

    if ($logcatProcess -and -not $logcatProcess.HasExited) {
        Stop-Process -Id $logcatProcess.Id -Force
    }

    if ($flutterExitCode -ne 0) {
        throw "集成测试失败，退出码: $flutterExitCode"
    }

    Write-Host "Flutter 输出: $flutterLogPath"
    Write-Host "ADB 日志: $adbLogPath"
}
finally {
    Pop-Location
}
