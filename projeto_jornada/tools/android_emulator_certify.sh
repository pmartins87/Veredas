#!/bin/sh
set -eu

PACKAGE="$1"
APK="$2"
API_LEVEL="$3"
EXPECTED_SEED=881001
DIAG_ROOT="${GITHUB_WORKSPACE:-.}/android-emulator-diagnostics/api-${API_LEVEL}"
mkdir -p "$DIAG_ROOT"
STEPS="$DIAG_ROOT/steps.log"

step() {
  printf '%s\n' "$1" | tee -a "$STEPS"
}

capture_on_exit() {
  status=$?
  trap - 0
  printf 'exit_status=%s\n' "$status" >> "$STEPS"
  adb logcat -d > "$DIAG_ROOT/logcat.txt" 2>&1 || true
  adb shell dumpsys activity top > "$DIAG_ROOT/activity-top.txt" 2>&1 || true
  adb shell dumpsys package "$PACKAGE" > "$DIAG_ROOT/package.txt" 2>&1 || true
  adb shell run-as "$PACKAGE" find files -maxdepth 2 -type f -ls > "$DIAG_ROOT/app-files.txt" 2>&1 || true
  exit "$status"
}
trap capture_on_exit 0

step '01 install APK'
adb install -r "$APK" | tee "$DIAG_ROOT/install.txt"

step '02 verify package and create CI marker'
adb shell pm path "$PACKAGE" | tee "$DIAG_ROOT/package-path.txt"
adb shell run-as "$PACKAGE" mkdir -p files
adb shell run-as "$PACKAGE" touch files/android_ci_autostart
adb shell run-as "$PACKAGE" ls -l files/android_ci_autostart | tee "$DIAG_ROOT/marker.txt"

step '03 first launch'
adb logcat -c
adb shell monkey -p "$PACKAGE" -c android.intent.category.LAUNCHER 1 | tee "$DIAG_ROOT/launch-1.txt"
sleep 7
PID=$(adb shell pidof "$PACKAGE" | tr -d '\r')
printf 'pid=%s\n' "$PID" | tee "$DIAG_ROOT/pid-1.txt"
test -n "$PID"

step '04 pause and verify autosave'
adb shell input keyevent KEYCODE_HOME
sleep 3
adb shell run-as "$PACKAGE" sh -c 'test -s files/veredas_save.json'
adb exec-out run-as "$PACKAGE" cat files/veredas_save.json > "$DIAG_ROOT/save-before.json"
python - "$DIAG_ROOT/save-before.json" "$EXPECTED_SEED" <<'PY'
import json, sys
path, expected = sys.argv[1], int(sys.argv[2])
data = json.load(open(path, encoding='utf-8'))
run = data['game']['run']
assert run['active'] is True, run
assert int(run['seed']) == expected, run.get('seed')
assert run['flags']['ci.android_autostart'] is True, run.get('flags')
assert run['mode'] == 'story', run.get('mode')
print('SAVE_BEFORE seed=', run['seed'], 'world=', run['world_id'], 'mode=', run['mode'])
PY
SEED_BEFORE=$(python -c "import json; print(int(json.load(open('$DIAG_ROOT/save-before.json'))['game']['run']['seed']))")

step '05 force-stop and relaunch'
adb shell am force-stop "$PACKAGE"
sleep 2
adb shell monkey -p "$PACKAGE" -c android.intent.category.LAUNCHER 1 | tee "$DIAG_ROOT/launch-2.txt"
sleep 7
PID=$(adb shell pidof "$PACKAGE" | tr -d '\r')
printf 'pid=%s\n' "$PID" | tee "$DIAG_ROOT/pid-2.txt"
test -n "$PID"

step '06 pause resumed app and verify same journey'
adb shell input keyevent KEYCODE_HOME
sleep 3
adb shell run-as "$PACKAGE" sh -c 'test -s files/veredas_save.json'
adb exec-out run-as "$PACKAGE" cat files/veredas_save.json > "$DIAG_ROOT/save-after.json"
python - "$DIAG_ROOT/save-after.json" "$EXPECTED_SEED" <<'PY'
import json, sys
path, expected = sys.argv[1], int(sys.argv[2])
data = json.load(open(path, encoding='utf-8'))
run = data['game']['run']
assert run['active'] is True, run
assert int(run['seed']) == expected, run.get('seed')
assert run['flags']['ci.android_autostart'] is True, run.get('flags')
assert run['mode'] == 'story', run.get('mode')
print('SAVE_AFTER seed=', run['seed'], 'world=', run['world_id'], 'mode=', run['mode'])
PY
SEED_AFTER=$(python -c "import json; print(int(json.load(open('$DIAG_ROOT/save-after.json'))['game']['run']['seed']))")
test "$SEED_BEFORE" = "$SEED_AFTER"

step '07 inspect runtime logcat'
adb logcat -d > "$DIAG_ROOT/logcat-final.txt"
if grep -E 'SCRIPT ERROR|Parse Error|FATAL EXCEPTION.*com\.veredasdatrama\.preview' "$DIAG_ROOT/logcat-final.txt"; then
  echo 'Runtime error found in Android logcat'
  exit 1
fi

step "ANDROID_EMULATOR_CERTIFICATION PASS: API ${API_LEVEL} seed ${SEED_AFTER}"
