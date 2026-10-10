#!/usr/bin/env python3
"""Run the real shared UI against an explicitly owned local identity fixture."""
import argparse
import json
import os
import re
from pathlib import Path
import signal
import shutil
import subprocess
from urllib.parse import urlparse
from integration_runner import integration_runner
from contextlib import ExitStack

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--fixture", type=Path, required=True)
parser.add_argument("--app", type=Path, default=Path(__file__).resolve().parents[1])
parser.add_argument("--device", default="linux")
parser.add_argument("--cold-restart", action="store_true",
                    help="Verify encrypted persistence across two Android app processes")
args = parser.parse_args()
app = args.app.resolve()
app_id = None
if args.cold_restart:
    if not args.device.startswith("emulator-"):
        raise SystemExit("Cold-process acceptance requires an explicitly owned emulator")
    gradle = (app / "android/app/build.gradle.kts").read_text()
    match = re.search(r'applicationId = "(ai[.]nddev[.]nds[.][a-zA-Z0-9_.]+)"', gradle)
    if not match:
        raise SystemExit("Expected an NDS-owned Android application id")
    app_id = match.group(1)
    installed = subprocess.run(["adb", "-s", args.device, "shell", "pm", "path", app_id],
                               capture_output=True, timeout=10)
    if installed.stdout.strip():
        raise SystemExit("Cold acceptance requires an emulator without an existing NDS app")
fixture = json.loads(args.fixture.read_text())
for key in ["base_url", "mailpit_url"]:
    parsed = urlparse(fixture[key])
    if parsed.scheme != "http" or parsed.hostname != "127.0.0.1":
        raise SystemExit("Only the isolated loopback fixture is accepted")
if fixture.get("status") != "running":
    raise SystemExit("Fixture is not running")
source = Path(__file__).resolve().parents[1] / "packages/nds_ui/integration_test/identity_flow_test.dart"
target = app / "integration_test/identity_acceptance_generated_test.dart"
if target.exists():
    raise SystemExit("Refuse to overwrite existing generated test target")
target.parent.mkdir(exist_ok=True)
ports = [str(urlparse(fixture[key]).port) for key in ["base_url", "mailpit_url"]]
log = args.fixture.parent / ("flutter-" + args.device + ".log")
runner = ExitStack()
try:
    runner.enter_context(integration_runner(app, development_http=True))
    shutil.copyfile(source, target)
    if args.device.startswith("emulator-"):
        for port in ports:
            subprocess.run(["adb", "-s", args.device, "reverse", "tcp:" + port, "tcp:" + port], check=True, timeout=10)
    command = ["flutter", "test", str(target), "-d", args.device, "--timeout=3m", "--no-pub",
        "--dart-define=NDS_TEST_SERVER=" + fixture["base_url"],
        "--dart-define=NDS_TEST_MAILPIT=" + fixture["mailpit_url"],
        "--dart-define=NDS_TEST_OWNER=" + fixture["owner_email"]]
    environment = os.environ.copy()
    environment["CARGO_BUILD_JOBS"] = "4"
    status = 0
    for phase in (["persist", "restore"] if args.cold_restart else ["complete"]):
        phase_log = log.with_stem(log.stem + "-" + phase) if args.cold_restart else log
        with phase_log.open("w") as output:
            phase_command = command + ["--dart-define=NDS_TEST_PHASE=" + phase]
            if phase == "persist":
                phase_command.append("--no-uninstall")
            process = subprocess.Popen(phase_command,
                cwd=app, env=environment, stdout=output,
                stderr=subprocess.STDOUT, start_new_session=True)
            try:
                status = process.wait(timeout=900)
            except (subprocess.TimeoutExpired, KeyboardInterrupt):
                os.killpg(process.pid, signal.SIGTERM)
                try:
                    process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    os.killpg(process.pid, signal.SIGKILL)
                    process.wait()
                raise
        print(f"Actual identity UI acceptance phase={phase} exit={status}; private log: {phase_log}")
        if status:
            break
        if app_id is not None:
            subprocess.run(["adb", "-s", args.device, "shell", "am", "force-stop", app_id],
                           check=True, timeout=10)
            alive = subprocess.run(["adb", "-s", args.device, "shell", "pidof", app_id],
                                   capture_output=True, timeout=10)
            if alive.returncode != 1 or alive.stdout.strip():
                raise SystemExit("Owned Android application did not stop between phases")
    raise SystemExit(status)
finally:
    target.unlink(missing_ok=True)
    try:
        runner.close()
    finally:
        if app_id is not None:
            subprocess.run(["adb", "-s", args.device, "uninstall", app_id],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=15)
        if args.device.startswith("emulator-"):
            for port in ports:
                subprocess.run(["adb", "-s", args.device, "reverse", "--remove", "tcp:" + port],
                    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=10)
