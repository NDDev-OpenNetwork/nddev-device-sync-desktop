# nds_native

Thin native Rust bridge for [NDDev OpenNetwork](https://nddev.ai), AGPL-3.0-only.
`rust/src/api` owns only Flutter adaptation; accounts owns identity and native
credential storage. Generated Dart exports safe views and opaque handles.

Flutter Native Assets runs `hook/build.dart`. Regenerate through the repository's
`just generate` command, which also applies Rust formatting. The Android plugin
initializes the application context for native credentials and TLS verification;
no credentials cross a MethodChannel.
