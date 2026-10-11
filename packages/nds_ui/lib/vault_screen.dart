import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nddev_opennetwork_design_system/opennetwork_design_system.dart';
import 'package:nds_native/nds_native.dart' as native;

import 'l10n/app_localizations.dart';
import 'state_screen.dart';

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
  String? _error;
  bool _busy = false;
  bool _paused = false;
  Timer? _refresh;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !_paused && !_busy) {
        _run(() => widget.client.vaultSnapshot());
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _run(() => widget.client.vaultSnapshot());
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
    for (final controller in [_title, _username, _secret]) {
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
          _error = view.syncError.isEmpty ? null : view.syncError;
        });
      }
    } catch (error) {
      var code = 'unexpected';
      if (error is native.VaultError) {
        code = await error.code();
      }
      if (code != 'vault_busy' && mounted) setState(() => _error = code);
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

  String _message(AppLocalizations l) => switch (_error) {
    'vault_locked' => l.vaultLocked,
    'vault_key_registration_required' => l.vaultRegistrationRequired,
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
                    Text(
                      view.catchingUp
                          ? l.syncCatchingUp
                          : view.lastSyncAt == BigInt.zero
                          ? l.syncNotObserved
                          : l.syncCaughtUp,
                    ),
                    if (view.keyId.isNotEmpty)
                      SelectableText('${l.vaultKeyIdentity}: ${view.keyId}'),
                    if (view.unlocked) ...[
                      OutlinedButton(
                        key: const Key('open-synced-state'),
                        onPressed: _busy
                            ? null
                            : () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      StateScreen(client: widget.client),
                                ),
                              ),
                        child: Text(l.syncedState),
                      ),
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
