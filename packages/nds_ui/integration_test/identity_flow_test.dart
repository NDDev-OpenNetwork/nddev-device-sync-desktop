import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nds_ui/nds_ui.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const server = String.fromEnvironment('NDS_TEST_SERVER');
  const mailbox = String.fromEnvironment('NDS_TEST_MAILPIT');
  const owner = String.fromEnvironment('NDS_TEST_OWNER');
  const phase = String.fromEnvironment(
    'NDS_TEST_PHASE',
    defaultValue: 'complete',
  );

  testWidgets(
    'actual identity, device enrollment, native restore and revocation',
    (tester) async {
      expect(Uri.parse(server).host, '127.0.0.1');
      expect(Uri.parse(mailbox).host, '127.0.0.1');
      expect(owner.endsWith('.invalid') || owner.endsWith('.test'), isTrue);
      final frameworkHandler = FlutterError.onError;
      await runNdsApp();
      final diagnosticHandler = FlutterError.onError;
      // Production reports redacted classes. The acceptance harness must also
      // receive unexpected framework failures rather than silently swallow them.
      FlutterError.onError = (details) {
        diagnosticHandler?.call(details);
        frameworkHandler?.call(details);
      };
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        FlutterError.onError = frameworkHandler;
      });
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('server-address')), server);
      await tester.tap(find.byKey(const Key('connect')));
      if (phase == 'restore') {
        await waitFor(tester, find.byKey(const Key('logout')));
        expect(find.text('This installation'), findsOneWidget);
        await tester.ensureVisible(find.byKey(const Key('logout')));
        await tester.tap(find.byKey(const Key('logout')));
        await waitFor(tester, find.byKey(const Key('email')));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        return;
      }
      await waitFor(tester, find.byKey(const Key('email')));
      await tester.enterText(find.byKey(const Key('email')), owner);
      await tester.tap(find.byKey(const Key('send-code')));
      await waitFor(tester, find.byKey(const Key('otp')));

      final code = await readLocalCode(mailbox);
      await tester.enterText(find.byKey(const Key('otp')), code);
      await tester.tap(find.byKey(const Key('verify')));
      await waitFor(tester, find.byKey(const Key('logout')));
      expect(find.byKey(const Key('otp')), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byKey(const Key('device-name')));
      await tester.enterText(
        find.byKey(const Key('device-name')),
        'Acceptance device',
      );
      await tester.ensureVisible(find.byKey(const Key('enroll-device')));
      await tester.tap(find.byKey(const Key('enroll-device')));
      await waitFor(tester, find.text('This installation'));
      Finder currentCard() => find.ancestor(
        of: find.text('This installation'),
        matching: find.byType(Card),
      );
      expect(
        find.descendant(
          of: currentCard(),
          matching: find.text('Acceptance device'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('enroll-device')), findsNothing);
      if (phase == 'persist') {
        await tester.pumpWidget(const SizedBox.shrink());
        return;
      }

      // Replace the client. Restoration must use the actual native store and
      // a fresh server validation, rather than a retained Dart session object.
      await tester.ensureVisible(find.text('Change server'));
      await tester.tap(find.text('Change server'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('connect')));
      await waitFor(tester, find.byKey(const Key('logout')));
      expect(
        find.descendant(
          of: currentCard(),
          matching: find.text('Acceptance device'),
        ),
        findsOneWidget,
      );
      expect(find.text('This installation'), findsOneWidget);
      final revoke = find.descendant(
        of: currentCard(),
        matching: find.widgetWithText(TextButton, 'Revoke device'),
      );
      await tester.ensureVisible(revoke);
      await tester.tap(revoke);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Revoke device'));
      await tester.pumpAndSettle();
      await waitFor(
        tester,
        find.descendant(
          of: currentCard(),
          matching: find.textContaining('· Revoked'),
        ),
      );
      await tester.ensureVisible(find.byKey(const Key('logout')));
      await tester.tap(find.byKey(const Key('logout')));
      await waitFor(tester, find.byKey(const Key('email')));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

Future<void> waitFor(WidgetTester tester, Finder finder) async {
  final deadline = DateTime.now().add(const Duration(seconds: 25));
  while (finder.evaluate().isEmpty) {
    if (DateTime.now().isAfter(deadline)) {
      final error = find.byKey(const Key('auth-error'));
      final message = error.evaluate().isEmpty
          ? 'no displayed error'
          : tester.widget<Text>(error).data;
      throw StateError(
        'Identity UI did not reach its expected state: $message',
      );
    }
    await tester.pump(const Duration(milliseconds: 100));
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle();
}

Future<String> readLocalCode(String mailbox) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
  Future<Map<String, dynamic>> get(String path) async {
    final request = await client.getUrl(Uri.parse('$mailbox$path'));
    final response = await request.close().timeout(const Duration(seconds: 5));
    if (response.statusCode != 200) {
      throw StateError('Isolated mailbox unavailable');
    }
    final body = await utf8.decoder.bind(response).join();
    return jsonDecode(body) as Map<String, dynamic>;
  }

  try {
    return await (() async {
      while (true) {
        final messages = (await get('/api/v1/messages'))['messages'] as List;
        if (messages.isNotEmpty) {
          final id = (messages.first as Map)['ID'] as String;
          final message = await get('/api/v1/message/$id');
          final match = RegExp(r'(?:code|код входа): (\d{8})')
              .firstMatch(message['Text'] as String);
          if (match != null) return match.group(1)!;
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    })().timeout(const Duration(seconds: 10));
  } finally {
    client.close(force: true);
  }
}
