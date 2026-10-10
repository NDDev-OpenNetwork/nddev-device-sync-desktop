import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nds_native/nds_native.dart' as native;
import 'package:nds_ui/diagnostics.dart';
import 'package:nds_ui/nds_ui.dart';

const privateInput = 'NDS_DIAGNOSTICS_PRIVATE_SENTINEL';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => native.RustLib.init());

  testWidgets(
    'actual framework failure reaches native policy without raw details',
    (tester) async {
      final previous = FlutterError.onError;
      final diagnostics = ApplicationDiagnostics()..nativeInitialized();
      try {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Builder(builder: (_) => throw StateError(privateInput)),
          ),
        );
        expect(diagnostics.hadFailure, isTrue);
        expect(diagnostics.reportingUnavailable, isFalse);
        final error = tester.widget<ErrorWidget>(find.byType(ErrorWidget));
        expect(error.message, isNot(contains(privateInput)));
        expect(native.clientDiagnostics().rejectedFieldsOrEvents, BigInt.zero);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        diagnostics.dispose();
      }
      expect(FlutterError.onError, previous);
    },
  );

  testWidgets('actual root-isolate async failure uses the same native policy', (
    tester,
  ) async {
    final diagnostics = ApplicationDiagnostics()..nativeInitialized();
    try {
      await tester.runAsync(() async {
        Zone.root.run(
          () => scheduleMicrotask(() => throw StateError(privateInput)),
        );
        final deadline = DateTime.now().add(const Duration(seconds: 3));
        while (!diagnostics.hadFailure && DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      expect(diagnostics.hadFailure, isTrue);
      expect(diagnostics.reportingUnavailable, isFalse);
      expect(native.clientDiagnostics().rejectedFieldsOrEvents, BigInt.zero);
    } finally {
      diagnostics.dispose();
    }
  });

  testWidgets('native debug window expires without an identity session', (
    tester,
  ) async {
    expect(
      () => native.configureDebug(scope: native.DebugScope.process, seconds: 1),
      throwsA(native.DiagnosticsError.invalidInput),
    );
    expect(
      () => native.configureDebug(scope: native.DebugScope.http, seconds: 301),
      throwsA(native.DiagnosticsError.invalidInput),
    );
    native.configureDebug(scope: native.DebugScope.io, seconds: 1);
    try {
      expect(native.clientDiagnostics().debugScope, native.DebugScope.io);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 1100)),
      );
      final status = native.clientDiagnostics();
      expect(status.debugEnabled, isFalse);
      expect(status.debugScope, isNull);
    } finally {
      native.configureDebug(scope: native.DebugScope.io, seconds: 0);
    }
  });

  testWidgets('startup failure has a safe user-facing screen', (tester) async {
    await tester.pumpWidget(const NdsApp(nativeReady: false));
    await tester.pumpAndSettle();
    expect(find.textContaining('NDS could not start.'), findsOneWidget);
    expect(find.byKey(const Key('connect')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
