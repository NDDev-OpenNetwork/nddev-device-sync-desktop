import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nddev_opennetwork_design_system/opennetwork_design_system.dart';
import 'package:nds_native/nds_native.dart' as native;
import 'package:url_launcher/url_launcher.dart';

import 'l10n/app_localizations.dart';
import 'modules_screen.dart';
import 'diagnostics.dart';

Future<void> runNdsApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  final diagnostics = ApplicationDiagnostics();
  var nativeReady = false;
  try {
    await native.RustLib.init();
    diagnostics.nativeInitialized();
    nativeReady = true;
  } catch (_) {
    diagnostics.reportFailure(native.FailureKind.nativeBridge);
  }
  runApp(NdsApp(diagnostics: diagnostics, nativeReady: nativeReady));
}

class NdsApp extends StatefulWidget {
  const NdsApp({super.key, this.diagnostics, this.nativeReady = true});
  final ApplicationDiagnostics? diagnostics;
  final bool nativeReady;
  @override
  State<NdsApp> createState() => _NdsAppState();
}

class _NdsAppState extends State<NdsApp> {
  Locale? _locale;
  int _page = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.nativeReady) widget.diagnostics?.clientReady();
    });
  }

  @override
  void dispose() {
    widget.diagnostics?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => MaterialApp(
      title: 'NDDev OpenNetwork',
      debugShowCheckedModeBanner: false,
      theme: OpenNetworkTheme.dark(width: constraints.maxWidth),
      locale: _locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          widget.diagnostics?.locale = Localizations.localeOf(context);
          if (!widget.nativeReady) {
            return Scaffold(
              appBar: AppBar(
                title: const OpenNetworkBrand(),
                toolbarHeight:
                    OpenNetworkBrand.heightOf(context) +
                    OpenNetworkSpacing.four,
              ),
              body: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(OpenNetworkSpacing.six),
                  child: Text(AppLocalizations.of(context)!.startupFailed),
                ),
              ),
            );
          }
          final identity = _IdentityScreen(
            onLocale: (locale) => setState(() => _locale = locale),
            diagnostics: widget.diagnostics,
          );
          if (!native.supportsLocalAgent()) return identity;
          final l = AppLocalizations.of(context)!;
          return Scaffold(
            body: IndexedStack(
              index: _page,
              children: [
                identity,
                ModulesScreen(
                  onLocale: (locale) => setState(() => _locale = locale),
                  diagnostics: widget.diagnostics,
                ),
              ],
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _page,
              onDestinationSelected: (page) => setState(() => _page = page),
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.account_circle_outlined),
                  label: l.sessionTab,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.devices),
                  label: l.localModules,
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}

class _IdentityScreen extends StatefulWidget {
  const _IdentityScreen({required this.onLocale, this.diagnostics});
  final ValueChanged<Locale> onLocale;
  final ApplicationDiagnostics? diagnostics;
  @override
  State<_IdentityScreen> createState() => _IdentityScreenState();
}

class _IdentityScreenState extends State<_IdentityScreen>
    with WidgetsBindingObserver {
  final _endpoint = TextEditingController(
    text: const String.fromEnvironment('NDS_SERVER_URL'),
  );
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _deviceName = TextEditingController(
    text: const String.fromEnvironment('NDS_DEVICE_NAME'),
  );
  native.NdsClient? _client;
  native.View? _view;
  bool _busy = false;
  int _actionEpoch = 0;
  bool _paused = false;
  bool _browserOpened = false;
  String? _error;
  Timer? _poll;
  Timer? _clock;
  native.DebugScope _debugScope = native.DebugScope.http;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !_paused) {
        setState(() => _view = _client?.snapshot());
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _paused = state != AppLifecycleState.resumed;
    if (_paused) {
      _poll?.cancel();
    } else {
      _schedulePoll();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clock?.cancel();
    _poll?.cancel();
    _client?.cancel();
    _client?.dispose();
    _endpoint.dispose();
    _email.dispose();
    _code.clear();
    _code.dispose();
    _deviceName.dispose();
    super.dispose();
  }

  String get _locale => Localizations.localeOf(context).languageCode;

  Future<void> _run(Future<native.View> Function() action) async {
    if (_busy) return;
    final epoch = _actionEpoch;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      var view = await action();
      if (view.authenticated &&
          view.sessionVerified &&
          view.devicesCheckedAt == 0) {
        view = await _client!.refreshDevices();
      }
      if (!mounted || epoch != _actionEpoch) return;
      setState(() => _view = view);
      if (view.authenticated) _code.clear();
    } catch (error) {
      var code = 'unexpected';
      if (error is native.ClientError) {
        code = await error.code();
        error.dispose();
      } else {
        widget.diagnostics?.reportFailure(native.FailureKind.nativeBridge);
      }
      if (mounted && epoch == _actionEpoch) {
        setState(() {
          _error = code;
          _view = _client?.snapshot();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _view = _client?.snapshot();
        });
        _schedulePoll();
      }
    }
  }

  Future<void> _connect() => _run(() async {
    _client?.cancel();
    _client?.dispose();
    _client = null;
    _view = null;
    final epoch = _actionEpoch;
    final client = await native.NdsClient.newInstance(
      endpoint: _endpoint.text.trim(),
    );
    if (!mounted || epoch != _actionEpoch) {
      client.cancel();
      client.dispose();
      throw StateError('cancelled');
    }
    _client = client;
    return client.refresh();
  });

  void _schedulePoll() {
    _poll?.cancel();
    if (!_browserOpened ||
        _paused ||
        _busy ||
        _view?.flow != 'github' ||
        _view!.expiresInSeconds == 0) {
      return;
    }
    _poll = Timer(Duration(seconds: _view!.retryAfterSeconds.clamp(1, 30)), () {
      if (mounted && !_paused && _client != null) {
        _run(() => _client!.pollGithub());
      }
    });
  }

  Future<void> _startGithub() {
    _browserOpened = false;
    _poll?.cancel();
    return _run(() => _client!.startGithub(locale: _locale));
  }

  Future<void> _openGithub() async {
    final epoch = _actionEpoch;
    final uri = Uri.tryParse(_view?.authorizationUrl ?? '');
    // Defense in depth for the only externally launched authorization URL.
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'github.com' ||
        uri.path != '/login/oauth/authorize' ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        uri.port != 443) {
      setState(() => _error = 'invalid_response');
      return;
    }
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError('unavailable');
      }
      if (!mounted || epoch != _actionEpoch) return;
      _browserOpened = true;
      _schedulePoll();
    } catch (_) {
      widget.diagnostics?.reportFailure(native.FailureKind.nativeBridge);
      if (mounted) setState(() => _error = 'browser_unavailable');
    }
  }

  void _cancel() {
    _actionEpoch++;
    _poll?.cancel();
    _browserOpened = false;
    _client?.cancel();
    _code.clear();
    setState(() {
      _view = _client?.snapshot();
      _error = 'cancelled';
    });
  }

  String _message(AppLocalizations l, String code) => switch (code) {
    'invalid_endpoint' => l.endpointError,
    'invalid_input' => l.inputError,
    'credential_store_unavailable' => l.storeError,
    'credential_revalidation_required' => l.revalidationRequired,
    'transport_unavailable' ||
    'request_timeout' ||
    'dependency_unavailable' => l.networkError,
    'authentication_failed' || 'authorization_denied' => l.authError,
    'device_revoked' => l.deviceRevokedHelp,
    'challenge_expired' => l.expiredError,
    'rate_limited' || 'server_busy' || 'busy' => l.rateError,
    'cancelled' => l.cancelledError,
    'invalid_response' => l.responseError,
    'browser_unavailable' => l.launchError,
    'method_unavailable' => l.unavailable,
    'diagnostics_unavailable' => l.diagnosticsUnavailable,
    _ => l.genericError,
  };

  String _date(String value) {
    final date = DateTime.tryParse(value)?.toLocal();
    if (date == null) return value;
    final format = MaterialLocalizations.of(context);
    return '${format.formatShortDate(date)} ${format.formatTimeOfDay(TimeOfDay.fromDateTime(date))}';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final v = _view;
    final diagnostics = native.clientDiagnostics();
    return Scaffold(
      appBar: AppBar(
        title: const OpenNetworkBrand(),
        toolbarHeight:
            OpenNetworkBrand.heightOf(context) + OpenNetworkSpacing.four,
        actions: [
          PopupMenuButton<String>(
            tooltip: 'English / Русский',
            onSelected: (language) => widget.onLocale(Locale(language)),
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
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    v?.authenticated == true
                        ? l.sessionTitle
                        : _client == null || v?.serverVersion.isEmpty != false
                        ? l.connectTitle
                        : l.signIn,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: OpenNetworkSpacing.six),
                  if (_client == null || v?.serverVersion.isEmpty != false) ...[
                    Text(l.connectHelp),
                    const SizedBox(height: OpenNetworkSpacing.four),
                    TextField(
                      key: const Key('server-address'),
                      controller: _endpoint,
                      enabled: !_busy,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: l.serverAddress,
                        hintText: 'https://server.example',
                      ),
                      onSubmitted: (_) {
                        if (!_busy) _connect();
                      },
                    ),
                    const SizedBox(height: OpenNetworkSpacing.four),
                    FilledButton(
                      key: const Key('connect'),
                      onPressed: _busy ? null : _connect,
                      child: Text(l.connect),
                    ),
                  ] else if (v!.credentialRevalidationRequired ||
                      !v.credentialStoreReady) ...[
                    Text(
                      v.credentialRevalidationRequired
                          ? l.revalidationRequired
                          : l.storeError,
                    ),
                    const SizedBox(height: OpenNetworkSpacing.four),
                    FilledButton(
                      key: const Key('refresh'),
                      onPressed: _busy
                          ? null
                          : () => _run(() => _client!.refresh()),
                      child: Text(l.refresh),
                    ),
                  ] else if (v.authenticated) ...[
                    if (!v.sessionVerified) ...[
                      Text(l.unverified),
                      const SizedBox(height: OpenNetworkSpacing.four),
                    ],
                    SelectableText(
                      '${l.instance}: ${_endpoint.text}\n${l.user}: ${v.userId}\n${l.method}: ${v.authMethod == 'email_otp' ? l.emailMethod : l.github}\n${l.expires}: ${_date(v.expiresAt)}',
                    ),
                    const SizedBox(height: OpenNetworkSpacing.four),
                    Text(
                      '${l.verified}: ${_date(DateTime.fromMillisecondsSinceEpoch(v.sessionCheckedAt.toInt() * 1000, isUtc: true).toIso8601String())}',
                    ),
                    const SizedBox(height: OpenNetworkSpacing.six),
                    Text(
                      l.devicesTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(l.devicesHelp),
                    const SizedBox(height: OpenNetworkSpacing.four),
                    if (v.devicesCheckedAt == 0) Text(l.devicesUnverified),
                    if (v.currentDeviceId.isEmpty) ...[
                      TextField(
                        key: const Key('device-name'),
                        controller: _deviceName,
                        enabled: !_busy && v.sessionVerified,
                        maxLength: 128,
                        decoration: InputDecoration(labelText: l.deviceName),
                      ),
                      FilledButton(
                        key: const Key('enroll-device'),
                        onPressed: _busy || !v.sessionVerified
                            ? null
                            : () => _run(
                                () => _client!.enrollDevice(
                                  name: _deviceName.text.trim(),
                                ),
                              ),
                        child: Text(l.enrollDevice),
                      ),
                    ],
                    for (final device in v.devices)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(
                            OpenNetworkSpacing.four,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                device.displayName,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                '${device.platform} · ${device.revoked ? l.deviceRevoked : l.deviceActive}',
                              ),
                              if (device.isCurrent) Text(l.thisDevice),
                              Text(
                                '${l.deviceCreated}: ${_date(device.createdAt)}',
                              ),
                              if (device.revoked && device.isCurrent)
                                Text(l.deviceRevokedHelp),
                              if (!device.revoked)
                                TextButton(
                                  key: Key('revoke-device-${device.deviceId}'),
                                  onPressed: _busy || !v.sessionVerified
                                      ? null
                                      : () async {
                                          final confirmed =
                                              await showDialog<bool>(
                                                context: context,
                                                builder: (context) =>
                                                    AlertDialog(
                                                      title: Text(
                                                        l.revokeDevice,
                                                      ),
                                                      content: Text(
                                                        l.revokeDeviceHelp(
                                                          device.displayName,
                                                        ),
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                context,
                                                                false,
                                                              ),
                                                          child: Text(
                                                            l.keepDevice,
                                                          ),
                                                        ),
                                                        FilledButton(
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                context,
                                                                true,
                                                              ),
                                                          child: Text(
                                                            l.revokeDevice,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                              );
                                          if (confirmed == true && mounted) {
                                            await _run(
                                              () => _client!.revokeDevice(
                                                id: device.deviceId,
                                              ),
                                            );
                                          }
                                        },
                                  child: Text(l.revokeDevice),
                                ),
                            ],
                          ),
                        ),
                      ),
                    TextButton(
                      key: const Key('refresh-devices'),
                      onPressed: _busy || !v.sessionVerified
                          ? null
                          : () => _run(() => _client!.refreshDevices()),
                      child: Text(l.refreshDevices),
                    ),
                    const SizedBox(height: OpenNetworkSpacing.four),
                    OutlinedButton(
                      key: const Key('refresh'),
                      onPressed: _busy
                          ? null
                          : () => _run(() => _client!.refresh()),
                      child: Text(l.refresh),
                    ),
                    FilledButton(
                      key: const Key('logout'),
                      onPressed: _busy
                          ? null
                          : () => _run(() => _client!.logout()),
                      child: Text(l.logout),
                    ),
                  ] else if (v.flow == 'github') ...[
                    Text(l.githubHelp),
                    const SizedBox(height: OpenNetworkSpacing.four),
                    SelectableText(
                      v.verificationCode,
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    Text(l.validFor(v.expiresInSeconds)),
                    const SizedBox(height: OpenNetworkSpacing.four),
                    FilledButton(
                      onPressed: _busy ? null : _openGithub,
                      child: Text(l.openGithub),
                    ),
                    if (_browserOpened) Text(l.awaitApproval),
                    TextButton(onPressed: _cancel, child: Text(l.cancel)),
                  ] else ...[
                    TextField(
                      key: const Key('email'),
                      controller: _email,
                      enabled: !_busy && v.emailAvailable,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      autofillHints: const [AutofillHints.email],
                      decoration: InputDecoration(labelText: l.email),
                    ),
                    const SizedBox(height: OpenNetworkSpacing.four),
                    if (v.flow == 'email') ...[
                      Text(l.emailHint),
                      const SizedBox(height: OpenNetworkSpacing.four),
                      TextField(
                        key: const Key('otp'),
                        controller: _code,
                        enabled: !_busy,
                        keyboardType: TextInputType.number,
                        obscureText: true,
                        maxLength: 8,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        autofillHints: const [AutofillHints.oneTimeCode],
                        decoration: InputDecoration(labelText: l.code),
                        onSubmitted: (_) {
                          if (!_busy) {
                            _run(() => _client!.verifyEmail(code: _code.text));
                          }
                        },
                      ),
                      FilledButton(
                        key: const Key('verify'),
                        onPressed: _busy
                            ? null
                            : () => _run(
                                () => _client!.verifyEmail(code: _code.text),
                              ),
                        child: Text(l.verify),
                      ),
                      Text(l.validFor(v.expiresInSeconds)),
                      if (v.retryAfterSeconds > 0)
                        Text(l.retryIn(v.retryAfterSeconds)),
                    ],
                    FilledButton(
                      key: const Key('send-code'),
                      onPressed:
                          _busy || !v.emailAvailable || v.retryAfterSeconds > 0
                          ? null
                          : () => _run(
                              () => _client!.requestEmail(
                                email: _email.text.trim(),
                                locale: _locale,
                              ),
                            ),
                      child: Text(v.flow == 'email' ? l.resend : l.sendCode),
                    ),
                    if (!v.emailAvailable) Text(l.unavailable),
                    const SizedBox(height: OpenNetworkSpacing.four),
                    OutlinedButton(
                      key: const Key('github'),
                      onPressed: _busy || !v.githubAvailable
                          ? null
                          : _startGithub,
                      child: Text(l.github),
                    ),
                    if (!v.githubAvailable) Text(l.unavailable),
                    if (v.flow.isNotEmpty)
                      TextButton(onPressed: _cancel, child: Text(l.cancel)),
                  ],
                  if (_busy) ...[
                    const SizedBox(height: OpenNetworkSpacing.four),
                    Semantics(
                      label: l.working,
                      child: const LinearProgressIndicator(),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: OpenNetworkSpacing.four),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _message(l, _error!),
                        key: const Key('auth-error'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: OpenNetworkSpacing.six),
                  if (_client != null) ...[
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () {
                              _poll?.cancel();
                              _client!.cancel();
                              _client!.dispose();
                              _client = null;
                              _browserOpened = false;
                              _code.clear();
                              setState(() {
                                _view = null;
                                _error = null;
                              });
                            },
                      child: Text(l.changeServer),
                    ),
                  ],
                  if (diagnostics.sinkInitialized) ...[
                    DropdownButton<native.DebugScope>(
                      isExpanded: true,
                      isDense: false,
                      itemHeight: null,
                      value: diagnostics.debugScope ?? _debugScope,
                      items: [
                        DropdownMenuItem(
                          value: native.DebugScope.http,
                          child: Text(l.diagnosticsHttp),
                        ),
                        DropdownMenuItem(
                          value: native.DebugScope.io,
                          child: Text(l.diagnosticsIo),
                        ),
                      ],
                      onChanged: diagnostics.debugEnabled
                          ? null
                          : (scope) {
                              if (scope != null) {
                                setState(() => _debugScope = scope);
                              }
                            },
                    ),
                    TextButton(
                      onPressed: () {
                        try {
                          native.configureDebug(
                            scope: _debugScope,
                            seconds: diagnostics.debugEnabled ? 0 : 300,
                          );
                        } catch (_) {
                          widget.diagnostics?.reportFailure(
                            native.FailureKind.nativeBridge,
                          );
                          setState(() => _error = 'diagnostics_unavailable');
                        }
                        setState(() {});
                      },
                      child: Text(
                        diagnostics.debugEnabled
                            ? l.diagnosticsOff
                            : l.diagnostics,
                      ),
                    ),
                  ],
                  Text(
                    diagnostics.sinkInitialized &&
                            widget.diagnostics?.reportingUnavailable != true
                        ? l.localDiagnosticsOnly
                        : l.diagnosticsUnavailable,
                    key: const Key('diagnostics-status'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (diagnostics.sinkInitialized &&
                      ((diagnostics.droppedEvents ?? BigInt.zero) >
                              BigInt.zero ||
                          (diagnostics.writeFailures ?? BigInt.zero) >
                              BigInt.zero ||
                          (diagnostics.rejectedFieldsOrEvents ?? BigInt.zero) >
                              BigInt.zero))
                    Text(
                      l.diagnosticsDegraded(
                        '${diagnostics.rejectedFieldsOrEvents}',
                        '${diagnostics.droppedEvents}',
                        '${diagnostics.writeFailures}',
                        '${diagnostics.pendingEvents}',
                      ),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  Text(l.privacy, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: OpenNetworkSpacing.four),
                  TextButton(
                    onPressed: () => launchUrl(
                      Uri.parse('https://nddev.ai'),
                      mode: LaunchMode.externalApplication,
                    ),
                    child: const Text('NDDev OpenNetwork · nddev.ai'),
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
