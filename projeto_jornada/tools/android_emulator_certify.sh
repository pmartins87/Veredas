#!/bin/sh
set -eu

PACKAGE="$1"
APK="$2"
API_LEVEL="$3"
EXPECTED_SEED=881001
EXPECTED_SCHEMA=3
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
  adb shell run-as "$PACKAGE" ls -la files > "$DIAG_ROOT/app-files.txt" 2>&1 || true
  adb shell run-as "$PACKAGE" cat files/android_ci_ready > "$DIAG_ROOT/ready-final.txt" 2>&1 || true
  exit "$status"
}
trap capture_on_exit 0

wait_for_pid() {
  limit="$1"
  i=0
  while [ "$i" -lt "$limit" ]; do
    pid=$(adb shell pidof "$PACKAGE" 2>/dev/null | tr -d '\r' || true)
    if [ -n "$pid" ]; then
      printf 'pid=%s\n' "$pid"
      return 0
    fi
    i=$((i + 1))
    sleep 1
  done
  return 1
}

file_exists() {
  relative_path="$1"
  adb shell run-as "$PACKAGE" ls -l "$relative_path" >/dev/null 2>&1
}

wait_for_file() {
  relative_path="$1"
  limit="$2"
  i=0
  while [ "$i" -lt "$limit" ]; do
    if file_exists "$relative_path"; then
      return 0
    fi
    i=$((i + 1))
    sleep 1
  done
  return 1
}

wait_for_ready() {
  expected_stage="$1"
  limit="$2"
  i=0
  while [ "$i" -lt "$limit" ]; do
    ready=$(adb shell run-as "$PACKAGE" cat files/android_ci_ready 2>/dev/null | tr -d '\r' || true)
    case "$ready" in
      "$expected_stage|seed=$EXPECTED_SEED|schema=$EXPECTED_SCHEMA")
        printf '%s\n' "$ready"
        return 0
        ;;
    esac
    i=$((i + 1))
    sleep 1
  done
  return 1
}

validate_save() {
  save_path="$1"
  label="$2"
  python - "$save_path" "$EXPECTED_SEED" "$EXPECTED_SCHEMA" "$label" <<'PY'
import json, sys
path, expected_seed, expected_schema, label = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), sys.argv[4]
data = json.load(open(path, encoding='utf-8'))
run = data['game']['run']
profile = data['game']['profile']
assert run['active'] is True, run
assert int(run['seed']) == expected_seed, run.get('seed')
assert run['flags']['ci.android_autostart'] is True, run.get('flags')
assert run['mode'] == 'story', run.get('mode')
assert int(profile['profile_schema_version']) == expected_schema, profile.get('profile_schema_version')
print(label, 'seed=', run['seed'], 'world=', run['world_id'], 'mode=', run['mode'], 'schema=', profile['profile_schema_version'])
PY
}

step '01 install APK'
adb install -r "$APK" | tee "$DIAG_ROOT/install.txt"

step '02 verify package and create CI marker'
adb shell pm path "$PACKAGE" | tee "$DIAG_ROOT/package-path.txt"
adb shell run-as "$PACKAGE" mkdir -p files
adb shell run-as "$PACKAGE" rm -f files/android_ci_ready files/veredas_save.json
adb shell run-as "$PACKAGE" touch files/android_ci_autostart
adb shell run-as "$PACKAGE" ls -l files/android_ci_autostart | tee "$DIAG_ROOT/marker.txt"

step '03 first launch and wait for application readiness'
adb logcat -c
adb shell monkey -p "$PACKAGE" -c android.intent.category.LAUNCHER 1 | tee "$DIAG_ROOT/launch-1.txt"
wait_for_pid 60 | tee "$DIAG_ROOT/pid-1.txt"
wait_for_ready started 90 | tee "$DIAG_ROOT/ready-started.txt"
wait_for_file files/veredas_save.json 30
adb shell run-as "$PACKAGE" ls -l files/veredas_save.json | tee "$DIAG_ROOT/save-initial-stat.txt"
adb exec-out run-as "$PACKAGE" cat files/veredas_save.json > "$DIAG_ROOT/save-initial.json"
validate_save "$DIAG_ROOT/save-initial.json" 'SAVE_INITIAL'

step '04 prove pause autosave by deleting disk save and requiring recreation'
adb shell run-as "$PACKAGE" rm -f files/veredas_save.json
if file_exists files/veredas_save.json; then
  echo 'Could not remove pre-pause save'
  exit 1
fi
adb shell input keyevent KEYCODE_HOME
wait_for_file files/veredas_save.json 45
adb shell run-as "$PACKAGE" ls -l files/veredas_save.json | tee "$DIAG_ROOT/save-pause-stat.txt"
adb exec-out run-as "$PACKAGE" cat files/veredas_save.json > "$DIAG_ROOT/save-before.json"
validate_save "$DIAG_ROOT/save-before.json" 'SAVE_AFTER_PAUSE'

step '05 force-stop and relaunch the persisted active journey'
adb shell run-as "$PACKAGE" rm -f files/android_ci_ready
adb shell am force-stop "$PACKAGE"
sleep 2
adb shell monkey -p "$PACKAGE" -c android.intent.category.LAUNCHER 1 | tee "$DIAG_ROOT/launch-2.txt"
wait_for_pid 60 | tee "$DIAG_ROOT/pid-2.txt"
wait_for_ready resumed 90 | tee "$DIAG_ROOT/ready-resumed.txt"

step '06 prove resumed in-memory journey can autosave again'
adb shell run-as "$PACKAGE" rm -f files/veredas_save.json
if file_exists files/veredas_save.json; then
  echo 'Could not remove post-resume save'
  exit 1
fi
adb shell input keyevent KEYCODE_HOME
wait_for_file files/veredas_save.json 45
adb shell run-as "$PACKAGE" ls -l files/veredas_save.json | tee "$DIAG_ROOT/save-resume-stat.txt"
adb exec-out run-as "$PACKAGE" cat files/veredas_save.json > "$DIAG_ROOT/save-after.json"
validate_save "$DIAG_ROOT/save-after.json" 'SAVE_AFTER_RELAUNCH_PAUSE'
python - "$DIAG_ROOT/save-before.json" "$DIAG_ROOT/save-after.json" <<'PY'
import json, sys
before = json.load(open(sys.argv[1], encoding='utf-8'))['game']
after = json.load(open(sys.argv[2], encoding='utf-8'))['game']
assert int(before['run']['seed']) == int(after['run']['seed']) == 881001
assert int(before['profile']['profile_schema_version']) == int(after['profile']['profile_schema_version']) == 3
assert before['run']['character_id'] == after['run']['character_id']
assert before['run']['world_id'] == after['run']['world_id']
print('PERSISTENCE_MATCH seed=881001 schema=3 character=', after['run']['character_id'], 'world=', after['run']['world_id'])
PY

step '07 inspect runtime logcat'
adb logcat -d > "$DIAG_ROOT/logcat-final.txt"
if grep -E 'SCRIPT ERROR|Parse Error|FATAL EXCEPTION.*com\.veredasdatrama\.preview' "$DIAG_ROOT/logcat-final.txt"; then
  echo 'Runtime error found in Android logcat'
  exit 1
fi

step "ANDROID_EMULATOR_CERTIFICATION PASS: API ${API_LEVEL} seed ${EXPECTED_SEED} schema ${EXPECTED_SCHEMA}"
