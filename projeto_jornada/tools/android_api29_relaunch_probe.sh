#!/bin/sh
set -eu

PACKAGE="$1"
APK="$2"
ROOT="${GITHUB_WORKSPACE:-.}/android-api29-relaunch-probe"
EXPECTED_SEED=881001
EXPECTED_SCHEMA=3
ATTEMPTS=3
SAMPLE_SECONDS=25
mkdir -p "$ROOT"

wait_for_ready() {
  stage="$1"
  limit="$2"
  i=0
  while [ "$i" -lt "$limit" ]; do
    ready=$(adb shell run-as "$PACKAGE" cat files/android_ci_ready 2>/dev/null | tr -d '\r' || true)
    case "$ready" in
      "$stage|seed=$EXPECTED_SEED|schema=$EXPECTED_SCHEMA") return 0 ;;
    esac
    i=$((i + 1))
    sleep 1
  done
  return 1
}

wait_for_file() {
  path="$1"
  limit="$2"
  i=0
  while [ "$i" -lt "$limit" ]; do
    if adb shell run-as "$PACKAGE" ls "$path" >/dev/null 2>&1; then return 0; fi
    i=$((i + 1)); sleep 1
  done
  return 1
}

sample_once() {
  attempt="$1"
  tick="$2"
  pid=$(adb shell pidof "$PACKAGE" 2>/dev/null | tr -d '\r' || true)
  printf '%s,%s,%s\n' "$attempt" "$tick" "${pid:-dead}" >> "$ROOT/pids.csv"
  adb shell cat /proc/meminfo > "$ROOT/system-mem-a${attempt}-t${tick}.txt" 2>&1 || true
  if [ -n "$pid" ]; then
    adb shell dumpsys meminfo "$PACKAGE" > "$ROOT/app-mem-a${attempt}-t${tick}.txt" 2>&1 || true
    adb shell cat "/proc/$pid/oom_score_adj" > "$ROOT/oom-a${attempt}-t${tick}.txt" 2>&1 || true
  fi
}

printf 'attempt,tick,pid\n' > "$ROOT/pids.csv"
adb install -r "$APK" > "$ROOT/install.txt"
adb shell pm clear "$PACKAGE" > "$ROOT/pm-clear.txt" 2>&1 || true
adb shell run-as "$PACKAGE" mkdir -p files
adb shell run-as "$PACKAGE" touch files/android_ci_autostart
adb logcat -c

# Establish the same canonical active journey/save used by the historical Android gate.
adb shell monkey -p "$PACKAGE" -c android.intent.category.LAUNCHER 1 > "$ROOT/initial-launch.txt"
if ! wait_for_ready started 90; then
  echo 'INITIAL_READY_FAIL' | tee "$ROOT/initial-result.txt"
  adb logcat -d > "$ROOT/logcat.txt" 2>&1 || true
  exit 1
fi
wait_for_file files/veredas_save.json 30
adb shell input keyevent KEYCODE_HOME
wait_for_file files/veredas_save.json 45
sleep 2

echo 'INITIAL_READY_PASS' | tee "$ROOT/initial-result.txt"

attempt=1
while [ "$attempt" -le "$ATTEMPTS" ]; do
  adb shell run-as "$PACKAGE" rm -f files/android_ci_ready || true
  adb shell am force-stop "$PACKAGE"
  sleep 2
  adb shell monkey -p "$PACKAGE" -c android.intent.category.LAUNCHER 1 > "$ROOT/launch-${attempt}.txt"
  started_at=$(date +%s)
  ready_tick=-1
  death_tick=-1
  tick=0
  while [ "$tick" -le "$SAMPLE_SECONDS" ]; do
    sample_once "$attempt" "$tick"
    ready=$(adb shell run-as "$PACKAGE" cat files/android_ci_ready 2>/dev/null | tr -d '\r' || true)
    if [ "$ready_tick" -lt 0 ] && [ "$ready" = "resumed|seed=$EXPECTED_SEED|schema=$EXPECTED_SCHEMA" ]; then
      ready_tick="$tick"
    fi
    pid=$(adb shell pidof "$PACKAGE" 2>/dev/null | tr -d '\r' || true)
    if [ "$death_tick" -lt 0 ] && [ -z "$pid" ]; then
      death_tick="$tick"
    fi
    tick=$((tick + 1))
    sleep 1
  done
  final_pid=$(adb shell pidof "$PACKAGE" 2>/dev/null | tr -d '\r' || true)
  elapsed=$(( $(date +%s) - started_at ))
  printf 'attempt=%s ready_tick=%s death_tick=%s final_pid=%s elapsed=%s\n' \
    "$attempt" "$ready_tick" "$death_tick" "${final_pid:-dead}" "$elapsed" | tee "$ROOT/result-${attempt}.txt"
  if [ -n "$final_pid" ]; then
    adb shell input keyevent KEYCODE_HOME || true
    sleep 2
  fi
  attempt=$((attempt + 1))
done

adb logcat -d > "$ROOT/logcat.txt" 2>&1 || true
adb shell dumpsys activity processes > "$ROOT/activity-processes.txt" 2>&1 || true
adb shell dumpsys meminfo > "$ROOT/system-mem-final.txt" 2>&1 || true

grep -Ei 'lowmemorykiller|lmkd|Kill .*com\.veredasdatrama\.preview|am_kill.*com\.veredasdatrama\.preview' "$ROOT/logcat.txt" > "$ROOT/lmk-lines.txt" || true

python3 - "$ROOT" <<'PY'
from __future__ import annotations
import json, pathlib, re, sys
root=pathlib.Path(sys.argv[1])

def val(text, patterns):
    for p in patterns:
        m=re.search(p,text,re.M|re.I)
        if m:
            return int(m.group(1).replace(',',''))
    return None
rows=[]
for p in sorted(root.glob('app-mem-a*-t*.txt')):
    m=re.search(r'a(\d+)-t(\d+)',p.name)
    if not m: continue
    text=p.read_text(errors='replace')
    pss=val(text,[r'TOTAL PSS:\s*([\d,]+)',r'^\s*TOTAL\s+([\d,]+)'])
    rss=val(text,[r'TOTAL RSS:\s*([\d,]+)'])
    if pss is not None:
        rows.append({'attempt':int(m.group(1)),'tick':int(m.group(2)),'pss_kb':pss,'rss_kb':rss})
results=[]
for i in range(1,4):
    text=(root/f'result-{i}.txt').read_text(errors='replace')
    mm=re.search(r'ready_tick=(-?\d+) death_tick=(-?\d+) final_pid=(\S+)',text)
    group=[r for r in rows if r['attempt']==i]
    results.append({
      'attempt':i,
      'ready_tick':int(mm.group(1)) if mm else None,
      'death_tick':int(mm.group(2)) if mm else None,
      'final_alive':bool(mm and mm.group(3)!='dead'),
      'max_pss_mb':round(max((r['pss_kb'] for r in group),default=0)/1024,2),
      'max_rss_mb':round(max((r['rss_kb'] or 0 for r in group),default=0)/1024,2),
      'samples':len(group),
    })
lmk=(root/'lmk-lines.txt').read_text(errors='replace').splitlines() if (root/'lmk-lines.txt').exists() else []
summary={'attempts':results,'lmk_line_count':len(lmk),'lmk_lines':lmk[-20:]}
(root/'summary.json').write_text(json.dumps(summary,indent=2,ensure_ascii=False)+'\n')
print(json.dumps(summary,ensure_ascii=False))
print('API29_RELAUNCH_MEMORY_PROBE COMPLETE attempts=3')
PY
