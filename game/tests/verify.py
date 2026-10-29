"""Run checks against a disposable project/profile, never the player's real save.

Usage: python game/tests/verify.py --engine /path/to/godot.exe [--visual]
"""

import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--engine", required=True, type=Path)
parser.add_argument("--visual", action="store_true")
parser.add_argument("--gameplay-only", action="store_true", help="Only rerun the composed scene after import")
parser.add_argument("--camera-only", action="store_true", help="Only camera math, boot and composed scene checks")
options = parser.parse_args()
source = Path(__file__).resolve().parents[2]
scratch = source.parent / ".verification" / "project"
scratch.mkdir(parents=True, exist_ok=True)
for folder in ("assets", "common", "core", "data", "game", "systems", "ui", "tests"):
    shutil.copytree(source / folder, scratch / folder, dirs_exist_ok=True,
                    ignore=shutil.ignore_patterns("__pycache__"))
for file_name in ("project.godot", "main.tscn"):
    shutil.copy2(source / file_name, scratch / file_name)
(scratch / "screenshots").mkdir(exist_ok=True)
(scratch / "override.cfg").write_text(
    '[application]\nconfig/name="IdleGameGodot_Codex_Verification"\n'
    'config/use_custom_user_dir=true\n'
    'config/custom_user_dir_name="IdleGameGodot_Codex_Verification"\n', encoding="utf-8")
results = []
environment = os.environ.copy()
if os.name == "nt":
    for variable, directory in (("APPDATA", "appdata"), ("LOCALAPPDATA", "localappdata")):
        isolated = scratch.parent / directory
        isolated.mkdir(exist_ok=True)
        environment[variable] = str(isolated)


def run(name, arguments, timeout=40):
    command = [str(options.engine), "--path", str(scratch), *arguments]
    started = time.monotonic()
    try:
        result = subprocess.run(command, capture_output=True, text=True,
                                encoding="utf-8", errors="replace", timeout=timeout,
                                env=environment,
                                creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
        output = result.stdout + result.stderr
        # GDScript parse/runtime failures can still leave the engine with exit 0.
        errors = re.findall(r"(?:SCRIPT ERROR:|Parse Error:|FAILED:|BASARISIZ:|ERROR:).*", output)
        if name == "save_service_test":
            expected_errors = ("ERROR: SaveService: sonlu olmayan sayi", "ERROR: SaveService: 'yanlis'")
            errors = [line for line in errors if not line.startswith(expected_errors)]
        passed = result.returncode == 0 and not errors
    except subprocess.TimeoutExpired as error:
        output = str(error)
        errors = ["Timed out"]
        passed = False
    (scratch.parent / (name + ".log")).write_text(output, encoding="utf-8")
    results.append({"name": name, "passed": passed, "seconds": round(time.monotonic() - started, 2), "errors": errors})
    print(("PASS " if passed else "FAIL ") + name, flush=True)
    if not passed:
        print("\n".join(errors) or output[-2500:], flush=True)
    return passed


if run("import", ["--headless", "--editor", "--import", "--quit"]) and not (options.gameplay_only or options.camera_only):
    for test in (
        "tests/big_number_test.gd", "tests/game_data_test.gd",
        "systems/upgrades/tests/upgrade_system_test.gd",
        "systems/upgrades/tests/auto_clicker_test.gd",
        "systems/save/tests/save_service_test.gd",
        "systems/save/tests/offline_progress_test.gd",
        "game/tests/orbit_math_test.gd", "game/tests/orbit_manager_test.gd",
        "game/tests/orbiter_visual_data_test.gd",
        "game/tests/orbit_camera_test.gd",
    ):
        run(Path(test).stem, ["--headless", "--script", "res://" + test])
    for test in ("game_state", "economy", "shop_panel", "save_integration"):
        run(test, ["--headless", "res://tests/runner.tscn", "--", "res://tests/" + test + "_test.gd"])
if results[0]["passed"]:
    if options.camera_only:
        run("orbit_camera_test", ["--headless", "--script", "res://game/tests/orbit_camera_test.gd"])
    run("boot", ["--headless", "--quit-after", "10"])
    args = [] if options.visual else ["--headless"]
    run("gameplay", [*args, "--resolution", "1920x1080", "res://tests/runner.tscn", "--", "res://game/tests/gameplay_integration_test.gd"])

(scratch.parent / "results.json").write_text(json.dumps(results, indent=2), encoding="utf-8")
failed = sum(not result["passed"] for result in results)
print(f"{len(results) - failed}/{len(results)} suites passed. Logs: {scratch.parent}", flush=True)
sys.exit(1 if failed else 0)
