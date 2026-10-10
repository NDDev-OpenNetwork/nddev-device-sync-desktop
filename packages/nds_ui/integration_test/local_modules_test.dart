import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nds_ui/nds_ui.dart';
import 'package:nds_native/nds_native.dart' as native;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('actual local modules and isolated native clipboard archive', (
    tester,
  ) async {
    await runNdsApp();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Local modules'));
    await tester.pumpAndSettle();
    await waitFor(tester, find.byKey(const Key('module-selector')));
    await tester.tap(find.byKey(const Key('read-system-info')));
    await waitFor(tester, find.text('CPU usage:'));
    expect(find.byKey(const Key('module-error')), findsNothing);

    await choose(tester, 'Clipboard history');
    await tester.tap(find.text('Refresh'));
    await waitFor(tester, find.byTooltip('Read text'));
    await tester.tap(find.byTooltip('Read text'));
    await waitFor(tester, find.text('Text preview, up to 16 KiB.'));
    const content = 'NDS isolated archive: Русский / English';
    expect(
      find.byWidgetPredicate(
        (widget) => widget is SelectableText && widget.data == content,
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('module-error')), findsNothing);

    await choose(tester, 'Cleaner');
    await tester.tap(find.text('Diagnostics'));
    await waitFor(tester, find.text('Errors:'));
    expect(find.byKey(const Key('module-error')), findsNothing);

    await choose(tester, 'Updates');
    await tester.tap(find.text('Update plan'));
    await waitFor(tester, find.textContaining('Channel:'));
    expect(find.byKey(const Key('module-error')), findsNothing);

    await choose(tester, 'GDS');
    const repository = String.fromEnvironment('NDS_TEST_REPOSITORY');
    expect(repository.startsWith('/tmp/nds-ui-providers.'), isTrue);
    await tester.enterText(
      find.byKey(const Key('repository-path')),
      repository,
    );
    await tester.tap(find.text('Refresh'));
    await waitFor(tester, find.text('Result:'));
    expect(find.byKey(const Key('module-error')), findsNothing);

    if (const bool.fromEnvironment('NDS_TEST_RDS_UNAVAILABLE')) {
      await choose(tester, 'RDS');
      await tester.tap(find.text('Refresh'));
      await waitFor(tester, find.byKey(const Key('module-error')));
      expect(
        tester.widget<Text>(find.byKey(const Key('module-error'))).data,
        'The local tool is unavailable.',
      );
    }
    expect(native.clientDiagnostics().sinkInitialized, isTrue);
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (native.clientDiagnostics().pendingEvents != BigInt.zero) {
      if (DateTime.now().isAfter(deadline)) {
        throw StateError('Local diagnostic output did not drain');
      }
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
    final diagnostics = native.clientDiagnostics();
    expect(diagnostics.writeFailures, BigInt.zero);
    expect(diagnostics.droppedEvents, BigInt.zero);
    expect(diagnostics.rejectedFieldsOrEvents, BigInt.zero);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Future<void> choose(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.byKey(const Key('module-selector')));
  await tester.tap(find.byKey(const Key('module-selector')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> waitFor(WidgetTester tester, Finder finder) async {
  final deadline = DateTime.now().add(const Duration(seconds: 35));
  while (finder.evaluate().isEmpty) {
    if (DateTime.now().isAfter(deadline)) {
      final error = find.byKey(const Key('module-error'));
      final text = error.evaluate().isEmpty
          ? 'no displayed error'
          : tester.widget<Text>(error).data;
      throw StateError(
        'Native module UI did not reach its expected state: $text',
      );
    }
    await tester.pump(const Duration(milliseconds: 100));
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle();
}
