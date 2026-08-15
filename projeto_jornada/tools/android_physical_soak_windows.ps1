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
$MinSoak = 1800
$MaxColdMs = 3000
$ResumeSamples = 12
$MaxResumeP95Ms = 1500
$MaxPssKb = 420 * 1024
$MaxPssDriftKb = 96 * 1024

function Fail([string]$Message) { throw "11.3 PHYSICAL SOAK: $Message" }
function AdbText([string[]]$Args) { return (& adb @Args 2>&1 | Out-String) }
function SaveText([string]$Path, [string]$Text) { [IO.File]::WriteAllText($Path, $Text, (New-Object Text.UTF8Encoding($false))) }
function Capture([string[]]$Args, [string]$Path) { $text = AdbText $Args; SaveText $Path $text; return $text }
function Prop([string]$Name) { return ((AdbText @('shell','getprop',$Name)).Trim()) }

function WaitPid([int]$Seconds = 60) {
    for ($i = 0; $i -lt $Seconds; $i++) {
        $p = ((AdbText @('shell','pidof',$Package)).Trim())
        if ($p) { return $p }
        Start-Sleep -Seconds 1
    }
    return ""
}

function Launch([string]$Path) {
    $text = Capture @('shell','am','start','-W','-a','android.intent.action.MAIN','-c','android.intent.category.LAUNCHER','-p',$Package) $Path
    if ($text -match '(?mi)^TotalTime:\s*(\d+)') { return [int]$Matches[1] }
    if ($text -match '(?mi)^WaitTime:\s*(\d+)') { return [int]$Matches[1] }
    return -1
}

function Mem([string]$Label, [string]$Directory) {
    $text = Capture @('shell','dumpsys','meminfo',$Package) (Join-Path $Directory "$Label.txt")
    if ($text -match '(?mi)TOTAL PSS:\s*([\d,]+)') { return [int](($Matches[1] -replace ',', '')) }
    if ($text -match '(?mi)^\s*TOTAL\s+([\d,]+)') { return [int](($Matches[1] -replace ',', '')) }
    return -1
}

function P95([int[]]$Values) {
    if (-not $Values -or $Values.Count -eq 0) { return -1 }
    $sorted = @($Values | Sort-Object)
    $idx = [Math]::Round(($sorted.Count - 1) * 0.95)
    if ($idx -lt 0) { $idx = 0 }
    if ($idx -ge $sorted.Count) { $idx = $sorted.Count - 1 }
    return [int]$sorted[$idx]
}

function AskYes([string]$Question) {
    while ($true) {
        $a = (Read-Host "$Question [S/N]").Trim().ToUpperInvariant()
        if ($a -in @('S','SIM','Y','YES')) { return $true }
        if ($a -in @('N','NAO','NÃO','NO')) { return $false }
    }
}

if ($SoakSeconds -lt $MinSoak) { Fail "o soak deve ter pelo menos $MinSoak segundos." }
if (-not (Test-Path -LiteralPath $Apk -PathType Leaf)) { Fail "APK não encontrado: $Apk" }
if (-not (Get-Command adb -ErrorAction SilentlyContinue)) { Fail "adb não encontrado no PATH. Instale o Android Platform Tools." }

$apkPath = (Resolve-Path -LiteralPath $Apk).Path
$apkSha = (Get-FileHash -LiteralPath $apkPath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($apkSha -ne $ExpectedApkSha256) { Fail "APK incorreto. esperado=$ExpectedApkSha256 obtido=$apkSha" }

$devices = @(& adb devices | Select-Object -Skip 1 | Where-Object { $_ -match "`tdevice\s*$" })
if ($devices.Count -ne 1) { Fail "é necessário exatamente 1 aparelho autorizado via ADB; encontrados=$($devices.Count)." }
$serial = ($devices[0] -split "`t")[0].Trim()
$manufacturer = Prop 'ro.product.manufacturer'
$model = Prop 'ro.product.model'
$androidRelease = Prop 'ro.build.version.release'
$apiText = Prop 'ro.build.version.sdk'
try { $apiLevel = [int]$apiText } catch { Fail "API level inválido: $apiText" }
if ($apiLevel -lt 24) { Fail "API level $apiLevel abaixo do mínimo 24." }

$root = [IO.Path]::GetFullPath($OutputDirectory)
$raw = Join-Path $root 'raw'
$launchDir = Join-Path $raw 'launch'
$memDir = Join-Path $raw 'meminfo'
if (Test-Path $root) { Remove-Item $root -Recurse -Force }
New-Item -ItemType Directory -Force -Path $launchDir, $memDir | Out-Null
SaveText (Join-Path $raw 'context.txt') ((@(
    "serial=$serial", "manufacturer=$manufacturer", "model=$model",
    "android_release=$androidRelease", "api_level=$apiLevel", "package=$Package",
    "apk_sha256=$apkSha", "requested_soak_seconds=$SoakSeconds", "operator=$Operator"
) -join "`r`n") + "`r`n")

Write-Host ""
Write-Host "Veredas da Trama — soak físico 11.3"
Write-Host "Aparelho: $manufacturer $model | Android $androidRelease (API $apiLevel)"
Write-Host "APK SHA-256 confirmado: $apkSha"
Write-Host "O coletor fará instalação, cold launch e 12 resumes; depois jogue normalmente por 30 minutos."
Write-Host "Não desconecte o USB nem feche esta janela."
Write-Host ""

$install = Capture @('install','-r',$apkPath) (Join-Path $raw 'install.txt')
if ($LASTEXITCODE -ne 0 -or $install -notmatch '(?i)Success') { Fail "falha na instalação. Se houver conflito de assinatura, remova a instalação antiga manualmente." }
& adb logcat -c | Out-Null
$batteryBefore = Capture @('shell','dumpsys','battery') (Join-Path $raw 'battery-before.txt')
$thermalBefore = Capture @('shell','dumpsys','thermalservice') (Join-Path $raw 'thermal-before.txt')
Capture @('shell','dumpsys','cpuinfo') (Join-Path $raw 'cpu-before.txt') | Out-Null

$fail = New-Object System.Collections.Generic.List[string]
$allPss = New-Object System.Collections.Generic.List[int]
$resumes = New-Object System.Collections.Generic.List[int]
$soakPss = New-Object System.Collections.Generic.List[int]

& adb shell am force-stop $Package | Out-Null
Start-Sleep 1
$cold = Launch (Join-Path $launchDir 'cold.txt')
if ($cold -lt 0) { $fail.Add('cold_launch_missing') } elseif ($cold -gt $MaxColdMs) { $fail.Add("cold_launch_ms=$cold") }
if (-not (WaitPid 60)) { $fail.Add('cold_launch_pid_missing') }
Start-Sleep 3
$v = Mem 'cold' $memDir; if ($v -ge 0) { $allPss.Add($v) }
Capture @('shell','dumpsys','gfxinfo',$Package,'framestats') (Join-Path $raw 'gfx-cold.txt') | Out-Null

for ($i = 1; $i -le $ResumeSamples; $i++) {
    & adb shell input keyevent KEYCODE_HOME | Out-Null
    Start-Sleep 1
    $ms = Launch (Join-Path $launchDir "resume-$i.txt")
    if ($ms -ge 0) { $resumes.Add($ms) }
    if (-not (WaitPid 60)) { $fail.Add("resume_${i}_pid_missing") }
    Start-Sleep 1
    $v = Mem "resume-$i" $memDir; if ($v -ge 0) { $allPss.Add($v) }
}
$resumeP95 = P95 $resumes.ToArray()
if ($resumes.Count -ne $ResumeSamples) { $fail.Add("resume_samples=$($resumes.Count)") }
if ($resumeP95 -lt 0) { $fail.Add('resume_launch_missing') } elseif ($resumeP95 -gt $MaxResumeP95Ms) { $fail.Add("resume_p95_ms=$resumeP95") }

Write-Host ""
Write-Host "AGORA JOGUE NORMALMENTE por pelo menos $SoakSeconds segundos. Amostragem PSS: 5 s."
$soakStart = [DateTimeOffset]::Now
$sample = 0
while (([DateTimeOffset]::Now - $soakStart).TotalSeconds -lt $SoakSeconds) {
    Start-Sleep 5
    $sample++
    if (-not ((AdbText @('shell','pidof',$Package)).Trim())) { $fail.Add("process_missing_during_soak_sample=$sample"); break }
    $v = Mem "soak-$sample" $memDir
    if ($v -ge 0) { $allPss.Add($v); $soakPss.Add($v) }
    $cpu = AdbText @('shell','dumpsys','cpuinfo')
    $line = @($cpu -split "`r?`n" | Where-Object { $_ -like "*$Package*" }) -join "`r`n"
    if ($line) { Add-Content -LiteralPath (Join-Path $raw 'cpu-soak.txt') -Value $line -Encoding UTF8 }
    if (($sample % 12) -eq 0) { Write-Host ("Soak: {0} / {1} s" -f [int]([DateTimeOffset]::Now-$soakStart).TotalSeconds,$SoakSeconds) }
}
$soakEnd = [DateTimeOffset]::Now
$actualSoak = [int]($soakEnd - $soakStart).TotalSeconds
if ($actualSoak -lt $MinSoak) { $fail.Add("soak_seconds=$actualSoak") }

Capture @('shell','dumpsys','gfxinfo',$Package,'framestats') (Join-Path $raw 'gfx-after.txt') | Out-Null
$batteryAfter = Capture @('shell','dumpsys','battery') (Join-Path $raw 'battery-after.txt')
Capture @('shell','dumpsys','batterystats',$Package) (Join-Path $raw 'batterystats.txt') | Out-Null
$thermalAfter = Capture @('shell','dumpsys','thermalservice') (Join-Path $raw 'thermal-after.txt')
Capture @('shell','dumpsys','cpuinfo') (Join-Path $raw 'cpu-after.txt') | Out-Null
$logcat = Capture @('logcat','-d') (Join-Path $raw 'logcat.txt')

$maxPss = if ($allPss.Count) { [int](($allPss | Measure-Object -Maximum).Maximum) } else { -1 }
if ($maxPss -lt 0) { $fail.Add('pss_missing') } elseif ($maxPss -gt $MaxPssKb) { $fail.Add("max_pss_kb=$maxPss") }
$drift = if ($soakPss.Count -ge 2) { [int]($soakPss[$soakPss.Count-1]-$soakPss[0]) } else { 0 }
if ($soakPss.Count -lt 2) { $fail.Add("soak_samples=$($soakPss.Count)") }
if ($drift -gt $MaxPssDriftKb) { $fail.Add("soak_pss_drift_kb=$drift") }

$escaped = [regex]::Escape($Package)
$crashCount = 0
if ($logcat -match "(?is)FATAL EXCEPTION.{0,1500}?Process:\s*$escaped") { $crashCount++ }
if ($logcat -match "(?im)ANR in\s+$escaped|am_anr.*$escaped") { $crashCount++ }
if ($logcat -match "(?im)lowmemorykiller: Kill '$escaped'|lmkd.*Kill.*$escaped") { $crashCount++ }
if ($logcat -match '(?im)SCRIPT ERROR|Parse Error') { $crashCount++ }
if ($crashCount) { $fail.Add("crash_or_anr_count=$crashCount") }

Write-Host ""
Write-Host "Soak concluído. Responda às observações humanas:"
$noCrash = AskYes 'Sem crash/travamento que exigiu reinício?'
$noThermal = AskYes 'Sem condição térmica que impediu jogar?'
$noVisual = AskYes 'Sem corrupção visual relevante?'
$responsive = AskYes 'Comandos permaneceram responsivos?'
if (-not $noCrash) { $fail.Add('operator_observed_crash_or_unrecoverable_hang') }
if (-not $noThermal) { $fail.Add('operator_observed_unusable_thermal_condition') }
if (-not $noVisual) { $fail.Add('operator_observed_visual_corruption') }
if (-not $responsive) { $fail.Add('operator_observed_unresponsive_input') }

$rawZip = Join-Path $root 'veredas-physical-soak-raw.zip'
Compress-Archive -Path (Join-Path $raw '*') -DestinationPath $rawZip -CompressionLevel Optimal -Force
$rawSha = (Get-FileHash $rawZip -Algorithm SHA256).Hash.ToLowerInvariant()
$evidence = [ordered]@{
    schema_version=1; roadmap_step='11.3'; application_id=$Package; candidate_apk_sha256=$apkSha;
    physical_device=[ordered]@{
        source='physical'; serial=$serial; manufacturer=$manufacturer; model=$model; android_release=$androidRelease; api_level=$apiLevel;
        started_at=$soakStart.ToString('o'); ended_at=$soakEnd.ToString('o'); soak_seconds=$actualSoak; tested_apk_sha256=$apkSha; operator=$Operator;
        metrics=[ordered]@{ cold_launch_ms=$cold; resume_samples=$resumes.Count; resume_p95_ms=$resumeP95; max_pss_kb=$maxPss; max_pss_mb=$(if($maxPss-ge 0){[Math]::Round($maxPss/1024.0,2)}else{$null}); soak_samples=$soakPss.Count; soak_pss_drift_kb=$drift; failures=@($fail); crash_or_anr_count=$crashCount };
        raw_evidence=[ordered]@{ battery_before_captured=[bool]$batteryBefore; battery_after_captured=[bool]$batteryAfter; thermal_before_captured=[bool]$thermalBefore; thermal_after_captured=[bool]$thermalAfter; logcat_captured=[bool]$logcat; archive_filename=[IO.Path]::GetFileName($rawZip); archive_sha256=$rawSha };
        operator_observations=[ordered]@{ no_crash=$noCrash; no_unusable_thermal_condition=$noThermal; no_visual_corruption=$noVisual; input_remained_responsive=$responsive }
    }
}
$evidencePath = Join-Path $root 'physical_device_evidence.json'
$json = $evidence | ConvertTo-Json -Depth 8
[IO.File]::WriteAllText($evidencePath, $json + "`r`n", (New-Object Text.UTF8Encoding($false)))

Write-Host ""
Write-Host "============================================================"
if ($fail.Count -eq 0) { Write-Host 'COLETA FÍSICA 11.3 CONCLUÍDA SEM FALHAS LOCAIS' } else { Write-Warning ("COLETA COM FALHAS: " + ($fail -join ', ')) }
Write-Host "Cold=$cold ms | resume p95=$resumeP95 ms | max PSS=$maxPss KB | soak=$actualSoak s | drift=$drift KB | crash/ANR/LMK=$crashCount"
Write-Host "Envie ao ChatGPT estes dois arquivos:"
Write-Host "  $evidencePath"
Write-Host "  $rawZip"
Write-Host "SHA-256 do ZIP bruto: $rawSha"
Write-Host "============================================================"
