import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nddev_opennetwork_design_system/opennetwork_design_system.dart';
import 'package:nds_native/nds_native.dart' as native;

import 'l10n/app_localizations.dart';

class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key, required this.client});
  final native.NdsClient client;
  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> with WidgetsBindingObserver {
  native.VaultView? _view;
  List<native.RecordView> _records = [];
  final _title = TextEditingController();
  final _username = TextEditingController();
  final _secret = TextEditingController();
  final _code = TextEditingController();
  String? _outputCode;
  String? _error;
  bool _busy = false;
  bool _paused = false;
  Timer? _refresh;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted && !_paused && !_busy && _view?.unlocked == true) {
        _run(() => widget.client.vaultSync());
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _run(() => widget.client.vaultRefresh());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _paused = state != AppLifecycleState.resumed;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refresh?.cancel();
    _secret.clear();
    for (final controller in [_title, _username, _secret, _code]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _run(Future<native.VaultView> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final view = await action();
      final records = view.unlocked
          ? await widget.client.vaultRecords()
          : <native.RecordView>[];
      if (mounted) {
        setState(() {
          _view = view;
          _records = records;
        });
      }
    } catch (error) {
      var code = 'unexpected';
      if (error is native.VaultError) {
        code = await error.code();
      }
      if (mounted) setState(() => _error = code);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() => _run(() async {
    try {
      await widget.client.vaultSave(
        title: _title.text.trim(),
        username: _username.text.trim(),
        secret: _secret.text,
      );
      _secret.clear();
      _title.clear();
      _username.clear();
      return await widget.client.vaultSync();
    } finally {
      _secret.clear();
    }
  });

  Future<void> _pair({required bool grant}) => _run(() async {
    if (grant) {
      final invitation = _code.text.trim();
      final peer = await widget.client.vaultPairingPreview(code: invitation);
      if (!mounted) return widget.client.vaultRefresh();
      final l = AppLocalizations.of(context)!;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l.vaultGrant),
          content: SelectableText(
            l.vaultGrantConfirm(peer.name, peer.deviceId, peer.fingerprint),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l.keepDevice),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l.vaultGrant),
            ),
          ],
        ),
      );
      if (confirmed != true) return widget.client.vaultRefresh();
      final code = await widget.client.vaultPairingGrant(code: invitation);
      if (mounted) setState(() => _outputCode = code);
      _code.clear();
      return widget.client.vaultRefresh();
    }
    await widget.client.vaultPairingImport(code: _code.text.trim());
    _code.clear();
    return widget.client.vaultSync();
  });

  String _message(AppLocalizations l) => switch (_error) {
    'vault_locked' => l.vaultLocked,
    'vault_key_exists' => l.vaultExisting,
    'vault_invalid_input' => l.vaultInputError,
    'vault_authentication_failed' => l.vaultProofError,
    'vault_busy' => l.rateError,
    'vault_dependency_unavailable' => l.networkError,
    _ => l.genericError,
  };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final view = _view;
    return Scaffold(
      appBar: AppBar(title: Text(l.vaultTitle)),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(OpenNetworkSpacing.six),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l.vaultHelp),
                  const SizedBox(height: OpenNetworkSpacing.four),
                  if (view != null) ...[
                    Text(
                      view.unlocked ? l.vaultUnlocked : l.vaultLocked,
                      key: const Key('vault-state'),
                    ),
                    Text(l.vaultCounts(view.pending, view.conflicts)),
                    if (view.keyId.isNotEmpty)
                      SelectableText('${l.vaultKeyIdentity}: ${view.keyId}'),
                    if (!view.unlocked) ...[
                      FilledButton(
                        key: const Key('vault-create'),
                        onPressed: _busy
                            ? null
                            : () => _run(() => widget.client.vaultCreate()),
                        child: Text(l.vaultCreate),
                      ),
                      OutlinedButton(
                        key: const Key('vault-pair-start'),
                        onPressed: _busy
                            ? null
                            : () => _run(() async {
                                final code = await widget.client
                                    .vaultPairingStart();
                                if (mounted) setState(() => _outputCode = code);
                                return widget.client.vaultRefresh();
                              }),
                        child: Text(l.vaultPairStart),
                      ),
                    ] else ...[
                      const SizedBox(height: OpenNetworkSpacing.six),
                      TextField(
                        key: const Key('vault-title'),
                        controller: _title,
                        maxLength: 128,
                        enabled: !_busy,
                        decoration: InputDecoration(
                          labelText: l.vaultRecordTitle,
                        ),
                      ),
                      TextField(
                        key: const Key('vault-username'),
                        controller: _username,
                        maxLength: 254,
                        enabled: !_busy,
                        autocorrect: false,
                        decoration: InputDecoration(labelText: l.vaultUsername),
                      ),
                      TextField(
                        key: const Key('vault-secret'),
                        controller: _secret,
                        enabled: !_busy,
                        obscureText: true,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: InputDecoration(labelText: l.vaultSecret),
                      ),
                      FilledButton(
                        key: const Key('vault-save'),
                        onPressed: _busy ? null : _save,
                        child: Text(l.vaultSave),
                      ),
                      const SizedBox(height: OpenNetworkSpacing.six),
                      for (final record in _records)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(
                              OpenNetworkSpacing.four,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  record.title,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                                if (record.username.isNotEmpty)
                                  Text(record.username),
                                Text(
                                  l.vaultRevision(record.revision.toString()),
                                ),
                                if (record.conflicted) Text(l.vaultConflict),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ],
                  const SizedBox(height: OpenNetworkSpacing.six),
                  Text(l.vaultPairHelp),
                  TextField(
                    key: const Key('vault-pair-code'),
                    controller: _code,
                    enabled: !_busy,
                    maxLength: 2048,
                    minLines: 2,
                    maxLines: 5,
                    autocorrect: false,
                    decoration: InputDecoration(labelText: l.vaultPairCode),
                  ),
                  if (view?.unlocked == true)
                    OutlinedButton(
                      key: const Key('vault-pair-grant'),
                      onPressed: _busy ? null : () => _pair(grant: true),
                      child: Text(l.vaultGrant),
                    )
                  else
                    OutlinedButton(
                      key: const Key('vault-pair-import'),
                      onPressed: _busy ? null : () => _pair(grant: false),
                      child: Text(l.vaultImport),
                    ),
                  if (_outputCode != null)
                    SelectableText(
                      _outputCode!,
                      key: const Key('vault-pair-output'),
                    ),
                  if (view?.pairingFingerprint.isNotEmpty == true)
                    SelectableText(
                      view!.pairingFingerprint,
                      key: const Key('vault-pair-fingerprint'),
                    ),
                  const SizedBox(height: OpenNetworkSpacing.four),
                  OutlinedButton(
                    key: const Key('vault-sync'),
                    onPressed: _busy
                        ? null
                        : () => _run(() => widget.client.vaultSync()),
                    child: Text(l.vaultSync),
                  ),
                  TextButton(
                    key: const Key('vault-refresh'),
                    onPressed: _busy
                        ? null
                        : () => _run(() => widget.client.vaultRefresh()),
                    child: Text(l.moduleRefresh),
                  ),
                  if (_busy) const LinearProgressIndicator(),
                  if (_error != null)
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _message(l),
                        key: const Key('vault-error'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
