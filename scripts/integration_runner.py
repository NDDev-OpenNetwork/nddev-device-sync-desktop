"""Own the temporary Flutter integration-test dependency and debug hook scope."""
from contextlib import contextmanager
from pathlib import Path
import signal
import subprocess

@contextmanager
def integration_runner(app: Path, *, development_http=False):
    spec, lock = app / 'pubspec.yaml', app / 'pubspec.lock'
    original, original_lock = spec.read_bytes(), lock.read_bytes()
    source = original.decode()
    if '  integration_test:' in source or 'hooks:' in source:
        raise RuntimeError('Refuse to replace existing integration/hook configuration')
    if source.count('dev_dependencies:\n') != 1:
        raise RuntimeError('Expected one development-dependency section')
    source = source.replace('dev_dependencies:\n', 'dev_dependencies:\n  integration_test:\n    sdk: flutter\n')
    if development_http:
        source += '\nhooks:\n  user_defines:\n    nds_native:\n      development_http: true\n'
    def interrupted(_signal, _frame):
        raise KeyboardInterrupt
    handlers = {sig: signal.signal(sig, interrupted) for sig in [signal.SIGTERM, signal.SIGINT]}
    try:
        spec.write_text(source)
        subprocess.run(['flutter', 'pub', 'get'], cwd=app, check=True,
                       stdout=subprocess.DEVNULL, timeout=120)
        yield
    finally:
        spec.write_bytes(original)
        lock.write_bytes(original_lock)
        try:
            subprocess.run(['flutter', 'pub', 'get', '--enforce-lockfile'], cwd=app,
                           check=True, stdout=subprocess.DEVNULL, timeout=120)
        finally:
            for sig, handler in handlers.items():
                signal.signal(sig, handler)
