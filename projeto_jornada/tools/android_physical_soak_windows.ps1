param(
    [string]$Apk = ".\veredas-debug.apk",
    [string]$OutputDirectory = ".\veredas-physical-soak-11-3",
    [int]$SoakSeconds = 1800,
    [string]$Operator = $env:USERNAME
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$Package = "com.pmartins87.veredasdatrama"
$ExpectedApkSha256 = "d01119c949ecd72b20f1af9b56dac8a359452ae71503612f4e898a173c5ff879"
$CandidateSourceHead = "bb6b1e70a5c880582b9f33c8f7b4e62bb2f89817"
$CandidateWorkflowRunId = 31856094548
$CandidateApkArtifactId = 9239079052
$MinSoak = 1800
$MaxColdMs = 3000
$ResumeSamplesRequired = 12
$MaxResumeP95Ms = 1500
$MaxPssKb = 420 * 1024
$MaxPssDriftKb = 96 * 1024

function Fail([string]$Message) {
    throw "11.3 PHYSICAL SOAK: $Message"
}

function AdbText([string[]]$Args) {
    return (& adb @Args 2>&1 | Out-String)
}

function SaveText([string]$Path, [string]$Text) {
    [IO.File]::WriteAllText($Path, $Text, (New-Object Text.UTF8Encoding($false)))
}

function Capture([string[]]$Args, [string]$Path) {
    $text = AdbText $Args
    SaveText $Path $text
    return $text
}

function Prop([string]$Name) {
    return ((AdbText @('shell', 'getprop', $Name)).Trim())
}

function WaitPid([int]$Seconds = 60) {
    for ($i = 0; $i -lt $Seconds; $i++) {
        $p = ((AdbText @('shell', 'pidof', $Package)).Trim())
        if ($p) {
            return $p
        }
        Start-Sleep -Seconds 1
    }
    return ""
}

function Launch([string]$Path) {
    $text = Capture @(
        'shell', 'am', 'start', '-W',
        '-a', 'android.intent.action.MAIN',
        '-c', 'android.intent.category.LAUNCHER',
        '-p', $Package
    ) $Path
    if ($text -match '(?mi)^TotalTime:\s*(\d+)') {
        return [int]$Matches[1]
    }
    if ($text -match '(?mi)^WaitTime:\s*(\d+)') {
        return [int]$Matches[1]
    }
    return -1
}

function Mem([string]$Label, [string]$Directory) {
    $text = Capture @('shell', 'dumpsys', 'meminfo', $Package) (Join-Path $Directory "$Label.txt")
    if ($text -match '(?mi)TOTAL PSS:\s*([\d,]+)') {
        return [int](($Matches[1] -replace ',', ''))
    }
    if ($text -match '(?mi)^\s*TOTAL\s+([\d,]+)') {
        return [int](($Matches[1] -replace ',', ''))
    }
    return -1
}

function P95([int[]]$Values) {
    if (-not $Values -or $Values.Count -eq 0) {
        return -1
    }
    $sorted = @($Values | Sort-Object)
    $idx = [Math]::Round(($sorted.Count - 1) * 0.95)
    if ($idx -lt 0) {
        $idx = 0
    }
    if ($idx -ge $sorted.Count) {
        $idx = $sorted.Count - 1
    }
    return [int]$sorted[$idx]
}

function AskYes([string]$Question) {
    while ($true) {
        $answer = (Read-Host "$Question [S/N]").Trim().ToUpperInvariant()
        if ($answer -in @('S', 'SIM', 'Y', 'YES')) {
            return $true
        }
        if ($answer -in @('N', 'NAO', 'NO')) {
            return $false
        }
    }
}

if ($SoakSeconds -lt $MinSoak) {
    Fail "soak must be at least $MinSoak seconds"
}
if (-not (Test-Path -LiteralPath $Apk -PathType Leaf)) {
    Fail "APK not found: $Apk"
}
if (-not (Get-Command adb -ErrorAction SilentlyContinue)) {
    Fail "adb not found in PATH"
}

$apkPath = (Resolve-Path -LiteralPath $Apk).Path
$apkSha = (Get-FileHash -LiteralPath $apkPath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($apkSha -ne $ExpectedApkSha256) {
    Fail "wrong APK SHA-256; expected=$ExpectedApkSha256 actual=$apkSha"
}

$devices = @(& adb devices | Select-Object -Skip 1 | Where-Object { $_ -match "`tdevice\s*$" })
if ($devices.Count -ne 1) {
    Fail "exactly one authorized Android device is required; found=$($devices.Count)"
}

$serial = ($devices[0] -split "`t")[0].Trim()
$manufacturer = Prop 'ro.product.manufacturer'
$model = Prop 'ro.product.model'
$androidRelease = Prop 'ro.build.version.release'
$apiText = Prop 'ro.build.version.sdk'
try {
    $apiLevel = [int]$apiText
}
catch {
    Fail "invalid API level: $apiText"
}
if ($apiLevel -lt 24) {
    Fail "API level $apiLevel is below minimum 24"
}

$root = [IO.Path]::GetFullPath($OutputDirectory)
$raw = Join-Path $root 'raw'
$launchDir = Join-Path $raw 'launch'
$memDir = Join-Path $raw 'meminfo'
if (Test-Path -LiteralPath $root) {
    Remove-Item -LiteralPath $root -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $launchDir, $memDir | Out-Null

$context = @(
    "serial=$serial",
    "manufacturer=$manufacturer",
    "model=$model",
    "android_release=$androidRelease",
    "api_level=$apiLevel",
    "package=$Package",
    "apk_sha256=$apkSha",
    "requested_soak_seconds=$SoakSeconds",
    "operator=$Operator"
) -join "`r`n"
SaveText (Join-Path $raw 'context.txt') ($context + "`r`n")

Write-Host ""
Write-Host "Veredas da Trama - physical Android soak 11.3"
Write-Host "Device: $manufacturer $model | Android $androidRelease (API $apiLevel)"
Write-Host "APK SHA-256 confirmed: $apkSha"
Write-Host "The script will install the APK, measure cold launch, and run 12 resume cycles."
Write-Host "When prompted, play normally for at least 30 minutes."
Write-Host "Keep USB connected and do not close this window."
Write-Host ""

$install = Capture @('install', '-r', $apkPath) (Join-Path $raw 'install.txt')
if ($LASTEXITCODE -ne 0 -or $install -notmatch '(?i)Success') {
    Fail "APK installation failed"
}

& adb logcat -c | Out-Null
$batteryBefore = Capture @('shell', 'dumpsys', 'battery') (Join-Path $raw 'battery-before.txt')
$thermalBefore = Capture @('shell', 'dumpsys', 'thermalservice') (Join-Path $raw 'thermal-before.txt')
Capture @('shell', 'dumpsys', 'cpuinfo') (Join-Path $raw 'cpu-before.txt') | Out-Null

$failures = New-Object System.Collections.Generic.List[string]
$allPss = New-Object System.Collections.Generic.List[int]
$resumeTimes = New-Object System.Collections.Generic.List[int]
$soakPss = New-Object System.Collections.Generic.List[int]

& adb shell am force-stop $Package | Out-Null
Start-Sleep -Seconds 1
$coldMs = Launch (Join-Path $launchDir 'cold.txt')
if ($coldMs -lt 0) {
    $failures.Add('cold_launch_missing')
}
elseif ($coldMs -gt $MaxColdMs) {
    $failures.Add("cold_launch_ms=$coldMs")
}
if (-not (WaitPid 60)) {
    $failures.Add('cold_launch_pid_missing')
}
Start-Sleep -Seconds 3
$pss = Mem 'cold' $memDir
if ($pss -ge 0) {
    $allPss.Add($pss)
}
Capture @('shell', 'dumpsys', 'gfxinfo', $Package, 'framestats') (Join-Path $raw 'gfx-cold.txt') | Out-Null

for ($i = 1; $i -le $ResumeSamplesRequired; $i++) {
    & adb shell input keyevent KEYCODE_HOME | Out-Null
    Start-Sleep -Seconds 1
    $resumeMs = Launch (Join-Path $launchDir "resume-$i.txt")
    if ($resumeMs -ge 0) {
        $resumeTimes.Add($resumeMs)
    }
    if (-not (WaitPid 60)) {
        $failures.Add("resume_${i}_pid_missing")
    }
    Start-Sleep -Seconds 1
    $pss = Mem "resume-$i" $memDir
    if ($pss -ge 0) {
        $allPss.Add($pss)
    }
}

$resumeP95 = P95 $resumeTimes.ToArray()
if ($resumeTimes.Count -ne $ResumeSamplesRequired) {
    $failures.Add("resume_samples=$($resumeTimes.Count)")
}
if ($resumeP95 -lt 0) {
    $failures.Add('resume_launch_missing')
}
elseif ($resumeP95 -gt $MaxResumeP95Ms) {
    $failures.Add("resume_p95_ms=$resumeP95")
}

Write-Host ""
Write-Host "INITIAL MEASUREMENTS COMPLETE."
Write-Host "PLAY NORMALLY NOW for at least $SoakSeconds seconds."
Write-Host "Memory will be sampled every 5 seconds."
Write-Host ""

$soakStart = [DateTimeOffset]::Now
$sample = 0
while (([DateTimeOffset]::Now - $soakStart).TotalSeconds -lt $SoakSeconds) {
    Start-Sleep -Seconds 5
    $sample++

    $pidText = ((AdbText @('shell', 'pidof', $Package)).Trim())
    if (-not $pidText) {
        $failures.Add("process_missing_during_soak_sample=$sample")
        break
    }

    $pss = Mem "soak-$sample" $memDir
    if ($pss -ge 0) {
        $allPss.Add($pss)
        $soakPss.Add($pss)
    }

    $cpu = AdbText @('shell', 'dumpsys', 'cpuinfo')
    $cpuLines = @($cpu -split "`r?`n" | Where-Object { $_ -like "*$Package*" })
    if ($cpuLines.Count -gt 0) {
        Add-Content -LiteralPath (Join-Path $raw 'cpu-soak.txt') -Value ($cpuLines -join "`r`n") -Encoding UTF8
    }

    if (($sample % 12) -eq 0) {
        $elapsed = [int]([DateTimeOffset]::Now - $soakStart).TotalSeconds
        Write-Host ("Soak: {0} / {1} s" -f $elapsed, $SoakSeconds)
    }
}

$soakEnd = [DateTimeOffset]::Now
$actualSoak = [int]($soakEnd - $soakStart).TotalSeconds
if ($actualSoak -lt $MinSoak) {
    $failures.Add("soak_seconds=$actualSoak")
}

Capture @('shell', 'dumpsys', 'gfxinfo', $Package, 'framestats') (Join-Path $raw 'gfx-after.txt') | Out-Null
$batteryAfter = Capture @('shell', 'dumpsys', 'battery') (Join-Path $raw 'battery-after.txt')
Capture @('shell', 'dumpsys', 'batterystats', $Package) (Join-Path $raw 'batterystats.txt') | Out-Null
$thermalAfter = Capture @('shell', 'dumpsys', 'thermalservice') (Join-Path $raw 'thermal-after.txt')
Capture @('shell', 'dumpsys', 'cpuinfo') (Join-Path $raw 'cpu-after.txt') | Out-Null
$logcat = Capture @('logcat', '-d') (Join-Path $raw 'logcat.txt')

$maxPss = -1
if ($allPss.Count -gt 0) {
    $maxPss = [int](($allPss | Measure-Object -Maximum).Maximum)
}
if ($maxPss -lt 0) {
    $failures.Add('pss_missing')
}
elseif ($maxPss -gt $MaxPssKb) {
    $failures.Add("max_pss_kb=$maxPss")
}

$drift = 0
if ($soakPss.Count -ge 2) {
    $drift = [int]($soakPss[$soakPss.Count - 1] - $soakPss[0])
}
else {
    $failures.Add("soak_samples=$($soakPss.Count)")
}
if ($drift -gt $MaxPssDriftKb) {
    $failures.Add("soak_pss_drift_kb=$drift")
}

$escapedPackage = [regex]::Escape($Package)
$crashCount = 0
if ($logcat -match "(?is)FATAL EXCEPTION.{0,1500}?Process:\s*$escapedPackage") {
    $crashCount++
}
if ($logcat -match "(?im)ANR in\s+$escapedPackage|am_anr.*$escapedPackage") {
    $crashCount++
}
if ($logcat -match "(?im)lowmemorykiller.*$escapedPackage|lmkd.*Kill.*$escapedPackage") {
    $crashCount++
}
if ($logcat -match '(?im)SCRIPT ERROR|Parse Error') {
    $crashCount++
}
if ($crashCount -ne 0) {
    $failures.Add("crash_or_anr_count=$crashCount")
}

Write-Host ""
Write-Host "Soak complete. Answer the four observations truthfully."
$noCrash = AskYes 'No crash or unrecoverable hang during the test?'
$noThermal = AskYes 'No thermal condition made the game unusable?'
$noVisual = AskYes 'No relevant visual corruption occurred?'
$responsive = AskYes 'Controls remained responsive?'

if (-not $noCrash) {
    $failures.Add('operator_observed_crash_or_unrecoverable_hang')
}
if (-not $noThermal) {
    $failures.Add('operator_observed_unusable_thermal_condition')
}
if (-not $noVisual) {
    $failures.Add('operator_observed_visual_corruption')
}
if (-not $responsive) {
    $failures.Add('operator_observed_unresponsive_input')
}

$rawZip = Join-Path $root 'veredas-physical-soak-raw.zip'
Compress-Archive -Path (Join-Path $raw '*') -DestinationPath $rawZip -CompressionLevel Optimal -Force
$rawSha = (Get-FileHash -LiteralPath $rawZip -Algorithm SHA256).Hash.ToLowerInvariant()

$maxPssMb = $null
if ($maxPss -ge 0) {
    $maxPssMb = [Math]::Round($maxPss / 1024.0, 2)
}

$evidence = [ordered]@{
    schema_version = 1
    roadmap_step = '11.3'
    application_id = $Package
    formal_status = 'pending_review'
    pass_recorded = $false
    candidate = [ordered]@{
        source_head = $CandidateSourceHead
        workflow_run_id = $CandidateWorkflowRunId
        apk_artifact_id = $CandidateApkArtifactId
        apk_sha256 = $apkSha
    }
    emulator_preflight = [ordered]@{
        is_physical_evidence = $false
        api_29 = [ordered]@{
            status = 'pass'
            max_pss_kb = 248616
            low_memory_kill_detected = $false
        }
        api_34 = [ordered]@{
            status = 'pass'
            max_pss_kb = 266291
            low_memory_kill_detected = $false
        }
    }
    physical_device = [ordered]@{
        source = 'physical'
        serial = $serial
        manufacturer = $manufacturer
        model = $model
        android_release = $androidRelease
        api_level = $apiLevel
        started_at = $soakStart.ToString('o')
        ended_at = $soakEnd.ToString('o')
        soak_seconds = $actualSoak
        tested_apk_sha256 = $apkSha
        operator = $Operator
        metrics = [ordered]@{
            cold_launch_ms = $coldMs
            resume_samples = $resumeTimes.Count
            resume_p95_ms = $resumeP95
            max_pss_kb = $maxPss
            max_pss_mb = $maxPssMb
            soak_samples = $soakPss.Count
            soak_pss_drift_kb = $drift
            failures = @($failures)
            crash_or_anr_count = $crashCount
        }
        raw_evidence = [ordered]@{
            battery_before_captured = (-not [string]::IsNullOrWhiteSpace($batteryBefore))
            battery_after_captured = (-not [string]::IsNullOrWhiteSpace($batteryAfter))
            thermal_before_captured = (-not [string]::IsNullOrWhiteSpace($thermalBefore))
            thermal_after_captured = (-not [string]::IsNullOrWhiteSpace($thermalAfter))
            logcat_captured = (-not [string]::IsNullOrWhiteSpace($logcat))
            archive_filename = [IO.Path]::GetFileName($rawZip)
            archive_sha256 = $rawSha
        }
        operator_observations = [ordered]@{
            no_crash = $noCrash
            no_unusable_thermal_condition = $noThermal
            no_visual_corruption = $noVisual
            input_remained_responsive = $responsive
        }
    }
}

$evidencePath = Join-Path $root 'physical_device_evidence.json'
$json = $evidence | ConvertTo-Json -Depth 10
[IO.File]::WriteAllText($evidencePath, $json + "`r`n", (New-Object Text.UTF8Encoding($false)))

Write-Host ""
Write-Host "============================================================"
if ($failures.Count -eq 0) {
    Write-Host 'PHYSICAL COLLECTION 11.3 COMPLETED WITHOUT LOCAL FAILURES'
}
else {
    Write-Warning ("COLLECTION HAS FAILURES: " + ($failures -join ', '))
}
Write-Host "Cold=$coldMs ms | resume p95=$resumeP95 ms | max PSS=$maxPss KB | soak=$actualSoak s | drift=$drift KB | crash/ANR/LMK=$crashCount"
Write-Host "Send these two files to ChatGPT:"
Write-Host "  $evidencePath"
Write-Host "  $rawZip"
Write-Host "Raw ZIP SHA-256: $rawSha"
Write-Host "============================================================"
