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
$MinimumSoakSeconds = 1800
$MaximumColdLaunchMs = 3000
$RequiredResumeSamples = 12
$MaximumResumeP95Ms = 1500
$MaximumPssKb = 420 * 1024
$MaximumSoakPssDriftKb = 96 * 1024

function Fail([string]$Message) {
    throw "11.3 PHYSICAL SOAK: $Message"
}

function Invoke-AdbCapture {
    param(
        [string[]]$Arguments,
        [string]$Path
    )
    $text = (& adb @Arguments 2>&1 | Out-String)
    $text | Set-Content -LiteralPath $Path -Encoding UTF8
    return $text
}

function Get-DeviceProperty([string]$Name) {
    return ((& adb shell getprop $Name 2>$null | Out-String).Trim())
}

function Wait-ForPackagePid([int]$TimeoutSeconds = 60) {
    for ($i = 0; $i -lt $TimeoutSeconds; $i++) {
        $pidText = ((& adb shell pidof $Package 2>$null | Out-String).Trim())
        if ($pidText) { return $pidText }
        Start-Sleep -Seconds 1
    }
    return ""
}

function Parse-LaunchMs([string]$Text) {
    if ($Text -match '(?mi)^TotalTime:\s*(\d+)') { return [int]$Matches[1] }
    if ($Text -match '(?mi)^WaitTime:\s*(\d+)') { return [int]$Matches[1] }
    return -1
}

function Capture-Memory {
    param(
        [string]$Label,
        [string]$Directory
    )
    $path = Join-Path $Directory "$Label.txt"
    $text = Invoke-AdbCapture -Arguments @('shell','dumpsys','meminfo',$Package) -Path $path
    if ($text -match '(?mi)TOTAL PSS:\s*([\d,]+)') {
        return [int](($Matches[1] -replace ',', ''))
    }
    if ($text -match '(?mi)^\s*TOTAL\s+([\d,]+)') {
        return [int](($Matches[1] -replace ',', ''))
    }
    return -1
}

function Start-Application {
    param([string]$CapturePath)
    $text = Invoke-AdbCapture -Arguments @(
        'shell','am','start','-W',
        '-a','android.intent.action.MAIN',
        '-c','android.intent.category.LAUNCHER',
        '-p',$Package
    ) -Path $CapturePath
    return Parse-LaunchMs $text
}

function Percentile95([int[]]$Values) {
    if (-not $Values -or $Values.Count -eq 0) { return -1 }
    $sorted = @($Values | Sort-Object)
    $index = [Math]::Round(($sorted.Count - 1) * 0.95)
    if ($index -lt 0) { $index = 0 }
    if ($index -ge $sorted.Count) { $index = $sorted.Count - 1 }
    return [int]$sorted[$index]
}

if ($SoakSeconds -lt $MinimumSoakSeconds) {
    Fail "o soak físico deve ter pelo menos $MinimumSoakSeconds segundos."
}
if (-not (Test-Path -LiteralPath $Apk -PathType Leaf)) {
    Fail "APK não encontrado: $Apk"
}
if (-not (Get-Command adb -ErrorAction SilentlyContinue)) {
    Fail "adb não foi encontrado no PATH. Instale/ative o Android Platform Tools antes de executar o coletor."
}

$apkResolved = (Resolve-Path -LiteralPath $Apk).Path
$apkSha = (Get-FileHash -LiteralPath $apkResolved -Algorithm SHA256).Hash.ToLowerInvariant()
if ($apkSha -ne $ExpectedApkSha256) {
    Fail "APK SHA-256 diferente da candidata congelada. esperado=$ExpectedApkSha256 obtido=$apkSha"
}

$deviceLines = @(& adb devices | Select-Object -Skip 1 | Where-Object { $_ -match "`tdevice\s*$" })
if ($deviceLines.Count -ne 1) {
    Fail "é necessário exatamente 1 aparelho Android autorizado via ADB; encontrados=$($deviceLines.Count)."
}
$serial = ($deviceLines[0] -split "`t")[0].Trim()

$manufacturer = Get-DeviceProperty 'ro.product.manufacturer'
$model = Get-DeviceProperty 'ro.product.model'
$androidRelease = Get-DeviceProperty 'ro.build.version.release'
$apiText = Get-DeviceProperty 'ro.build.version.sdk'
if (-not [int]::TryParse($apiText, [ref]$null)) {
    Fail "não foi possível determinar o API level do aparelho: $apiText"
}
$apiLevel = [int]$apiText
if ($apiLevel -lt 24) {
    Fail "API level $apiLevel abaixo do mínimo 24."
}

$root = [IO.Path]::GetFullPath($OutputDirectory)
$raw = Join-Path $root 'raw'
$launchDir = Join-Path $raw 'launch'
$memDir = Join-Path $raw 'meminfo'
if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
New-Item -ItemType Directory -Force -Path $launchDir, $memDir | Out-Null

@(
    "serial=$serial",
    "manufacturer=$manufacturer",
    "model=$model",
    "android_release=$androidRelease",
    "api_level=$apiLevel",
    "package=$Package",
    "apk_sha256=$apkSha",
    "requested_soak_seconds=$SoakSeconds",
    "operator=$Operator"
) | Set-Content -LiteralPath (Join-Path $raw 'context.txt') -Encoding UTF8

Write-Host ""
Write-Host "Veredas da Trama — soak físico 11.3"
Write-Host "Aparelho: $manufacturer $model | Android $androidRelease (API $apiLevel)"
Write-Host "APK SHA-256 confirmado: $apkSha"
Write-Host ""
Write-Host "O script fará instalação, cold launch e 12 ciclos de resume."
Write-Host "Depois, mantenha o jogo aberto e USE-O NORMALMENTE durante os 30 minutos do soak."
Write-Host "Não desconecte o cabo USB e não feche esta janela."
Write-Host ""

$installText = Invoke-AdbCapture -Arguments @('install','-r',$apkResolved) -Path (Join-Path $raw 'install.txt')
if ($LASTEXITCODE -ne 0 -or $installText -notmatch '(?i)Success') {
    Fail "falha ao instalar o APK. Se houver conflito de assinatura com uma instalação antiga, remova-a manualmente e execute novamente."
}

& adb logcat -c | Out-Null
$batteryBefore = Invoke-AdbCapture -Arguments @('shell','dumpsys','battery') -Path (Join-Path $raw 'battery-before.txt')
$thermalBefore = Invoke-AdbCapture -Arguments @('shell','dumpsys','thermalservice') -Path (Join-Path $raw 'thermal-before.txt')
Invoke-AdbCapture -Arguments @('shell','dumpsys','cpuinfo') -Path (Join-Path $raw 'cpu-before.txt') | Out-Null

$failures = New-Object System.Collections.Generic.List[string]
$allPss = New-Object System.Collections.Generic.List[int]
$resumeTimes = New-Object System.Collections.Generic.List[int]
$soakPss = New-Object System.Collections.Generic.List[int]

& adb shell am force-stop $Package | Out-Null
Start-Sleep -Seconds 1
$coldMs = Start-Application -CapturePath (Join-Path $launchDir 'cold.txt')
if ($coldMs -lt 0) { $failures.Add('cold_launch_missing') }
elseif ($coldMs -gt $MaximumColdLaunchMs) { $failures.Add("cold_launch_ms=$coldMs") }
$pidText = Wait-ForPackagePid 60
if (-not $pidText) { $failures.Add('cold_launch_pid_missing') }
Start-Sleep -Seconds 3
$coldPss = Capture-Memory -Label 'cold' -Directory $memDir
if ($coldPss -ge 0) { $allPss.Add($coldPss) }
Invoke-AdbCapture -Arguments @('shell','dumpsys','gfxinfo',$Package,'framestats') -Path (Join-Path $raw 'gfx-cold.txt') | Out-Null

for ($i = 1; $i -le $RequiredResumeSamples; $i++) {
    & adb shell input keyevent KEYCODE_HOME | Out-Null
    Start-Sleep -Seconds 1
    $resumeMs = Start-Application -CapturePath (Join-Path $launchDir "resume-$i.txt")
    if ($resumeMs -ge 0) { $resumeTimes.Add($resumeMs) }
    $pidText = Wait-ForPackagePid 60
    if (-not $pidText) { $failures.Add("resume_${i}_pid_missing") }
    Start-Sleep -Seconds 1
    $pss = Capture-Memory -Label "resume-$i" -Directory $memDir
    if ($pss -ge 0) { $allPss.Add($pss) }
}

$resumeP95 = Percentile95 $resumeTimes.ToArray()
if ($resumeTimes.Count -ne $RequiredResumeSamples) { $failures.Add("resume_samples=$($resumeTimes.Count)") }
if ($resumeP95 -lt 0) { $failures.Add('resume_launch_missing') }
elseif ($resumeP95 -gt $MaximumResumeP95Ms) { $failures.Add("resume_p95_ms=$resumeP95") }

Write-Host ""
Write-Host "Medições iniciais concluídas."
Write-Host "A PARTIR DE AGORA: jogue normalmente e mantenha o jogo em uso por pelo menos $SoakSeconds segundos."
Write-Host "O coletor fará amostras de memória a cada 5 segundos."
Write-Host ""

$soakStarted = [DateTimeOffset]::Now
$sample = 0
while (([DateTimeOffset]::Now - $soakStarted).TotalSeconds -lt $SoakSeconds) {
    Start-Sleep -Seconds 5
    $sample++
    $pidText = ((& adb shell pidof $Package 2>$null | Out-String).Trim())
    if (-not $pidText) {
        $failures.Add("process_missing_during_soak_sample=$sample")
        break
    }
    $pss = Capture-Memory -Label "soak-$sample" -Directory $memDir
    if ($pss -ge 0) {
        $allPss.Add($pss)
        $soakPss.Add($pss)
    }
    $cpuLine = (& adb shell dumpsys cpuinfo 2>$null | Select-String -SimpleMatch $Package | ForEach-Object { $_.Line })
    if ($cpuLine) { Add-Content -LiteralPath (Join-Path $raw 'cpu-soak.txt') -Value $cpuLine -Encoding UTF8 }
    if (($sample % 12) -eq 0) {
        $elapsed = [int]([DateTimeOffset]::Now - $soakStarted).TotalSeconds
        Write-Host "Soak: $elapsed / $SoakSeconds s"
    }
}
$soakEnded = [DateTimeOffset]::Now
$actualSoakSeconds = [int]($soakEnded - $soakStarted).TotalSeconds
if ($actualSoakSeconds -lt $MinimumSoakSeconds) { $failures.Add("soak_seconds=$actualSoakSeconds") }

Invoke-AdbCapture -Arguments @('shell','dumpsys','gfxinfo',$Package,'framestats') -Path (Join-Path $raw 'gfx-after.txt') | Out-Null
$batteryAfter = Invoke-AdbCapture -Arguments @('shell','dumpsys','battery') -Path (Join-Path $raw 'battery-after.txt')
Invoke-AdbCapture -Arguments @('shell','dumpsys','batterystats',$Package) -Path (Join-Path $raw 'batterystats.txt') | Out-Null
$thermalAfter = Invoke-AdbCapture -Arguments @('shell','dumpsys','thermalservice') -Path (Join-Path $raw 'thermal-after.txt')
Invoke-AdbCapture -Arguments @('shell','dumpsys','cpuinfo') -Path (Join-Path $raw 'cpu-after.txt') | Out-Null
$logcat = Invoke-AdbCapture -Arguments @('logcat','-d') -Path (Join-Path $raw 'logcat.txt')

$maxPss = if ($allPss.Count -gt 0) { [int](($allPss | Measure-Object -Maximum).Maximum) } else { -1 }
if ($maxPss -lt 0) { $failures.Add('pss_missing') }
elseif ($maxPss -gt $MaximumPssKb) { $failures.Add("max_pss_kb=$maxPss") }

$soakPssDrift = if ($soakPss.Count -ge 2) { [int]($soakPss[$soakPss.Count - 1] - $soakPss[0]) } else { 0 }
if ($soakPss.Count -lt 2) { $failures.Add("soak_samples=$($soakPss.Count)") }
if ($soakPssDrift -gt $MaximumSoakPssDriftKb) { $failures.Add("soak_pss_drift_kb=$soakPssDrift") }

$crashOrAnrCount = 0
if ($logcat -match "(?is)FATAL EXCEPTION.*?Process:\s*$([regex]::Escape($Package))") { $crashOrAnrCount++ }
if ($logcat -match "(?im)ANR in\s+$([regex]::Escape($Package))|am_anr.*$([regex]::Escape($Package))") { $crashOrAnrCount++ }
if ($logcat -match "(?im)lowmemorykiller: Kill '$([regex]::Escape($Package))'|lmkd.*Kill.*$([regex]::Escape($Package))") { $crashOrAnrCount++ }
if ($logcat -match '(?im)SCRIPT ERROR|Parse Error') { $crashOrAnrCount++ }
if ($crashOrAnrCount -ne 0) { $failures.Add("crash_or_anr_count=$crashOrAnrCount") }

function Ask-Yes([string]$Question) {
    while ($true) {
        $answer = (Read-Host "$Question [S/N]").Trim().ToUpperInvariant()
        if ($answer -in @('S','SIM','Y','YES')) { return $true }
        if ($answer -in @('N','NAO','NÃO','NO')) { return $false }
    }
}

Write-Host ""
Write-Host "Soak concluído. Responda às quatro observações humanas:"
$noCrash = Ask-Yes 'Durante o teste, o jogo permaneceu sem crash/travamento que exigisse reinício?'
$noThermal = Ask-Yes 'O aparelho permaneceu utilizável, sem aquecimento/condição térmica que impedisse jogar?'
$noVisual = Ask-Yes 'Não houve corrupção visual relevante durante o teste?'
$responsive = Ask-Yes 'Os comandos permaneceram responsivos durante o teste?'

if (-not $noCrash) { $failures.Add('operator_observed_crash_or_unrecoverable_hang') }
if (-not $noThermal) { $failures.Add('operator_observed_unusable_thermal_condition') }
if (-not $noVisual) { $failures.Add('operator_observed_visual_corruption') }
if (-not $responsive) { $failures.Add('operator_observed_unresponsive_input') }

$rawZip = Join-Path $root 'veredas-physical-soak-raw.zip'
if (Test-Path -LiteralPath $rawZip) { Remove-Item -LiteralPath $rawZip -Force }
Compress-Archive -Path (Join-Path $raw '*') -DestinationPath $rawZip -CompressionLevel Optimal
$rawArchiveSha = (Get-FileHash -LiteralPath $rawZip -Algorithm SHA256).Hash.ToLowerInvariant()

$evidence = [ordered]@{
    schema_version = 1
    roadmap_step = '11.3'
    application_id = $Package
    candidate_apk_sha256 = $apkSha
    physical_device = [ordered]@{
        source = 'physical'
        serial = $serial
        manufacturer = $manufacturer
        model = $model
        android_release = $androidRelease
        api_level = $apiLevel
        started_at = $soakStarted.ToString('o')
        ended_at = $soakEnded.ToString('o')
        soak_seconds = $actualSoakSeconds
        tested_apk_sha256 = $apkSha
        operator = $Operator
        metrics = [ordered]@{
            cold_launch_ms = $coldMs
            resume_samples = $resumeTimes.Count
            resume_p95_ms = $resumeP95
            max_pss_kb = $maxPss
            max_pss_mb = if ($maxPss -ge 0) { [Math]::Round($maxPss / 1024.0, 2) } else { $null }
            soak_samples = $soakPss.Count
            soak_pss_drift_kb = $soakPssDrift
            failures = @($failures)
            crash_or_anr_count = $crashOrAnrCount
        }
        raw_evidence = [ordered]@{
            battery_before_captured = [bool]$batteryBefore
            battery_after_captured = [bool]$batteryAfter
            thermal_before_captured = [bool]$thermalBefore
            thermal_after_captured = [bool]$thermalAfter
            logcat_captured = [bool]$logcat
            archive_filename = [IO.Path]::GetFileName($rawZip)
            archive_sha256 = $rawArchiveSha
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
$evidence | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $evidencePath -Encoding UTF8

Write-Host ""
Write-Host "============================================================"
if ($failures.Count -eq 0) {
    Write-Host "COLETA FÍSICA 11.3 CONCLUÍDA SEM FALHAS LOCAIS"
} else {
    Write-Host "COLETA FÍSICA 11.3 CONCLUÍDA COM FALHAS: $($failures -join ', ')"
}
Write-Host "============================================================"
Write-Host "Cold launch: ${coldMs} ms"
Write-Host "Resume p95: ${resumeP95} ms ($($resumeTimes.Count) amostras)"
Write-Host "Max PSS: $maxPss KB"
Write-Host "Soak real: $actualSoakSeconds s | amostras=$($soakPss.Count) | drift=$soakPssDrift KB"
Write-Host "Crash/ANR/LMK/script errors: $crashOrAnrCount"
Write-Host ""
Write-Host "Envie estes DOIS arquivos de volta para o ChatGPT:"
Write-Host "  $evidencePath"
Write-Host "  $rawZip"
Write-Host "SHA-256 do ZIP bruto: $rawArchiveSha"
Write-Host ""
