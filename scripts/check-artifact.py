#!/usr/bin/env python3
"""Reject integration entrypoints and native test plugins in a built app."""
import argparse
from pathlib import Path
import zipfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('artifact', type=Path)
args = parser.parse_args()
markers = [b'identity_acceptance_generated_test', b'local_modules_generated_test',
           b'NDS_TEST_SERVER', b'NDS_TEST_MAILPIT', b'NDS isolated archive:',
           b'IntegrationTestPlugin', b'dev/flutter/plugins/integration_test']
checked = 0

def check(name, data):
    global checked
    if any(marker in data for marker in markers):
        raise SystemExit('Test harness found in app artifact: ' + name)
    checked += 1

if args.artifact.suffix == '.apk':
    with zipfile.ZipFile(args.artifact) as archive:
        for item in archive.infolist():
            if item.filename.endswith(('.dex', 'kernel_blob.bin')):
                if item.file_size > 128 * 1024 * 1024:
                    raise SystemExit('Unexpectedly large app inspection input')
                check(item.filename, archive.read(item))
elif args.artifact.is_dir():
    for path in args.artifact.rglob('kernel_blob.bin'):
        check(str(path.relative_to(args.artifact)), path.read_bytes())
else:
    raise SystemExit('Expected an APK or app bundle directory')
if not checked:
    raise SystemExit('No expected debug app payload was found')
print(f'Checked {checked} built app payloads; integration harness absent')
