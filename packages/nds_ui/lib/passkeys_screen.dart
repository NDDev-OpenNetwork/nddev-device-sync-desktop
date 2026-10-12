import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nddev_opennetwork_design_system/opennetwork_design_system.dart';
import 'package:nds_native/nds_native.dart' as native;

import 'l10n/app_localizations.dart';

class PasskeysScreen extends StatefulWidget {
  const PasskeysScreen({super.key, required this.client});
  final native.NdsClient client;
  @override
  State<PasskeysScreen> createState() => _PasskeysState();
}

class _PasskeysState extends State<PasskeysScreen> {
  List<native.PasskeyView>? _keys;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _run(Future<void> Function() work) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await work();
    } catch (error) {
      var code = 'unexpected';
      if (error is native.ClientError) {
        code = error.code();
        error.dispose();
      }
      if (mounted) setState(() => _error = code);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _load() => _run(() async {
    final keys = await widget.client.passkeys();
    if (mounted) setState(() => _keys = keys);
  });

  Future<void> _remove(native.PasskeyView key) async {
    final l = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.passkeyRemove),
        content: Text(l.passkeyRemoveHelp(key.id.substring(0, 12))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.keepPasskey),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.passkeyRemove),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(() async {
      final view = await widget.client.revokePasskey(id: key.id);
      if (!mounted) return;
      if (!view.authenticated) {
        Navigator.pop(context);
        return;
      }
      // The committed receipt is sufficient; a failed second network request
      // must not make a successful revocation appear to have failed.
      setState(() => _keys?.removeWhere((value) => value.id == key.id));
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    return Scaffold(
      appBar: AppBar(title: Text(l.passkeysTitle)),
      body: ListView(
        padding: const EdgeInsets.all(OpenNetworkSpacing.six),
        children: [
          Text(l.passkeysHelp),
          if (_keys?.isEmpty == true) Text(l.passkeysEmpty),
          for (final key in _keys ?? <native.PasskeyView>[])
            Card(
              child: ListTile(
                title: Text(key.id.substring(0, 12)),
                subtitle: Text(
                  l.passkeyCreated(
                    DateFormat.yMd(locale)
                        .add_Hm()
                        .format(DateTime.parse(key.createdAt).toLocal()),
                  ),
                ),
                trailing: TextButton(
                  onPressed: _busy ? null : () => _remove(key),
                  child: Text(l.passkeyRemove),
                ),
              ),
            ),
          TextButton(
            onPressed: _busy ? null : _load,
            child: Text(l.moduleRefresh),
          ),
          if (_busy) const LinearProgressIndicator(),
          if (_error != null)
            Semantics(
              liveRegion: true,
              child: Text(switch (_error) {
                'authorization_denied' => l.passkeyFreshLogin,
                'authentication_failed' => l.authError,
                'busy' || 'rate_limited' || 'server_busy' => l.operationBusy,
                'credential_store_unavailable' => l.storeError,
                'transport_unavailable' ||
                'request_timeout' ||
                'dependency_unavailable' => l.networkError,
                _ => l.genericError,
              }),
            ),
        ],
      ),
    );
  }
}
