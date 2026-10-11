# nddev-device-sync-desktop

Desktop client and shared Flutter presentation for
[NDDev OpenNetwork](https://nddev.ai), AGPL-3.0-only. `packages/nds_ui` owns the
en/ru interface used by desktop and mobile; `packages/nds_native` generates a
thin bridge to the Rust accounts module. NDS tokens never enter Dart.

The same observability SDK used by the server and agent owns event validation,
redaction, trace context, debug windows and local diagnostics. Flutter framework
and root-isolate async failures pass only a fixed error class through the generated
bridge; raw exception text/stacks are omitted from both logs and error widgets.
Diagnostics work before sign-in. Network and local-I/O debug scopes expire
after five minutes or 100 debug events. Normal security/error logging continues.
The SDK emits process startup and controlled shutdown; a cancelable desktop exit
waits for bounded shutdown, while mobile background/detach never terminates it.
Forced termination cannot promise a final event. Missing native initialization
shows a safe localized startup screen; a missing sink remains explicitly degraded.

`just check` includes real framework/root-isolate failure tests using the native
library. The observability repository's isolated pipeline can additionally consume
that private test log through `NDS_CLIENT_EVENTS_FILE` and verify searchable
failure records in OpenObserve. Authenticated clients use the shared native
accounts sender for signed event and OTLP span delivery; the server applies its
operator policy and binds tenant/user/device identity. Clipboard and alerts
shows per-signal acknowledgements, losses, policy and last successful receipt.
Pause/resume, bounded retention and cancellation belong to the shared sender.

Use Flutter 3.47.7/Dart 3.13.5, Rust 1.99.0 and flutter_rust_bridge_codegen 2.13.0.
Install the Rust target matching the platform being built. `flutter pub get
--enforce-lockfile`, `just check`, `just generated-check` and `just build-linux`
cover dependencies, static checks, generated-source drift and the Linux build.
Run the same native build on each other supported host before claiming support.

The Linux alpha uses Flutter's supported Skia GPU backend. Requalify Impeller
after an engine update passes native interaction acceptance under low VRAM;
this selection does not enable software rendering.

`flutter run -d linux` opens the client. Enter the HTTPS origin of an NDS server
supporting protocol v2. Native credential storage must be available and unlocked.
GitHub sign-in requires the server's actual provider configuration and explicit
browser approval; an unavailable provider stays unavailable.

`just identity-acceptance /private/path/fixture.json linux` runs the real UI
against an explicitly started server PostgreSQL/Mailpit fixture. The driver
briefly enables debug-only loopback HTTP, uses a synthetic identity, and restores
the runner configuration afterward. Production builds require HTTPS. Runtime
logs and fixture receipts stay outside the repository.

For encrypted persistence across Android processes, pass `--cold-restart` to the
acceptance driver with an explicitly owned emulator and no existing NDS app.
The two launches preserve app storage between phases, then revoke the session
and uninstall only the test-owned app.

The desktop Local modules tab reads native system metrics, clipboard history,
cleaner diagnostics/previews, update plans and repository/remote-session state.
Missing tools report unavailable. `just module-acceptance /absolute/path/to/clipboardd`
runs actual Flutter interactions with installed providers, a fresh clipboard
archive with capture disabled, and a temporary Git repository. It does not read
or change the personal clipboard archive or execute cleanup/updates.

`python scripts/build.py linux --debug` builds committed source with an explicit,
cache-tracked native source SHA; ordinary `flutter build` retains development
provenance. The build wrapper restores its temporary hook configuration.

CI pins SDK archives by SHA-256 and builds Linux, macOS (ARM64/Intel) and
Windows. Those builds are separate from native credential/provider interaction
acceptance. `scripts/check-artifact.py` rejects integration entrypoints and
native test plugins in debug bundles. Integration dependencies exist only
inside the acceptance driver's temporary scope.

Vault records use bounded native cursor pages. The UI supports create/edit,
encrypted tombstones and explicit conflict choices guarded by the displayed
revision and observed sequence. A save confirms a durable local outbox receipt;
the UI separately shows pending changes and the last fully caught-up timestamp.
Background reads keep editors enabled and retain keyboard focus. A user action
waits for an already running read and supersedes its presentation result.
Secret values are copied through native clipboard operations and are never
returned by the bridge. Shared text is explicit, bounded to 8 KiB and encrypted.
Android refuses private/unsupported input and marks delivered values sensitive
so they do not re-enter shared capture.

Passkey management exposes only public fingerprints and creation times.
Removal requires a recent sign-in and consumes the server's atomic revocation
receipt; revoking the current passkey session returns to sign-in. Creating or
using a passkey opens the server's browser ceremony with comparison-code approval.

`--vault` in identity acceptance also exercises shared text delivery/copy and,
on Android, refusal to re-share a marked private clipboard value. Use an owned
X11 session for Linux clipboard acceptance, for example
`xvfb-run -a env -u WAYLAND_DISPLAY GDK_BACKEND=x11 python3 scripts/identity-acceptance.py --fixture /private/fixture.json --vault`.
The test must observe the native operation completing before reading the OS
clipboard. Production UI confirmation uses the same native completion receipt.
