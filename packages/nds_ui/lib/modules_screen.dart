import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nddev_opennetwork_design_system/opennetwork_design_system.dart';
import 'package:nds_native/nds_native.dart' as native;
import 'package:nds_native/sysinfo.dart' as sysinfo;
import 'package:nds_native/clipboard.dart' as clipboard;
import 'package:nds_native/cleaner.dart' as cleaner;
import 'package:nds_native/updater.dart' as updater;
import 'package:nds_native/gds.dart' as gds;
import 'package:nds_native/rds.dart' as rds;

import 'l10n/app_localizations.dart';
import 'diagnostics.dart';

/// Presentation over canonical native responses. Local tools retain their state
/// and safety policies; this screen exposes bounded read/preview operations.
class ModulesScreen extends StatefulWidget {
  const ModulesScreen({super.key, required this.onLocale, this.diagnostics});
  final ValueChanged<Locale> onLocale;
  final ApplicationDiagnostics? diagnostics;
  @override
  State<ModulesScreen> createState() => _ModulesScreenState();
}

class _ModulesScreenState extends State<ModulesScreen> {
  native.LocalAgent? _agent;
  List<native.ModuleState> _modules = [];
  String _selected = 'sysinfo';
  Object? _result;
  String? _error;
  bool _busy = true;
  bool _cancelled = false;
  int _epoch = 0;
  final _repository = TextEditingController();

  @override
  void initState() {
    super.initState();
    _discover();
  }

  Future<void> _discover() async {
    final epoch = _epoch;
    try {
      final agent = await native.LocalAgent.discover();
      if (!mounted || epoch != _epoch) {
        agent.close();
        agent.dispose();
        return;
      }
      setState(() {
        _agent = agent;
        _modules = agent.modules();
        _busy = false;
      });
    } catch (error) {
      if (error is! native.AgentError) {
        widget.diagnostics?.reportFailure(native.FailureKind.nativeBridge);
      }
      if (mounted && epoch == _epoch) {
        setState(() {
          _error = 'unavailable';
          _busy = false;
        });
      }
    }
  }

  Future<void> _load(Future<Object> Function() operation) async {
    if (_busy || _agent == null) return;
    final epoch = _epoch;
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });
    try {
      final result = await operation();
      if (mounted && epoch == _epoch) setState(() => _result = result);
    } catch (error) {
      if (error is! native.AgentError) {
        widget.diagnostics?.reportFailure(native.FailureKind.nativeBridge);
      }
      if (mounted && epoch == _epoch) {
        setState(
          () => _error = error is native.AgentError ? error.name : 'unknown',
        );
      }
    } finally {
      if (mounted && epoch == _epoch) {
        setState(() {
          _busy = false;
          _modules = _agent?.modules() ?? [];
        });
      } else if (mounted && _cancelled) {
        // Close is terminal. Wait for the owned operation to finish before
        // creating another engine, so repeated cancellation cannot queue work.
        _agent?.dispose();
        _agent = null;
        _cancelled = false;
        _discover();
      }
    }
  }

  void _cancel() {
    if (!_busy || _agent == null || _cancelled) return;
    _epoch++;
    _agent!.close();
    setState(() {
      _result = null;
      _error = 'cancelled';
      _cancelled = true;
    });
  }

  @override
  void dispose() {
    _epoch++;
    _agent?.close();
    _agent?.dispose();
    _repository.dispose();
    super.dispose();
  }

  String _name(AppLocalizations l, String id) => switch (id) {
    'sysinfo' => l.systemInfo,
    'clipboard' => l.clipboardHistory,
    'cleaner' => l.cleaner,
    'updater' => l.updater,
    'gds' => 'GDS',
    'rds' => 'RDS',
    _ => id,
  };

  String _errorMessage(AppLocalizations l, String error) => switch (error) {
    'unavailable' || 'unsupportedPlatform' => l.providerUnavailable,
    'busy' => l.rateError,
    'timeout' => l.moduleNetworkError,
    'cancelled' => l.moduleCancelled,
    'invalidInput' => l.moduleInputError,
    'invalidResponse' || 'invalidContract' => l.moduleResponseError,
    _ => l.providerFailed,
  };

  String _number(num? value, [String unit = '']) => value == null
      ? AppLocalizations.of(context)!.missingReading
      : '${NumberFormat.decimalPatternDigits(locale: Localizations.localeOf(context).toString(), decimalDigits: 1).format(value)}$unit';

  Widget _rows(List<(String, String)> values) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: values
        .map(
          (row) => Padding(
            padding: const EdgeInsets.symmetric(
              vertical: OpenNetworkSpacing.two,
            ),
            child: Wrap(
              spacing: OpenNetworkSpacing.four,
              children: [Text('${row.$1}:'), SelectableText(row.$2)],
            ),
          ),
        )
        .toList(),
  );

  Widget _resultView(AppLocalizations l) => switch (_result) {
    sysinfo.SystemSnapshot value => _rows([
      (l.cpuUsage, _number(value.cpu.usage, '%')),
      (l.cpuTemperature, _number(value.cpu.temp, ' °C')),
      (l.memoryUsage, _number(value.memory.used, '%')),
      (l.swapUsage, _number(value.memory.swap, '%')),
      (l.gpuUsage, _number(value.gpu.usage, '%')),
      (l.gpuMemory, _number(value.gpu.memory, '%')),
      (l.gpuTemperature, _number(value.gpu.temp, ' °C')),
      (l.diskRead, _number(value.disk.read?.toDouble(), ' B/s')),
      (l.diskWrite, _number(value.disk.write?.toDouble(), ' B/s')),
      (l.diskTemperature, _number(value.disk.temp, ' °C')),
      (l.networkReceive, _number(value.net.rx?.toDouble(), ' B/s')),
      (l.networkSend, _number(value.net.tx?.toDouble(), ' B/s')),
    ]),
    clipboard.Page value => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (value.items.isEmpty) Text(l.noRecords),
        for (final entry in value.items)
          ListTile(
            title: Text(
              entry.preview ?? entry.kind,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text('${entry.bytes} B · ${entry.mimes.join(', ')}'),
            trailing:
                entry.mimes.any(
                  (mime) =>
                      mime == 'text/plain' || mime.startsWith('text/plain;'),
                )
                ? IconButton(
                    tooltip: l.openText,
                    icon: const Icon(Icons.article_outlined),
                    onPressed: _busy
                        ? null
                        : () => _load(() async {
                            final mime = entry.mimes.firstWhere(
                              (mime) =>
                                  mime == 'text/plain' ||
                                  mime.startsWith('text/plain;'),
                            );
                            final bytes = await _agent!.clipboardContent(
                              entry: entry.id,
                              mime: mime,
                            );
                            return utf8.decode(
                              bytes.take(16_384).toList(),
                              allowMalformed: true,
                            );
                          }),
                  )
                : null,
          ),
        if (value.more && value.items.isNotEmpty)
          TextButton(
            onPressed: _busy
                ? null
                : () => _load(
                    () => _agent!.clipboardEntries(before: value.items.last.id),
                  ),
            child: Text(l.nextPage),
          ),
      ],
    ),
    cleaner.Diagnostics value => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _rows([
          (l.errors, '${value.errors}'),
          (l.warnings, '${value.warnings}'),
        ]),
        for (final check in value.checks)
          ListTile(
            title: Text(check.id),
            subtitle: Text(check.detail),
            trailing: Text(switch (check.state) {
              cleaner.CheckState.ok => l.checkOk,
              cleaner.CheckState.warning => l.checkWarning,
              cleaner.CheckState.error => l.checkError,
              cleaner.CheckState.info => l.checkInfo,
            }),
          ),
      ],
    ),
    cleaner.CleanerRunSummary value => _rows([
      (l.mode, value.dryRun ? l.preview : l.executed),
      (l.duration, '${value.durationMs} ms'),
      (
        l.freedBytes,
        value.freedBytes == null ? l.unavailable : '${value.freedBytes} B',
      ),
      (l.deleted, '${value.deleted}'),
      (l.skipped, '${value.skipped}'),
      (l.failed, '${value.failed}'),
    ]),
    updater.Plan value => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('${l.channel}: ${value.channel}'),
        if (value.actions.isEmpty) Text(l.noRecords),
        for (final action in value.actions)
          ListTile(
            title: Text(switch (native.updateActionKind(action: action)) {
              'gds_install' => l.gdsInstall,
              'verified_applications' => l.verifiedApplications,
              'apt_observe' => l.aptObserve,
              'toolchain_observe' => l.toolchainObserve,
              'homebrew' => 'Homebrew',
              'flatpak' => 'Flatpak',
              _ => l.unavailable,
            }),
            subtitle: Text(native.updateActionPlatform(action: action) ?? ''),
          ),
      ],
    ),
    updater.UpdateRunSummary value => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('${l.channel}: ${value.channel}'),
        if (value.results.isEmpty) Text(l.noRecords),
        for (final action in value.results)
          ListTile(
            title: Text(action.action),
            subtitle: Text(action.detail),
            trailing: Text(action.ok ? l.checkOk : l.checkError),
          ),
      ],
    ),
    gds.Status value => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _rows([(l.result, value.result), (l.exitClass, value.exitClass)]),
        if (value.status case final status?)
          _rows([
            (l.branch, status.branch.name ?? l.unavailable),
            (l.upstream, status.branch.upstream ?? l.unavailable),
            (l.aheadBehind, '${status.branch.ahead} / ${status.branch.behind}'),
            (l.staged, '${status.changes.staged}'),
            (l.unstaged, '${status.changes.unstaged}'),
            (l.untracked, '${status.changes.untracked}'),
            (l.conflicts, '${status.changes.conflicted}'),
            (l.remoteFreshness, status.remoteFreshness),
          ]),
        for (final finding in value.findings)
          ListTile(title: Text(finding.code), subtitle: Text(finding.message)),
      ],
    ),
    rds.RemoteSnapshot value => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (value.sessions.isEmpty) Text(l.noRecords),
        for (final session in value.sessions)
          ListTile(
            title: Text(session.peer),
            subtitle: Text(session.id),
            trailing: Text(
              session.status == rds.SessionState.connected
                  ? l.connected
                  : l.connecting,
            ),
          ),
      ],
    ),
    String value => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [Text(l.textPreviewLimit), SelectableText(value)],
    ),
    _ => const SizedBox.shrink(),
  };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final current = _modules
        .where((module) => module.id == _selected)
        .firstOrNull;
    Widget action(String label, Future<Object> Function() run, {Key? key}) =>
        FilledButton(
          key: key,
          onPressed: _busy || _agent == null ? null : () => _load(run),
          child: Text(label),
        );
    return Scaffold(
      appBar: AppBar(
        title: const OpenNetworkBrand(),
        toolbarHeight:
            OpenNetworkBrand.heightOf(context) + OpenNetworkSpacing.four,
        actions: [
          PopupMenuButton<String>(
            tooltip: 'English / Русский',
            onSelected: (value) => widget.onLocale(Locale(value)),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'en', child: Text('English')),
              PopupMenuItem(value: 'ru', child: Text('Русский')),
            ],
            icon: const Icon(Icons.language),
          ),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(OpenNetworkSpacing.six),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l.localReadOnly),
                  const SizedBox(height: OpenNetworkSpacing.four),
                  if (_modules.isNotEmpty)
                    DropdownButtonFormField<String>(
                      key: const Key('module-selector'),
                      isExpanded: true,
                      isDense: false,
                      itemHeight: null,
                      initialValue: _selected,
                      items: _modules
                          .map(
                            (module) => DropdownMenuItem(
                              value: module.id,
                              child: Text(_name(l, module.id)),
                            ),
                          )
                          .toList(),
                      onChanged: _busy
                          ? null
                          : (value) => setState(() {
                              _selected = value!;
                              _result = null;
                              _error = null;
                            }),
                      decoration: InputDecoration(labelText: l.module),
                    ),
                  if (current != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: OpenNetworkSpacing.four,
                      ),
                      child: Text(
                        '${_name(l, current.id)} · ${current.version} · ${!current.configured ? l.providerUnavailable : switch (current.reachability) {
                                native.Reachability.notChecked => l.notChecked,
                                native.Reachability.reachable => l.reachable,
                                native.Reachability.unavailable => l.providerUnavailable,
                                native.Reachability.failed => l.providerFailed,
                              }}${!current.configured || current.observedAtMs == null ? '' : ' · ${DateFormat.yMd(Localizations.localeOf(context).toString()).add_Hms().format(DateTime.fromMillisecondsSinceEpoch(current.observedAtMs!.toInt()))}'}',
                      ),
                    ),
                  if (_selected == 'gds')
                    Padding(
                      padding: const EdgeInsets.only(
                        bottom: OpenNetworkSpacing.four,
                      ),
                      child: TextField(
                        key: const Key('repository-path'),
                        controller: _repository,
                        enabled: !_busy,
                        decoration: InputDecoration(
                          labelText: l.repositoryPath,
                        ),
                      ),
                    ),
                  Wrap(
                    spacing: OpenNetworkSpacing.two,
                    runSpacing: OpenNetworkSpacing.two,
                    children: [
                      if (_selected == 'sysinfo')
                        action(
                          l.moduleRefresh,
                          () => _agent!.systemInfo(),
                          key: const Key('read-system-info'),
                        ),
                      if (_selected == 'clipboard')
                        action(
                          l.moduleRefresh,
                          () => _agent!.clipboardEntries(),
                        ),
                      if (_selected == 'cleaner') ...[
                        action(
                          l.moduleDiagnostics,
                          () => _agent!.cleanerDiagnostics(),
                        ),
                        action(l.preview, () => _agent!.cleanerPreview()),
                        action(l.lastRun, () => _agent!.cleanerLastRun()),
                      ],
                      if (_selected == 'updater') ...[
                        action(l.updatePlan, () => _agent!.updatePlan()),
                        action(l.lastRun, () => _agent!.updateLastRun()),
                      ],
                      if (_selected == 'gds')
                        action(
                          l.moduleRefresh,
                          () => _agent!.repositoryStatus(
                            path: _repository.text.trim(),
                          ),
                        ),
                      if (_selected == 'rds')
                        action(l.moduleRefresh, () => _agent!.remoteSessions()),
                      if (_busy && _agent != null)
                        TextButton(
                          onPressed: _cancelled ? null : _cancel,
                          child: Text(l.moduleCancel),
                        ),
                      if (_agent == null && !_busy)
                        TextButton(
                          onPressed: () {
                            setState(() => _busy = true);
                            _discover();
                          },
                          child: Text(l.moduleRefresh),
                        ),
                    ],
                  ),
                  if (_busy) const LinearProgressIndicator(),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: OpenNetworkSpacing.four,
                      ),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          _errorMessage(l, _error!),
                          key: const Key('module-error'),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: OpenNetworkSpacing.six),
                  _resultView(l),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
