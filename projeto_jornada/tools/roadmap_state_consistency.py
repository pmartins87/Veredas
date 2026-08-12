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

STATUS_RE = re.compile(r"^- (11\.\d+) (✅|🟡|⏳) ", re.MULTILINE)
COUNT_RE = re.compile(r"\*\*(\d+)/130 passos concluídos")


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
    project_phase11 = project.get("phase11", {})
    if not isinstance(project_phase11, dict):
        errors.append("PROJECT_STATE phase11 must be an object")
        project_phase11 = {}

    expected_steps = [f"11.{index}" for index in range(1, 11)]
    for step in expected_steps:
        roadmap_value = roadmap_status.get(step)
        project_value = status_class(str(project_phase11.get(step, "")))
        if roadmap_value is None:
            errors.append(f"ROADMAP_STATE status missing for {step}")
            continue
        if project_value == "unknown":
            errors.append(f"PROJECT_STATE status invalid/missing for {step}")
            continue
        if roadmap_value != project_value:
            errors.append(
                f"phase11 status mismatch {step}: roadmap={roadmap_value} project={project_value}"
            )

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

    if errors:
        print(f"ROADMAP_STATE_CONSISTENCY FAIL: {len(errors)} issue(s)")
        for error in errors:
            print("ERROR:", error)
        return 1

    print(
        "ROADMAP_STATE_CONSISTENCY PASS: completed=%d/130 phase11=10 launch_locales=%s"
        % (int(project["completed_steps"]), ",".join(manifest_launch))
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
