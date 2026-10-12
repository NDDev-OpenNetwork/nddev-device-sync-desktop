import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';

import 'initialize_native.dart'
    if (dart.library.js_interop) 'initialize_web.dart'
    as platform;
import 'rust/frb_generated.dart';

Future<void> initializeNdsBridge() async {
  // FRB exposes different unrelated ExternalLibrary types on web and native.
  // Resolve and check the matching platform type at this conditional boundary.
  final library = await platform.bundledLibrary();
  await RustLib.init(externalLibrary: library as ExternalLibrary?);
}
