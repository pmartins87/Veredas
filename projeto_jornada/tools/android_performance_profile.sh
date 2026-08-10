#!/bin/sh
set -eu

PACKAGE="$1"
API_LEVEL="$2"
SOURCE="${3:-emulator}"
SOAK_SECONDS="${4:-60}"
ROOT="${GITHUB_WORKSPACE:-.}/android-emulator-diagnostics/api-${API_LEVEL}/performance"
mkdir -p "$ROOT/meminfo" "$ROOT/launch"

case "$SOURCE" in
  emulator|physical) ;;
  *) echo "Unknown source: $SOURCE" >&2; exit 2 ;;
esac

if [ "$SOURCE" = physical ] && [ "$SOAK_SECONDS" -lt 1800 ]; then
  echo "Physical 11.3 evidence requires at least 1800 soak seconds." >&2
  exit 2
fi

launch_cmd() {
  adb shell am start -W \
    -a android.intent.action.MAIN \
    -c android.intent.category.LAUNCHER \
    -p "$PACKAGE"
}

wait_for_pid() {
  i=0
  while [ "$i" -lt 60 ]; do
    pid=$(adb shell pidof "$PACKAGE" 2>/dev/null | tr -d '\r' || true)
    if [ -n "$pid" ]; then
      printf '%s\n' "$pid"
      return 0
    fi
    i=$((i + 1))
    sleep 1
  done
  return 1
}

capture_mem() {
  label="$1"
  adb shell dumpsys meminfo "$PACKAGE" > "$ROOT/meminfo/${label}.txt" 2>&1 || true
}

printf 'source=%s\napi_level=%s\nsoak_seconds=%s\npackage=%s\n' \
  "$SOURCE" "$API_LEVEL" "$SOAK_SECONDS" "$PACKAGE" > "$ROOT/context.txt"
adb shell getprop ro.product.manufacturer >> "$ROOT/context.txt" 2>/dev/null || true
adb shell getprop ro.product.model >> "$ROOT/context.txt" 2>/dev/null || true
adb shell getprop ro.build.version.release >> "$ROOT/context.txt" 2>/dev/null || true
adb shell dumpsys battery > "$ROOT/battery-before.txt" 2>&1 || true
adb shell dumpsys thermalservice > "$ROOT/thermal-before.txt" 2>&1 || true
adb shell dumpsys cpuinfo > "$ROOT/cpu-before.txt" 2>&1 || true

# Cold launch.
adb shell am force-stop "$PACKAGE"
sleep 1
launch_cmd | tee "$ROOT/launch/cold.txt"
wait_for_pid > "$ROOT/pid-cold.txt"
sleep 3
capture_mem cold
adb shell dumpsys gfxinfo "$PACKAGE" framestats > "$ROOT/gfx-cold.txt" 2>&1 || true

# Repeated foreground/resume launches.
i=1
while [ "$i" -le 12 ]; do
  adb shell input keyevent KEYCODE_HOME
  sleep 1
  launch_cmd > "$ROOT/launch/resume-${i}.txt"
  wait_for_pid > "$ROOT/pid-resume-${i}.txt"
  sleep 1
  capture_mem "resume-${i}"
  i=$((i + 1))
done

# Short reproducible soak for emulator; mandatory 30 min when source=physical.
elapsed=0
sample=0
while [ "$elapsed" -lt "$SOAK_SECONDS" ]; do
  sleep 5
  elapsed=$((elapsed + 5))
  sample=$((sample + 1))
  capture_mem "soak-${sample}"
  adb shell dumpsys cpuinfo | grep -F "$PACKAGE" >> "$ROOT/cpu-soak.txt" 2>/dev/null || true
done

adb shell dumpsys gfxinfo "$PACKAGE" framestats > "$ROOT/gfx-after.txt" 2>&1 || true
adb shell dumpsys battery > "$ROOT/battery-after.txt" 2>&1 || true
adb shell dumpsys batterystats "$PACKAGE" > "$ROOT/batterystats.txt" 2>&1 || true
adb shell dumpsys thermalservice > "$ROOT/thermal-after.txt" 2>&1 || true
adb shell dumpsys cpuinfo > "$ROOT/cpu-after.txt" 2>&1 || true
adb logcat -d > "$ROOT/logcat.txt" 2>&1 || true

python3 - "$ROOT" "$SOURCE" "$API_LEVEL" <<'PY'
from __future__ import annotations
import json, pathlib, re, statistics, sys
root = pathlib.Path(sys.argv[1])
source = sys.argv[2]
api = int(sys.argv[3])

def number(text, patterns):
    for pattern in patterns:
        m = re.search(pattern, text, re.M | re.I)
        if m:
            return int(m.group(1).replace(',', ''))
    return None

def launch_ms(path):
    text = path.read_text(errors='replace')
    return number(text, [r'^TotalTime:\s*(\d+)', r'^WaitTime:\s*(\d+)'])

def mem_kb(path):
    text = path.read_text(errors='replace')
    pss = number(text, [r'TOTAL PSS:\s*([\d,]+)', r'^\s*TOTAL\s+([\d,]+)'])
    rss = number(text, [r'TOTAL RSS:\s*([\d,]+)'])
    return pss, rss

def percentile(values, q):
    values = sorted(values)
    if not values: return None
    idx = round((len(values)-1)*q)
    return values[max(0, min(idx, len(values)-1))]

cold = launch_ms(root/'launch'/'cold.txt')
resumes = [v for p in sorted((root/'launch').glob('resume-*.txt')) if (v := launch_ms(p)) is not None]
mem_rows=[]
for p in sorted((root/'meminfo').glob('*.txt')):
    pss,rss=mem_kb(p)
    if pss is not None:
        mem_rows.append({'file':p.name,'pss_kb':pss,'rss_kb':rss})
pss=[r['pss_kb'] for r in mem_rows]
soak=[r for r in mem_rows if r['file'].startswith('soak-')]
soak_pss=[r['pss_kb'] for r in soak]
resume_p95=percentile(resumes,.95)
max_pss=max(pss) if pss else None
soak_drift=(soak_pss[-1]-soak_pss[0]) if len(soak_pss)>=2 else 0

fail=[]
if cold is None: fail.append('cold_launch_missing')
elif cold > 3000: fail.append(f'cold_launch_ms={cold}')
if resume_p95 is None: fail.append('resume_launch_missing')
elif resume_p95 > 1000: fail.append(f'resume_p95_ms={resume_p95}')
if max_pss is None: fail.append('pss_missing')
elif max_pss > 420*1024: fail.append(f'max_pss_kb={max_pss}')
if soak_drift > 96*1024: fail.append(f'soak_pss_drift_kb={soak_drift}')

summary={
  'source':source,'api_level':api,'cold_launch_ms':cold,
  'resume_samples':len(resumes),'resume_p95_ms':resume_p95,
  'mem_samples':len(mem_rows),'max_pss_kb':max_pss,
  'max_pss_mb':round(max_pss/1024,2) if max_pss is not None else None,
  'soak_samples':len(soak_pss),'soak_pss_drift_kb':soak_drift,
  'soak_pss_drift_mb':round(soak_drift/1024,2),
  'failures':fail,
  'thermal_and_battery_semantics':'proxy_only' if source=='emulator' else 'physical_evidence',
}
(root/'summary.json').write_text(json.dumps(summary,indent=2,ensure_ascii=False)+'\n')
print(json.dumps(summary,ensure_ascii=False))
if fail:
    print('ANDROID_PERFORMANCE_PROXY FAIL: 11.3-B source=%s api=%d failures=%s' % (source,api,','.join(fail)))
    raise SystemExit(1)
if source == 'emulator':
    print('ANDROID_PERFORMANCE_PROXY PASS: 11.3-B source=emulator api=%d' % api)
else:
    print('ANDROID_PERFORMANCE_DEVICE_EVIDENCE COMPLETE: 11.3-C source=physical api=%d' % api)
PY
