import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
  native.RecordView? _editing;
  BigInt? _loadedCursor;
  String _after = '', _nextAfter = '';
  bool _hasMore = false;
  String _draftId = native.newVaultRecordId();
  final _title = TextEditingController();
  final _username = TextEditingController();
  final _secret = TextEditingController();
  final _scroll = ScrollController();
  String? _error;
  bool _busy = false, _paused = false;
  Timer? _refresh;
  Completer<void>? _backgroundRead;
  int _actionEpoch = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted &&
          !_paused &&
          !_busy &&
          ModalRoute.of(context)?.isCurrent == true) {
        unawaited(_run(() => widget.client.vaultSnapshot(), background: true));
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_run(() => widget.client.vaultSnapshot()));
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
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _run(
    Future<native.VaultView> Function() action, {
    bool reload = false,
    String? after,
    bool background = false,
  }) async {
    if (_busy || (background && _backgroundRead != null)) return;
    final epoch = background ? _actionEpoch : ++_actionEpoch;
    final completion = background ? Completer<void>() : null;
    if (background) {
      _backgroundRead = completion;
    } else {
      setState(() {
        _busy = true;
        if (reload) _error = null;
      });
    }
    try {
      // A user action has priority over the result of an older background read.
      // Finish that bounded read before acquiring the native mutation gate.
      if (!background) await _backgroundRead?.future;
      if (!mounted) return;
      final view = await action();
      if (!mounted || epoch != _actionEpoch) return;
      setState(() {
        _view = view;
        if (view.syncError.isNotEmpty) _error = view.syncError;
      });
      if (!view.unlocked) {
        setState(() {
          _records = [];
          _loadedCursor = null;
          _hasMore = false;
          _resetEditor();
        });
        return;
      }
      if (reload || _loadedCursor != view.cursor) {
        final cursor = after ?? _after;
        final page = await widget.client.vaultRecords(after: cursor);
        if (!mounted || epoch != _actionEpoch) return;
        setState(() {
          _records = page.items;
          _loadedCursor = page.observedSeq;
          _after = cursor;
          _nextAfter = page.nextAfter;
          _hasMore = page.hasMore;
          _error = view.syncError.isEmpty ? null : view.syncError;
        });
      }
    } catch (error) {
      var code = 'unexpected';
      if (error is native.VaultError) code = await error.code();
      if (mounted && epoch == _actionEpoch) {
        setState(() {
          if (code != 'vault_busy' || reload) _error = code;
          if (code == 'vault_locked') {
            _records = [];
            _loadedCursor = null;
            _secret.clear();
          }
        });
      }
    } finally {
      if (background) {
        _backgroundRead = null;
        completion!.complete();
      } else if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _resetEditor() {
    _secret.clear();
    _title.clear();
    _username.clear();
    _editing = null;
    _draftId = native.newVaultRecordId();
  }

  Future<void> _save() => _run(
    () async {
      await widget.client.vaultSave(
        id: _editing?.id ?? _draftId,
        expectedRevision: _editing?.revision ?? BigInt.zero,
        title: _title.text.trim(),
        username: _username.text.trim(),
        secret: _secret.text,
      );
      if (mounted) _resetEditor();
      return widget.client.vaultSnapshot();
    },
    reload: true,
    after: '',
  );

  Future<bool> _confirm(String title, String body, String action) async {
    final l = AppLocalizations.of(context)!;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(body),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l.actionCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(action),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _delete(native.RecordView record) async {
    final l = AppLocalizations.of(context)!;
    if (!await _confirm(
          l.vaultDelete,
          l.vaultDeleteHelp(record.title),
          l.vaultDelete,
        ) ||
        !mounted) {
      return;
    }
    await _run(() async {
      await widget.client.vaultDelete(
        id: record.id,
        expectedRevision: record.revision,
      );
      return widget.client.vaultSnapshot();
    }, reload: true);
  }

  Future<void> _resolve(native.RecordView record, bool conflict) async {
    final l = AppLocalizations.of(context)!;
    final choice = conflict ? l.vaultUseConflict : l.vaultKeepServer;
    if (!await _confirm(l.vaultResolve, l.vaultResolveHelp(choice), choice) ||
        !mounted) {
      return;
    }
    await _run(() async {
      await widget.client.vaultResolve(
        id: record.id,
        expectedRevision: record.revision,
        expectedCursor: record.observedSeq,
        useConflict: conflict,
      );
      return widget.client.vaultSnapshot();
    }, reload: true);
  }

  String _message(AppLocalizations l) => switch (_error) {
    'vault_locked' => l.vaultLocked,
    'vault_key_registration_required' => l.vaultRegistrationRequired,
    'vault_invalid_input' => l.vaultInputError,
    'vault_authentication_failed' => l.vaultProofError,
    'vault_busy' => l.operationBusy,
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
            controller: _scroll,
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
                    if (view.lastSyncAt != BigInt.zero)
                      Text(
                        l.syncLastSeen(
                          DateFormat.yMd(
                            Localizations.localeOf(context).languageCode,
                          ).add_Hms().format(
                            DateTime.fromMillisecondsSinceEpoch(
                              view.lastSyncAt.toInt() * 1000,
                            ),
                          ),
                        ),
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
                      if (_editing != null)
                        Text(l.vaultEditing(_editing!.title)),
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
                      if (_editing != null)
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => setState(_resetEditor),
                          child: Text(l.actionCancel),
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
                                if (record.deleted) Text(l.vaultDeleted),
                                if (record.conflicted) ...[
                                  Text(l.vaultConflict),
                                  if (record.conflict != null)
                                    Text(
                                      l.vaultConflictingTitle(
                                        record.conflict!.title,
                                      ),
                                    ),
                                  if (record.conflict?.deleted == true)
                                    Text(l.vaultConflictingDelete),
                                  Wrap(
                                    spacing: OpenNetworkSpacing.four,
                                    children: [
                                      TextButton(
                                        onPressed: _busy
                                            ? null
                                            : () => _resolve(record, false),
                                        child: Text(l.vaultKeepServer),
                                      ),
                                      TextButton(
                                        onPressed: _busy
                                            ? null
                                            : () => _resolve(record, true),
                                        child: Text(l.vaultUseConflict),
                                      ),
                                    ],
                                  ),
                                ] else if (!record.deleted)
                                  Wrap(
                                    spacing: OpenNetworkSpacing.four,
                                    children: [
                                      if (native.supportsNativeClipboard())
                                        TextButton(
                                          onPressed: _busy
                                              ? null
                                              : () => _run(() async {
                                                  await widget.client
                                                      .vaultCopySecret(
                                                        id: record.id,
                                                      );
                                                  return widget.client
                                                      .vaultSnapshot();
                                                }),
                                          child: Text(l.vaultCopySecret),
                                        ),
                                      TextButton(
                                        onPressed: _busy
                                            ? null
                                            : () {
                                                setState(() {
                                                  _editing = record;
                                                  _title.text = record.title;
                                                  _username.text =
                                                      record.username;
                                                  _secret.clear();
                                                });
                                                _scroll.jumpTo(0);
                                              },
                                        child: Text(l.vaultEdit),
                                      ),
                                      TextButton(
                                        onPressed: _busy
                                            ? null
                                            : () => _delete(record),
                                        child: Text(l.vaultDelete),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                      if (_hasMore)
                        TextButton(
                          key: const Key('vault-next-page'),
                          onPressed: _busy
                              ? null
                              : () => _run(
                                  () => widget.client.vaultSnapshot(),
                                  reload: true,
                                  after: _nextAfter,
                                ),
                          child: Text(l.vaultNextPage),
                        ),
                      if (_after.isNotEmpty)
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => _run(
                                  () => widget.client.vaultSnapshot(),
                                  reload: true,
                                  after: '',
                                ),
                          child: Text(l.vaultFirstPage),
                        ),
                    ],
                  ],
                  const SizedBox(height: OpenNetworkSpacing.six),
                  OutlinedButton(
                    key: const Key('vault-sync'),
                    onPressed: _busy
                        ? null
                        : () => _run(
                            () => widget.client.vaultSync(),
                            reload: true,
                          ),
                    child: Text(l.vaultSync),
                  ),
                  TextButton(
                    key: const Key('vault-refresh'),
                    onPressed: _busy
                        ? null
                        : () => _run(
                            () => widget.client.vaultRefresh(),
                            reload: true,
                          ),
                    child: Text(l.moduleRefresh),
                  ),
                  if (_busy) const LinearProgressIndicator(),
                  if (_error != null)
                    Semantics(
                      liveRegion: true,
                      child: Text(_message(l), key: const Key('vault-error')),
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
