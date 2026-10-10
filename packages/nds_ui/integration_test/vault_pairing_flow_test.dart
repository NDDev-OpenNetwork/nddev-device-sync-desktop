import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nds_ui/nds_ui.dart';

// This is a real two-process/native-store scenario. The disposable relay carries
// only public invitations, fingerprints and encrypted grants, never credentials.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const server = String.fromEnvironment('NDS_TEST_SERVER');
  const mailbox = String.fromEnvironment('NDS_TEST_MAILPIT');
  const owner = String.fromEnvironment('NDS_TEST_OWNER');
  const role = String.fromEnvironment('NDS_TEST_PAIRING_ROLE');
  const relay = String.fromEnvironment('NDS_TEST_RELAY');
  const phase = String.fromEnvironment('NDS_TEST_PHASE');

  testWidgets('actual trusted-device E2EE transfer and bidirectional records', (
    tester,
  ) async {
    for (final url in [server, mailbox, relay]) {
      expect(Uri.parse(url).host, '127.0.0.1');
    }
    expect(owner.endsWith('.invalid'), isTrue);
    final http = HttpClient()..connectionTimeout = const Duration(seconds: 3);
    http.findProxy = (_) => 'DIRECT';
    final framework = FlutterError.onError;
    await runNdsApp();
    final diagnostic = FlutterError.onError;
    FlutterError.onError = (details) {
      diagnostic?.call(details);
      framework?.call(details);
    };
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      FlutterError.onError = framework;
      http.close(force: true);
    });
    Future<Map<String, dynamic>> request(
      String url, [
      Map<String, dynamic>? body,
    ]) async {
      final req = await http.openUrl(
        body == null ? 'GET' : 'POST',
        Uri.parse(url),
      );
      if (body != null) {
        req.headers.contentType = ContentType.json;
        req.write(jsonEncode(body));
      }
      final res = await req.close().timeout(const Duration(seconds: 5));
      expect(res.statusCode, 200);
      return jsonDecode(await utf8.decoder.bind(res).join())
          as Map<String, dynamic>;
    }

    Future<void> waitUntil(bool Function() ready) async {
      final deadline = DateTime.now().add(const Duration(seconds: 160));
      while (!ready()) {
        if (DateTime.now().isAfter(deadline)) {
          throw StateError('Pairing acceptance timed out');
        }
        await tester.pump(const Duration(milliseconds: 100));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      await tester.pumpAndSettle();
    }

    Future<void> visible(String key) async {
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      final finder = find.byKey(Key(key));
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
    }

    Future<String> relayValue(String key) async {
      String? value;
      final deadline = DateTime.now().add(const Duration(seconds: 160));
      while (value == null) {
        value = (await request(relay))[key] as String?;
        if (DateTime.now().isAfter(deadline)) {
          throw StateError('Peer did not reach pairing step');
        }
        await tester.pump(const Duration(milliseconds: 200));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
      return value;
    }

    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('server-address')), server);
    await visible('connect');
    if (phase != 'restore') {
      await waitUntil(
        () => find.byKey(const Key('email')).evaluate().isNotEmpty,
      );
      if (role == 'recipient') await relayValue('ready');
      await tester.enterText(find.byKey(const Key('email')), owner);
      final requestedAt = DateTime.now();
      await visible('send-code');
      await waitUntil(() => find.byKey(const Key('otp')).evaluate().isNotEmpty);
      final messages =
          (await request('$mailbox/api/v1/messages'))['messages'] as List;
      final id = (messages.first as Map)['ID'] as String;
      final message = await request('$mailbox/api/v1/message/$id');
      final code = RegExp(r'code: (\d{8})')
          .firstMatch(message['Text'] as String)!
          .group(1)!;
      await tester.enterText(find.byKey(const Key('otp')), code);
      await visible('verify');
      await waitUntil(
        () => find.byKey(const Key('device-name')).evaluate().isNotEmpty,
      );
      await tester.enterText(
        find.byKey(const Key('device-name')),
        'Pairing $role',
      );
      await visible('enroll-device');
      await waitUntil(
        () => find.text('This installation').evaluate().isNotEmpty,
      );
      await visible('open-vault');
      await waitUntil(
        () => find.byKey(const Key('vault-create')).evaluate().isNotEmpty,
      );
      if (role == 'owner') {
        await visible('vault-create');
        await waitUntil(
          () => find.byKey(const Key('vault-title')).evaluate().isNotEmpty,
        );
        await tester.enterText(
          find.byKey(const Key('vault-title')),
          'Linux shared record',
        );
        await tester.enterText(
          find.byKey(const Key('vault-secret')),
          'PRIVATE_PAIR_LINUX_VALUE',
        );
        await visible('vault-save');
        await waitUntil(
          () => find.text('Linux shared record').evaluate().isNotEmpty,
        );
        // Respect the real email challenge cooldown before the second process
        // signs in. No clock modification or provider bypass is used.
        await waitUntil(
          () => DateTime.now().difference(requestedAt).inSeconds >= 61,
        );
        await request(relay, {'ready': 'ready'});
        final invitation = await relayValue('invitation');
        final fingerprint = await relayValue('fingerprint');
        await tester.enterText(
          find.byKey(const Key('vault-pair-code')),
          invitation,
        );
        await visible('vault-pair-grant');
        await waitUntil(() => find.byType(AlertDialog).evaluate().isNotEmpty);
        expect(find.textContaining(fingerprint), findsOneWidget);
        expect(find.textContaining('Pairing recipient'), findsOneWidget);
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(FilledButton),
          ),
        );
        await waitUntil(
          () =>
              find.byKey(const Key('vault-pair-output')).evaluate().isNotEmpty,
        );
        final grant = tester
            .widget<SelectableText>(find.byKey(const Key('vault-pair-output')))
            .data!;
        await request(relay, {'grant': grant});
        await relayValue('recipient_saved');
        await visible('vault-sync');
        await waitUntil(
          () => find.text('Android shared record').evaluate().isNotEmpty,
        );
      } else {
        await visible('vault-pair-start');
        await waitUntil(
          () =>
              find.byKey(const Key('vault-pair-output')).evaluate().isNotEmpty,
        );
        final invitation = tester
            .widget<SelectableText>(find.byKey(const Key('vault-pair-output')))
            .data!;
        final fingerprint = tester
            .widget<SelectableText>(
              find.byKey(const Key('vault-pair-fingerprint')),
            )
            .data!;
        await request(relay, {
          'invitation': invitation,
          'fingerprint': fingerprint,
        });
        final grant = await relayValue('grant');
        await tester.enterText(find.byKey(const Key('vault-pair-code')), grant);
        await visible('vault-pair-import');
        await waitUntil(
          () => find.text('Linux shared record').evaluate().isNotEmpty,
        );
        await tester.enterText(
          find.byKey(const Key('vault-title')),
          'Android shared record',
        );
        await tester.enterText(
          find.byKey(const Key('vault-secret')),
          'PRIVATE_PAIR_ANDROID_VALUE',
        );
        await visible('vault-save');
        await waitUntil(
          () => find.text('Android shared record').evaluate().isNotEmpty,
        );
        await request(relay, {'recipient_saved': 'saved'});
      }
    } else {
      await waitUntil(
        () => find.byKey(const Key('open-vault')).evaluate().isNotEmpty,
      );
      await visible('open-vault');
      await waitUntil(
        () => find.text('Linux shared record').evaluate().isNotEmpty,
      );
      expect(find.text('Android shared record'), findsOneWidget);
      expect(find.byKey(const Key('vault-create')), findsNothing);
    }
    expect(find.text('PRIVATE_PAIR_LINUX_VALUE'), findsNothing);
    expect(find.text('PRIVATE_PAIR_ANDROID_VALUE'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
