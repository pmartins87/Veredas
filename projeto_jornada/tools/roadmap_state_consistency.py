#!/usr/bin/env python3
from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
ROADMAP = ROOT / "ROADMAP_STATE.md"
PROJECT = ROOT / "PROJECT_STATE.json"
LOCALE_MANIFEST = ROOT / "localization" / "manifest.json"
QA_118 = ROOT / "QA_11_8_COMPLETION.json"

STATUS_RE = re.compile(r"^- ((?:11|12)\.\d+) (✅|🟡|⏳) ", re.MULTILINE)
COUNT_RE = re.compile(r"\*\*(\d+)/130 passos concluídos")

PHASE12_STATE_FILES = {
    "12.1": ROOT / "RELEASE_12_1_NAME_STATE.json",
    "12.2": ROOT / "RELEASE_12_2_STATE.json",
    "12.3": ROOT / "RELEASE_12_3_STATE.json",
    "12.4": ROOT / "RELEASE_12_4_STATE.json",
    "12.5": ROOT / "RELEASE_12_5_STATE.json",
    "12.6": ROOT / "RELEASE_12_6_STATE.json",
    "12.7": ROOT / "RELEASE_12_7_STATE.json",
    "12.8": ROOT / "RELEASE_12_8_STATE.json",
    "12.9": ROOT / "RELEASE_12_9_STATE.json",
    "12.10": ROOT / "RELEASE_12_10_STATE.json",
}


def read_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise RuntimeError(f"expected JSON object: {path}")
    return value


def status_class(value: str) -> str:
    if value == "certified":
        return "certified"
    if value.startswith("in_progress"):
        return "in_progress"
    if value == "pending":
        return "pending"
    return "unknown"


def compare_phase(
    errors: list[str],
    phase: str,
    roadmap_status: dict[str, str],
    project: dict[str, Any],
) -> None:
    key = f"phase{phase}"
    raw = project.get(key, {})
    if not isinstance(raw, dict):
        errors.append(f"PROJECT_STATE {key} must be an object")
        raw = {}
    for index in range(1, 11):
        step = f"{phase}.{index}"
        roadmap_value = roadmap_status.get(step)
        project_value = status_class(str(raw.get(step, "")))
        if roadmap_value is None:
            errors.append(f"ROADMAP_STATE status missing for {step}")
            continue
        if project_value == "unknown":
            errors.append(f"PROJECT_STATE status invalid/missing for {step}")
            continue
        if roadmap_value != project_value:
            errors.append(
                f"phase{phase} status mismatch {step}: roadmap={roadmap_value} project={project_value}"
            )


def compare_phase12_state_files(
    errors: list[str],
    roadmap_status: dict[str, str],
) -> None:
    for step, path in PHASE12_STATE_FILES.items():
        if not path.exists():
            errors.append(f"phase12 formal state file missing for {step}: {path.name}")
            continue

        state = read_json(path)
        if state.get("roadmap_step") != step:
            errors.append(
                f"phase12 state roadmap_step mismatch in {path.name}: expected={step!r} got={state.get('roadmap_step')!r}"
            )

        file_status = status_class(str(state.get("formal_status", "")))
        roadmap_value = roadmap_status.get(step)
        if file_status == "unknown":
            errors.append(f"phase12 formal_status invalid/missing in {path.name}")
        elif roadmap_value is not None and file_status != roadmap_value:
            errors.append(
                f"phase12 state mismatch {step}: roadmap={roadmap_value} file={file_status} ({path.name})"
            )

        pass_recorded = state.get("pass_recorded")
        if pass_recorded not in (True, False):
            errors.append(f"phase12 pass_recorded must be boolean in {path.name}")
        elif file_status == "certified" and pass_recorded is not True:
            errors.append(f"phase12 {step} is certified but pass_recorded is not true in {path.name}")
        elif file_status != "certified" and pass_recorded is True:
            errors.append(f"phase12 {step} records PASS while formal_status={file_status} in {path.name}")


def main() -> int:
    roadmap_text = ROADMAP.read_text(encoding="utf-8")
    project = read_json(PROJECT)
    locale_manifest = read_json(LOCALE_MANIFEST)
    errors: list[str] = []

    count_match = COUNT_RE.search(roadmap_text)
    if not count_match:
        errors.append("ROADMAP_STATE formal completion count not found")
    else:
        roadmap_count = int(count_match.group(1))
        project_count = int(project.get("completed_steps", -1))
        if roadmap_count != project_count:
            errors.append(
                f"completion count mismatch: roadmap={roadmap_count} project={project_count}"
            )

    roadmap_status = {
        step: {"✅": "certified", "🟡": "in_progress", "⏳": "pending"}[symbol]
        for step, symbol in STATUS_RE.findall(roadmap_text)
    }
    compare_phase(errors, "11", roadmap_status, project)
    compare_phase(errors, "12", roadmap_status, project)
    compare_phase12_state_files(errors, roadmap_status)

    project_phase11 = project.get("phase11", {})
    if not isinstance(project_phase11, dict):
        project_phase11 = {}

    manifest_launch = [str(value) for value in locale_manifest.get("launch_locales", [])]
    launch_scope = project.get("launch_scope", {})
    project_launch = (
        [str(value) for value in launch_scope.get("launch_locales", [])]
        if isinstance(launch_scope, dict)
        else []
    )
    if manifest_launch != project_launch:
        errors.append(
            f"launch locale mismatch: manifest={manifest_launch} project={project_launch}"
        )
    if locale_manifest.get("source_locale") != (
        launch_scope.get("source_locale") if isinstance(launch_scope, dict) else None
    ):
        errors.append("source locale mismatch between manifest and PROJECT_STATE")
    if locale_manifest.get("fallback_locale") != (
        launch_scope.get("fallback_locale") if isinstance(launch_scope, dict) else None
    ):
        errors.append("fallback locale mismatch between manifest and PROJECT_STATE")

    if status_class(str(project_phase11.get("11.8", ""))) == "certified":
        if not QA_118.exists():
            errors.append("11.8 certified but QA_11_8_COMPLETION.json is missing")
        else:
            qa118 = read_json(QA_118)
            if qa118.get("roadmap_step") != "11.8" or qa118.get("status") != "pass":
                errors.append("QA_11_8_COMPLETION.json does not contain a valid 11.8 PASS")

    if project.get("source_of_truth") != "ROADMAP_STATE.md":
        errors.append("PROJECT_STATE must identify ROADMAP_STATE.md as source_of_truth")
    if int(project.get("roadmap_total_steps", -1)) != 130:
        errors.append("PROJECT_STATE roadmap_total_steps must be 130")

    if errors:
        print(f"ROADMAP_STATE_CONSISTENCY FAIL: {len(errors)} issue(s)")
        for error in errors:
            print("ERROR:", error)
        return 1

    print(
        "ROADMAP_STATE_CONSISTENCY PASS: completed=%d/130 phase11=10 phase12=10 phase12_state_files=%d launch_locales=%s"
        % (int(project["completed_steps"]), len(PHASE12_STATE_FILES), ",".join(manifest_launch))
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
