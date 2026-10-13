import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nds_native/nds_native.dart' as native;
import 'package:nds_ui/activity.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => native.RustLib.init());

  testWidgets('raw Flutter visibility uses the actual Rust activity policy', (
    tester,
  ) async {
    final previous = tester.binding.lifecycleState;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final observed = <native.ClientLifecycle>[];
    final activity = ApplicationActivity(
      nativeReady: true,
      onLifecycle: observed.add,
    );
    final client = native.NdsClient(endpoint: 'https://example.invalid');
    try {
      activity.attach(client);
      expect(activity.value, isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      expect(activity.value, isTrue);
      expect(observed.last, native.ClientLifecycle.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      expect(activity.value, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      expect(activity.value, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      expect(activity.value, isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(activity.value, isTrue);
    } finally {
      activity.dispose();
      client.cancel();
      client.dispose();
      tester.binding.handleAppLifecycleStateChanged(
        previous ?? AppLifecycleState.resumed,
      );
    }
  });

  testWidgets('unavailable startup never admits native background work', (
    tester,
  ) async {
    final activity = ApplicationActivity(nativeReady: false);
    try {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      expect(activity.value, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(activity.value, isFalse);
    } finally {
      activity.dispose();
    }
  });
}
