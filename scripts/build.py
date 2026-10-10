#!/usr/bin/env python3
"""Build with explicit, cache-tracked native source identity; restore app config."""
import argparse
import os
from pathlib import Path
import re
import signal
import shutil
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('flutter_arguments', nargs=argparse.REMAINDER)
args = parser.parse_args()
if not args.flutter_arguments:
    parser.error('a Flutter build target is required')
source = Path(__file__).resolve().parents[1]
app = Path.cwd()
spec = app / 'pubspec.yaml'
original = spec.read_bytes()
arguments = list(args.flutter_arguments)
# Apple bundle versions are numeric. Keep the candidate/build number in the
# owning pubspec instead of duplicating alpha build numbers in CI commands.
if arguments[0] in ('ios', 'macos') and not any(arg.startswith('--build-name') for arg in arguments):
    version = re.search(r'^version: (\d+\.\d+\.\d+)(?:-[0-9A-Za-z.-]+)?(?:\+\d+)?\s*$', original.decode(), re.MULTILINE)
    if version is None:
        raise SystemExit('Expected an explicit native application version')
    arguments.append('--build-name=' + version[1])
if re.search(r'^hooks:', original.decode(), re.MULTILINE):
    raise SystemExit('Refuse to replace existing hook configuration')
commit = subprocess.check_output(['git','rev-parse','HEAD'], cwd=source, text=True).strip()
if not re.fullmatch('[a-f0-9]{40}', commit):
    raise SystemExit('Native source requires a Git commit')
dirty = subprocess.check_output(['git','status','--porcelain','--untracked-files=no'], cwd=source, text=True).strip()
if dirty:
    raise SystemExit('Committed native source is required; tracked drift:\n' + '\n'.join(dirty.splitlines()[:32]))
if app != source and f'ref: {commit}' not in original.decode():
    raise SystemExit('The app must consume this exact shared native source')
print('Building native source: ' + commit, flush=True)
def interrupted(_signal, _frame):
    raise KeyboardInterrupt
handlers = {sig: signal.signal(sig, interrupted) for sig in [signal.SIGTERM, signal.SIGINT]}
try:
    spec.write_bytes(original + f'\nhooks:\n  user_defines:\n    nds_native:\n      source_commit: "{commit}"\n'.encode())
    environment = os.environ.copy()
    environment['CARGO_BUILD_JOBS'] = '4'
    executable = shutil.which('flutter')
    if executable is None:
        raise SystemExit('Flutter is unavailable')
    process = subprocess.Popen([executable,'build',*arguments],
        env=environment, start_new_session=os.name != 'nt')
    try:
        status = process.wait(timeout=1800)
    except (subprocess.TimeoutExpired, KeyboardInterrupt):
        if os.name == 'nt':
            subprocess.run(['taskkill','/PID',str(process.pid),'/T','/F'],
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=10)
        else:
            os.killpg(process.pid, signal.SIGTERM)
        try:
            process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            if os.name != 'nt': os.killpg(process.pid, signal.SIGKILL)
            else: process.kill()
            process.wait(timeout=10)
        raise
    raise SystemExit(status)
finally:
    spec.write_bytes(original)
    for sig, handler in handlers.items(): signal.signal(sig, handler)
