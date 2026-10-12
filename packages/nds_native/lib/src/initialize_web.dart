import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated_web.dart';

// The web assembly loads the pinned ES module without eval or script injection.
@JS('ndsInitializeRust')
external JSPromise<JSAny?> _initializeRust();

Future<Object?> bundledLibrary() async {
  await _initializeRust().toDart;
  return const ExternalLibrary(debugInfo: 'NDS bundled Rust module');
}
