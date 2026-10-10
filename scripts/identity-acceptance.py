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
import uuid
from urllib.parse import urlparse
from integration_runner import integration_runner
from contextlib import ExitStack

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--fixture", type=Path, required=True)
parser.add_argument("--app", type=Path, default=Path(__file__).resolve().parents[1])
parser.add_argument("--device", default="linux")
parser.add_argument("--cold-restart", action="store_true",
                    help="Verify encrypted persistence across two Android app processes")
parser.add_argument("--isolated-android", action="store_true",
                    help="Use a unique test applicationId on an explicitly selected Android device")
parser.add_argument("--vault", action="store_true", help="Exercise real native vault creation and encrypted sync")
parser.add_argument("--pairing-role", choices=["owner", "recipient"])
parser.add_argument("--relay-url", help="Owned loopback relay for public invitations and encrypted grants only")
args = parser.parse_args()
app = args.app.resolve()
app_id = None
gradle_path = app / "android/app/build.gradle.kts"
original_gradle = None
temporary_gradle = None
android = args.device.startswith("emulator-") or args.isolated_android
if args.isolated_android:
    if args.device in ["linux", "macos", "windows"]:
        raise SystemExit("Select the explicit ADB device id for isolated Android acceptance")
    original_gradle = gradle_path.read_bytes()
    match = re.search(rb'applicationId = "(ai[.]nddev[.]nds[.][a-zA-Z0-9_.]+)"', original_gradle)
    if not match or len(re.findall(rb'applicationId = ', original_gradle)) != 1:
        raise SystemExit("Expected one NDS applicationId; refuse ambiguous replacement")
    app_id = "ai.nddev.nds.acceptance.t" + uuid.uuid4().hex
    temporary_gradle = original_gradle.replace(match[0], f'applicationId = "{app_id}"'.encode())
if args.cold_restart:
    if not android:
        raise SystemExit("Cold-process acceptance requires an owned emulator or isolated Android namespace")
    gradle = (app / "android/app/build.gradle.kts").read_text()
    match = re.search(r'applicationId = "(ai[.]nddev[.]nds[.][a-zA-Z0-9_.]+)"', gradle)
    if not match:
        raise SystemExit("Expected an NDS-owned Android application id")
    if app_id is None:
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
source = Path(__file__).resolve().parents[1] / "packages/nds_ui/integration_test" / (
    "vault_pairing_flow_test.dart" if args.pairing_role else "identity_flow_test.dart")
if args.pairing_role:
    relay = urlparse(args.relay_url or "")
    if relay.scheme != "http" or relay.hostname != "127.0.0.1" or relay.path not in ["", "/"]:
        raise SystemExit("Pairing acceptance requires an explicitly owned loopback relay origin")
target = app / "integration_test/identity_acceptance_generated_test.dart"
if target.exists():
    raise SystemExit("Refuse to overwrite existing generated test target")
target.parent.mkdir(exist_ok=True)
ports = [str(urlparse(fixture[key]).port) for key in ["base_url", "mailpit_url"]]
if args.pairing_role:
    ports.append(str(relay.port))
log = args.fixture.parent / ("flutter-" + args.device + ".log")
if args.pairing_role:
    log = log.with_stem(log.stem + "-pair-" + args.pairing_role)
runner = ExitStack()
try:
    if temporary_gradle is not None:
        gradle_path.write_bytes(temporary_gradle)
    runner.enter_context(integration_runner(app, development_http=True))
    shutil.copyfile(source, target)
    if android:
        for port in ports:
            subprocess.run(["adb", "-s", args.device, "reverse", "tcp:" + port, "tcp:" + port], check=True, timeout=10)
    command = ["flutter", "test", str(target), "-d", args.device,
        "--timeout=5m" if args.pairing_role else "--timeout=3m", "--no-pub",
        "--dart-define=NDS_TEST_SERVER=" + fixture["base_url"],
        "--dart-define=NDS_TEST_MAILPIT=" + fixture["mailpit_url"],
        "--dart-define=NDS_TEST_OWNER=" + fixture["owner_email"]]
    if args.vault:
        command.append("--dart-define=NDS_TEST_VAULT=true")
    if args.pairing_role:
        command.extend(["--dart-define=NDS_TEST_PAIRING_ROLE=" + args.pairing_role,
                        "--dart-define=NDS_TEST_RELAY=" + args.relay_url])
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
        if temporary_gradle is not None:
            if gradle_path.read_bytes() != temporary_gradle:
                raise RuntimeError("Android configuration changed outside acceptance; preserve it for review")
            gradle_path.write_bytes(original_gradle)
        if app_id is not None:
            subprocess.run(["adb", "-s", args.device, "uninstall", app_id],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=15)
        if android:
            for port in ports:
                subprocess.run(["adb", "-s", args.device, "reverse", "--remove", "tcp:" + port],
                    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=10)
