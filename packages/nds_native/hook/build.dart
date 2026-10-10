import 'package:flutter_rust_bridge_hooks/flutter_rust_bridge_hooks.dart';
import 'package:logging/logging.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    final development = input.userDefines['development_http'];
    if (development != null && development is! bool) {
      throw const FormatException('development_http must be a boolean');
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
      extraCargoEnvironmentVariables: const {'RUSTUP_AUTO_INSTALL': '0'},
    ).run(input: input, output: output, logger: safeLogger);
  });
}
