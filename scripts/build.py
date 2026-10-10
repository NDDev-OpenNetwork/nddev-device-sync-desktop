#!/usr/bin/env python3
"""Build with explicit, cache-tracked native source identity; restore app config."""
import argparse
import os
from pathlib import Path
import re
import signal
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
if re.search(r'^hooks:', original.decode(), re.MULTILINE):
    raise SystemExit('Refuse to replace existing hook configuration')
commit = subprocess.check_output(['git','rev-parse','HEAD'], cwd=source, text=True).strip()
if not re.fullmatch('[a-f0-9]{40}', commit):
    raise SystemExit('Native source requires a Git commit')
dirty = subprocess.check_output(['git','status','--porcelain','--untracked-files=no'], cwd=source, text=True).strip()
if dirty:
    raise SystemExit('Use flutter build directly for uncommitted development; this build requires committed native source')
if app != source and f'ref: {commit}' not in original.decode():
    raise SystemExit('The app must consume this exact shared native source')
def interrupted(_signal, _frame):
    raise KeyboardInterrupt
handlers = {sig: signal.signal(sig, interrupted) for sig in [signal.SIGTERM, signal.SIGINT]}
try:
    spec.write_bytes(original + f'\nhooks:\n  user_defines:\n    nds_native:\n      source_commit: "{commit}"\n'.encode())
    environment = os.environ.copy()
    environment['CARGO_BUILD_JOBS'] = '4'
    result = subprocess.run(['flutter','build',*args.flutter_arguments], env=environment, timeout=1800)
    raise SystemExit(result.returncode)
finally:
    spec.write_bytes(original)
    for sig, handler in handlers.items(): signal.signal(sig, handler)
