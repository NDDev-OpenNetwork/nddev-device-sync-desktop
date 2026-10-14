import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nddev_opennetwork_design_system/opennetwork_design_system.dart';
import 'package:nds_native/nds_native.dart' as native;

import 'activity.dart';
import 'l10n/app_localizations.dart';

class RepositoriesScreen extends StatefulWidget {
  const RepositoriesScreen({super.key, required this.client});
  final native.NdsClient client;

  @override
  State<RepositoriesScreen> createState() => _RepositoriesScreenState();
}

class _RepositoriesScreenState extends State<RepositoriesScreen> {
  List<native.GithubCredentialReference> _credentials = [];
  native.GithubCredentialReference? _selected;
  native.GithubRepositoryPageView? _page;
  String _nextCredential = '';
  bool _moreCredentials = false;
  bool _credentialsLoaded = false;
  bool _busy = false;
  native.GithubCatalogError? _error;
  int _actionEpoch = 0;
  bool get _paused => !ApplicationActivityScope.read(context).value;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_paused) unawaited(_loadCredentials());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    ApplicationActivityScope.of(context);
    if (_paused) {
      _actionEpoch++;
      _stopCatalog();
      _page = null;
      _selected = null;
      _credentials = [];
      _moreCredentials = false;
      _credentialsLoaded = false;
    }
  }

  @override
  void dispose() {
    _actionEpoch++;
    _stopCatalog();
    super.dispose();
  }

  Future<void> _run(Future<void> Function(int epoch) action) async {
    if (_busy || _paused) return;
    final epoch = ++_actionEpoch;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action(epoch);
    } on native.GithubCatalogError catch (error) {
      if (mounted && epoch == _actionEpoch && !_paused) {
        setState(() {
          _error = error;
          _page = null;
        });
      }
    } catch (_) {
      native.recordClientFailure(kind: native.FailureKind.nativeBridge);
      if (mounted && epoch == _actionEpoch && !_paused) {
        setState(() {
          _error = native.GithubCatalogError.unavailable;
          _page = null;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadCredentials({bool next = false}) => _run((epoch) async {
    final result = await widget.client.githubCatalogCredentials(
      after: next ? _nextCredential : '',
    );
    if (!mounted || epoch != _actionEpoch || _paused) return;
    setState(() {
      _credentials = result.items;
      _credentialsLoaded = true;
      _nextCredential = result.nextAfter;
      _moreCredentials = result.hasMore;
    });
  });

  void _select(native.GithubCredentialReference record) {
    _actionEpoch++;
    setState(() {
      _page = null;
      _error = null;
      _selected = null;
    });
    try {
      widget.client.selectGithubCredential(
        recordRef: record.recordRef,
        revision: record.revision,
        pendingId: record.pendingId,
      );
      setState(() => _selected = record);
    } on native.GithubCatalogError catch (error) {
      setState(() => _error = error);
    } catch (_) {
      native.recordClientFailure(kind: native.FailureKind.nativeBridge);
      setState(() => _error = native.GithubCatalogError.unavailable);
    }
  }

  void _cancel() {
    _actionEpoch++;
    _stopCatalog();
    setState(() {
      _page = null;
      _error = native.GithubCatalogError.cancelled;
    });
  }

  void _stopCatalog() {
    try {
      widget.client.cancelGithubCatalog();
    } catch (_) {
      // The session owner may already have disposed this opaque client.
    }
  }

  Future<void> _loadPage({bool next = false}) => _run((epoch) async {
    setState(() => _page = null);
    final page = await widget.client.githubRepositoryPage(nextPage: next);
    if (!mounted || epoch != _actionEpoch || _paused) return;
    setState(() => _page = page);
  });

  String _errorText(AppLocalizations l, native.GithubCatalogError error) =>
      switch (error) {
        native.GithubCatalogError.authorizationRequired => l.catalogSignIn,
        native.GithubCatalogError.credentialChanged =>
          l.catalogCredentialChanged,
        native.GithubCatalogError.busy => l.operationBusy,
        native.GithubCatalogError.cancelled => l.catalogCancelled,
        native.GithubCatalogError.timeout => l.catalogTimeout,
        native.GithubCatalogError.invalidInput => l.catalogChooseCredential,
        native.GithubCatalogError.invalidResponse => l.catalogInvalidResponse,
        native.GithubCatalogError.providerFailed => l.catalogProviderFailed,
        native.GithubCatalogError.unavailable => l.catalogUnavailable,
      };

  String _observed(AppLocalizations l, String milliseconds) {
    final value = int.tryParse(milliseconds);
    if (value == null) return l.catalogObservationUnknown;
    try {
      return l.catalogObserved(
        DateFormat.yMd(Localizations.localeOf(context).toLanguageTag())
            .add_Hms()
            .format(DateTime.fromMillisecondsSinceEpoch(value).toLocal()),
      );
    } catch (_) {
      return l.catalogObservationUnknown;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final page = _page;
    final choices = [..._credentials];
    if (_selected != null &&
        !choices.any((item) => item.recordRef == _selected!.recordRef)) {
      choices.insert(0, _selected!);
    }
    return Scaffold(
      appBar: AppBar(title: Text(l.catalogTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(OpenNetworkSpacing.six),
          children: [
            Text(l.catalogHelp),
            const SizedBox(height: OpenNetworkSpacing.four),
            DropdownButtonFormField<String>(
              key: ValueKey(_selected?.recordRef),
              initialValue: _selected?.recordRef,
              isExpanded: true,
              decoration: InputDecoration(labelText: l.catalogCredential),
              items: choices
                  .map(
                    (record) => DropdownMenuItem(
                      value: record.recordRef,
                      child: Text(
                        record.title.isEmpty ? record.recordRef : record.title,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: _paused
                  ? null
                  : (id) {
                      if (id != null) {
                        _select(choices.firstWhere((r) => r.recordRef == id));
                      }
                    },
            ),
            if (_selected?.username.isNotEmpty == true)
              Text(_selected!.username),
            Wrap(
              spacing: OpenNetworkSpacing.two,
              children: [
                TextButton(
                  onPressed: _busy || _paused ? null : _loadCredentials,
                  child: Text(l.catalogRefreshCredentials),
                ),
                if (_moreCredentials)
                  TextButton(
                    onPressed: _busy || _paused
                        ? null
                        : () => _loadCredentials(next: true),
                    child: Text(l.catalogMoreCredentials),
                  ),
              ],
            ),
            if (_credentialsLoaded &&
                _credentials.isEmpty &&
                !_busy &&
                _error == null)
              Text(l.catalogNoCredentials),
            const SizedBox(height: OpenNetworkSpacing.four),
            Wrap(
              spacing: OpenNetworkSpacing.two,
              children: [
                FilledButton(
                  key: const Key('catalog-read'),
                  onPressed: _busy || _paused || _selected == null
                      ? null
                      : _loadPage,
                  child: Text(l.catalogRead),
                ),
                if (page?.continuation ==
                    native.GithubCatalogContinuationView.more)
                  OutlinedButton(
                    key: const Key('catalog-next'),
                    onPressed: _busy || _paused
                        ? null
                        : () => _loadPage(next: true),
                    child: Text(l.catalogNextPage),
                  ),
                if (_busy)
                  TextButton(onPressed: _cancel, child: Text(l.actionCancel)),
              ],
            ),
            if (_busy) const LinearProgressIndicator(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: OpenNetworkSpacing.four,
                ),
                child: Text(_errorText(l, _error!)),
              ),
            if (_paused) Text(l.catalogPaused),
            if (page != null) ...[
              const SizedBox(height: OpenNetworkSpacing.six),
              Text(l.catalogPrincipal(page.principal.login)),
              Text(_observed(l, page.observedAtMs)),
              Text(l.catalogPageScope),
              if (page.groups.isEmpty) Text(l.catalogEmptyPage),
              for (final group in page.groups)
                Card(
                  key: ValueKey('catalog-owner-${group.owner.id}'),
                  child: Padding(
                    padding: const EdgeInsets.all(OpenNetworkSpacing.four),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.owner.login,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          group.owner.kind ==
                                  native.GithubOwnerKindView.organization
                              ? l.catalogOrganization
                              : l.catalogPersonal,
                        ),
                        for (final repository in group.repositories)
                          ListTile(
                            key: ValueKey(
                              'catalog-repository-${repository.id}',
                            ),
                            contentPadding: EdgeInsets.zero,
                            title: Text(repository.name),
                            subtitle: Text(
                              [
                                switch (repository.visibility) {
                                  native
                                      .GithubRepositoryVisibilityView
                                      .public =>
                                    l.catalogPublic,
                                  native
                                      .GithubRepositoryVisibilityView
                                      .private =>
                                    l.catalogPrivate,
                                  native
                                      .GithubRepositoryVisibilityView
                                      .internal =>
                                    l.catalogInternal,
                                },
                                if (repository.archived) l.catalogArchived,
                                if (repository.defaultBranch != null)
                                  repository.defaultBranch!,
                              ].join(' · '),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              Text(switch (page.continuation) {
                native.GithubCatalogContinuationView.more => l.catalogHasMore,
                native.GithubCatalogContinuationView.endOfAccessScope =>
                  l.catalogAccessEnd,
                native.GithubCatalogContinuationView.limitReached =>
                  l.catalogLimitReached,
              }),
            ],
          ],
        ),
      ),
    );
  }
}
