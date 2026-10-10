import 'package:flutter_rust_bridge_hooks/flutter_rust_bridge_hooks.dart';
import 'package:logging/logging.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    final development = input.userDefines['development_http'];
    if (development != null && development is! bool) {
      throw const FormatException('development_http must be a boolean');
    }
    final sourceCommit = input.userDefines['source_commit'];
    if (sourceCommit != null &&
        (sourceCommit is! String ||
            !RegExp(r'^[a-f0-9]{40}$').hasMatch(sourceCommit))) {
      throw const FormatException('source_commit must be an immutable Git SHA');
    }
    // The upstream build helper logs its environment at CONFIG level. Never
    // forward those diagnostics; compiler failures still propagate as errors.
    final safeLogger = Logger.detached('nds_native_build')..level = Level.OFF;
    await FlutterRustBridgeNativeAssetsBuilder(
      cratePath: 'rust',
      buildMode: development == true
          ? FlutterRustBridgeBuildMode.debug
          : FlutterRustBridgeBuildMode.release,
      features: development == true ? const ['development-http'] : const [],
      extraCargoBuildArgs: const ['--locked', '--jobs', '4'],
      extraCargoEnvironmentVariables: {
        'RUSTUP_AUTO_INSTALL': '0',
        'NDS_SOURCE_COMMIT': sourceCommit as String? ?? 'unknown',
      },
    ).run(input: input, output: output, logger: safeLogger);
  });
}
