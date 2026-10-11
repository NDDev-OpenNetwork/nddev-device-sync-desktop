import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nds_ui/nds_ui.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const server = String.fromEnvironment('NDS_TEST_SERVER');
  const mailbox = String.fromEnvironment('NDS_TEST_MAILPIT');
  const owner = String.fromEnvironment('NDS_TEST_OWNER');
  const vault = bool.fromEnvironment('NDS_TEST_VAULT');
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
        if (vault) {
          await tester.ensureVisible(find.byKey(const Key('open-vault')));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('open-vault')));
          await waitFor(tester, find.text('UI encrypted record'));
          expect(find.byKey(const Key('vault-create')), findsNothing);
          expect(find.text('PRIVATE_UI_VAULT_VALUE'), findsNothing);
          await tester.pageBack();
          await tester.pumpAndSettle();
        }
        await tester.ensureVisible(find.byKey(const Key('logout')));
        await tester.tap(find.byKey(const Key('logout')));
        await waitFor(tester, find.byKey(const Key('email')));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        return;
      }
      // A failed acceptance may leave this owned loopback fixture signed in.
      // Revoke only its own session before repeating the full interaction.
      await tester.pumpAndSettle();
      if (find.byKey(const Key('logout')).evaluate().isNotEmpty) {
        await tester.ensureVisible(find.byKey(const Key('logout')));
        await tester.tap(find.byKey(const Key('logout')));
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
      if (vault) {
        await tester.ensureVisible(find.byKey(const Key('open-vault')));
        await tester.tap(find.byKey(const Key('open-vault')));
        await waitFor(tester, find.byKey(const Key('vault-title')));
        await tester.enterText(
          find.byKey(const Key('vault-title')),
          'UI encrypted record',
        );
        await tester.enterText(
          find.byKey(const Key('vault-username')),
          'fixture-user',
        );
        await tester.enterText(
          find.byKey(const Key('vault-secret')),
          'PRIVATE_UI_VAULT_VALUE',
        );
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const Key('vault-save')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('vault-save')));
        await waitFor(tester, find.text('UI encrypted record'));
        expect(
          tester
              .widget<TextField>(find.byKey(const Key('vault-secret')))
              .controller!
              .text,
          isEmpty,
        );
        expect(find.text('PRIVATE_UI_VAULT_VALUE'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.byKey(const Key('open-synced-state')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('open-synced-state')));
        await waitFor(tester, find.byKey(const Key('publish-device-state')));
        await tester.tap(find.byKey(const Key('publish-device-state')));
        await waitFor(tester, find.text('Email code'));
        expect(find.text('Acceptance device'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.pageBack();
        await tester.pumpAndSettle();
        if (nativeDesktop()) {
          await tester.tap(find.text('Local modules'));
          await waitFor(tester, find.byKey(const Key('publish-local-state')));
          await tester.tap(find.byKey(const Key('publish-local-state')));
          await waitFor(tester, find.text('Pending: 0 · Conflicts: 0'));
          await tester.tap(find.text('NDS session'));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.byKey(const Key('open-vault')));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('open-vault')));
          await waitFor(tester, find.byKey(const Key('open-synced-state')));
          await tester.ensureVisible(
            find.byKey(const Key('open-synced-state')),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('open-synced-state')));
          await waitFor(tester, find.text('gds'));
          expect(find.text('rds'), findsOneWidget);
          await tester.pageBack();
          await tester.pumpAndSettle();
          await tester.pageBack();
          await tester.pumpAndSettle();
        }
      }
      if (vault) {
        await tester.ensureVisible(find.byKey(const Key('open-utilities')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('open-utilities')));
        await waitFor(tester, find.byKey(const Key('shared-text')));
        await tester.enterText(
          find.byKey(const Key('shared-text')),
          'Owned shared clipboard acceptance',
        );
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const Key('share-text')));
        await tester.tap(find.byKey(const Key('share-text')));
        await waitFor(tester, find.textContaining('Server revision'));
        if (!Platform.isIOS) {
          await tester.ensureVisible(
            find.byKey(const Key('copy-shared-clipboard')),
          );
          await tester.pumpAndSettle();
          await waitFor(
            tester,
            find.byWidgetPredicate(
              (widget) =>
                  widget is FilledButton &&
                  widget.key == const Key('copy-shared-clipboard') &&
                  widget.onPressed != null,
            ),
          );
          await tester.tap(find.byKey(const Key('copy-shared-clipboard')));
          await waitFor(tester, find.text('Copied to device clipboard.'));
          await tester.pumpAndSettle();
          final deadline = DateTime.now().add(const Duration(seconds: 10));
          while (true) {
            final copied = await Clipboard.getData(Clipboard.kTextPlain);
            if (copied?.text == 'Owned shared clipboard acceptance') break;
            if (DateTime.now().isAfter(deadline)) {
              final error = find.byKey(const Key('utility-error'));
              throw StateError(
                error.evaluate().isEmpty
                    ? 'Native clipboard value not observed'
                    : tester.widget<Text>(error).data!,
              );
            }
            await tester.pump(const Duration(milliseconds: 100));
            await Future<void>.delayed(const Duration(milliseconds: 100));
          }
          if (Platform.isAndroid) {
            await tester.ensureVisible(
              find.byKey(const Key('share-native-clipboard')),
            );
            await tester.pumpAndSettle();
            await tester.tap(find.byKey(const Key('share-native-clipboard')));
            await waitFor(
              tester,
              find.textContaining('This clipboard item is private'),
            );
          }
        }
        await tester.pageBack();
        await tester.pumpAndSettle();
      }
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

bool nativeDesktop() =>
    Platform.isLinux || Platform.isMacOS || Platform.isWindows;

Future<void> waitFor(WidgetTester tester, Finder finder) async {
  final deadline = DateTime.now().add(const Duration(seconds: 25));
  while (finder.evaluate().isEmpty) {
    if (DateTime.now().isAfter(deadline)) {
      final error = find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            {
              const Key('auth-error'),
              const Key('vault-error'),
              const Key('state-error'),
            }.contains(widget.key),
      );
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
