// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'NDDev OpenNetwork';

  @override
  String get connectTitle => 'Connect to NDS';

  @override
  String get connectHelp =>
      'Enter the HTTPS address of your self-hosted NDS server.';

  @override
  String get serverAddress => 'Server address';

  @override
  String get connect => 'Connect';

  @override
  String get signIn => 'Sign in';

  @override
  String get email => 'Email address';

  @override
  String get sendCode => 'Send sign-in code';

  @override
  String get emailHint =>
      'If this address is permitted, a sign-in code will arrive.';

  @override
  String get code => 'Eight-digit code';

  @override
  String get verify => 'Verify code';

  @override
  String get resend => 'Send another code';

  @override
  String get github => 'Sign in with GitHub';

  @override
  String get githubHelp =>
      'Compare this code with the NDS approval page in your browser. Approve only when both codes match.';

  @override
  String get openGithub => 'Open GitHub';

  @override
  String get awaitApproval => 'Waiting for explicit browser approval';

  @override
  String get cancel => 'Cancel sign-in';

  @override
  String get unavailable => 'Unavailable on this server';

  @override
  String get sessionTitle => 'Your NDS session';

  @override
  String get user => 'User';

  @override
  String get instance => 'Server';

  @override
  String get method => 'Sign-in method';

  @override
  String get expires => 'Expires';

  @override
  String get verified => 'Last verified';

  @override
  String get unverified =>
      'This session has not been revalidated. Check the server connection.';

  @override
  String get refresh => 'Revalidate session';

  @override
  String get logout => 'Revoke session and sign out';

  @override
  String get changeServer => 'Change server';

  @override
  String get diagnostics => 'Diagnostic logs for five minutes';

  @override
  String get diagnosticsOff => 'Stop diagnostic logs';

  @override
  String get privacy =>
      'Session secrets stay in native secure storage. Sign-in does not recover vault keys.';

  @override
  String get endpointError =>
      'Use an HTTPS server origin without credentials, path, query or fragment.';

  @override
  String get inputError => 'Check the email address and the eight-digit code.';

  @override
  String get networkError =>
      'The server could not be reached. No fresh session state is confirmed.';

  @override
  String get storeError =>
      'The native credential store is unavailable. No plaintext fallback is used.';

  @override
  String get authError =>
      'Sign-in could not be confirmed. Check the code or start again.';

  @override
  String get expiredError => 'This sign-in attempt expired. Start again.';

  @override
  String get rateError => 'Please wait before trying again.';

  @override
  String get cancelledError => 'Sign-in cancelled.';

  @override
  String get responseError =>
      'The server response does not match the NDS contract.';

  @override
  String get genericError => 'The operation failed. Try again.';

  @override
  String get launchError => 'The authorization browser could not be opened.';

  @override
  String get working => 'Working…';

  @override
  String validFor(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: 'Valid for $seconds seconds',
      one: 'Valid for $seconds second',
    );
    return '$_temp0';
  }

  @override
  String retryIn(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: 'Retry in $seconds seconds',
      one: 'Retry in $seconds second',
    );
    return '$_temp0';
  }

  @override
  String get revalidationRequired =>
      'The credential write may have completed. Revalidate the session before continuing.';

  @override
  String get emailMethod => 'Email code';

  @override
  String get sessionTab => 'NDS session';

  @override
  String get localModules => 'Local modules';

  @override
  String get localReadOnly =>
      'Inspect local tools, history and planned maintenance. Tools retain control of their data.';

  @override
  String get module => 'Module';

  @override
  String get systemInfo => 'System information';

  @override
  String get clipboardHistory => 'Clipboard history';

  @override
  String get cleaner => 'Cleaner';

  @override
  String get updater => 'Updates';

  @override
  String get providerUnavailable => 'The local tool is unavailable.';

  @override
  String get providerFailed =>
      'The local tool could not complete this request.';

  @override
  String get notChecked => 'Not checked';

  @override
  String get reachable => 'Available';

  @override
  String get noRecords => 'No records.';

  @override
  String get nextPage => 'Next page';

  @override
  String get openText => 'Read text';

  @override
  String get cpuUsage => 'CPU usage';

  @override
  String get cpuTemperature => 'CPU temperature';

  @override
  String get memoryUsage => 'Memory used';

  @override
  String get swapUsage => 'Swap used';

  @override
  String get gpuUsage => 'GPU usage';

  @override
  String get gpuMemory => 'GPU memory used';

  @override
  String get gpuTemperature => 'GPU temperature';

  @override
  String get diskRead => 'Disk read rate';

  @override
  String get diskWrite => 'Disk write rate';

  @override
  String get diskTemperature => 'Disk temperature';

  @override
  String get networkReceive => 'Network receive rate';

  @override
  String get networkSend => 'Network send rate';

  @override
  String get errors => 'Errors';

  @override
  String get warnings => 'Warnings';

  @override
  String get checkOk => 'OK';

  @override
  String get checkWarning => 'Warning';

  @override
  String get checkError => 'Error';

  @override
  String get checkInfo => 'Information';

  @override
  String get mode => 'Mode';

  @override
  String get preview => 'Preview';

  @override
  String get executed => 'Executed';

  @override
  String get duration => 'Duration';

  @override
  String get freedBytes => 'Reclaimed space';

  @override
  String get deleted => 'Deleted entries';

  @override
  String get skipped => 'Skipped entries';

  @override
  String get failed => 'Failed entries';

  @override
  String get channel => 'Channel';

  @override
  String get result => 'Result';

  @override
  String get exitClass => 'Exit classification';

  @override
  String get branch => 'Branch';

  @override
  String get upstream => 'Upstream';

  @override
  String get aheadBehind => 'Ahead / behind';

  @override
  String get staged => 'Staged changes';

  @override
  String get unstaged => 'Unstaged changes';

  @override
  String get untracked => 'Untracked files';

  @override
  String get conflicts => 'Conflicts';

  @override
  String get remoteFreshness => 'Remote data freshness';

  @override
  String get repositoryPath => 'Absolute repository path';

  @override
  String get lastRun => 'Last run';

  @override
  String get updatePlan => 'Update plan';

  @override
  String get moduleRefresh => 'Refresh';

  @override
  String get moduleCancel => 'Cancel request';

  @override
  String get moduleDiagnostics => 'Diagnostics';

  @override
  String get moduleInputError => 'Check the repository path or selected entry.';

  @override
  String get moduleNetworkError => 'The local tool did not respond in time.';

  @override
  String get moduleResponseError =>
      'The local tool returned an unsupported response.';

  @override
  String get moduleCancelled => 'Request cancelled.';

  @override
  String get missingReading => 'No reading';

  @override
  String get textPreviewLimit => 'Text preview, up to 16 KiB.';

  @override
  String get gdsInstall => 'GDS installation';

  @override
  String get verifiedApplications => 'Verified applications';

  @override
  String get aptObserve => 'APT package observation';

  @override
  String get toolchainObserve => 'Toolchain observation';

  @override
  String get connected => 'Connected';

  @override
  String get connecting => 'Connecting';

  @override
  String get diagnosticsUnavailable =>
      'Local diagnostics are unavailable. Sign-in can continue.';

  @override
  String get localDiagnosticsOnly =>
      'Local diagnostics are initialized; external delivery is not configured.';

  @override
  String diagnosticsDegraded(
    String rejected,
    String dropped,
    String failures,
    String pending,
  ) {
    return 'Diagnostics: rejected $rejected, dropped $dropped, write failures $failures, pending $pending.';
  }

  @override
  String get startupFailed =>
      'NDS could not start. Restart the application. If this continues, check the installation and local diagnostics.';

  @override
  String get diagnosticsHttp => 'Network diagnostics';

  @override
  String get diagnosticsIo => 'Local operations';

  @override
  String get devicesTitle => 'Your devices';

  @override
  String get devicesHelp =>
      'Register this installation with its own native signing key. Device enrollment does not unlock the vault.';

  @override
  String get devicesUnverified =>
      'Device inventory has not been freshly verified.';

  @override
  String get deviceName => 'Device name';

  @override
  String get enrollDevice => 'Register this device';

  @override
  String get refreshDevices => 'Refresh devices';

  @override
  String get thisDevice => 'This installation';

  @override
  String get deviceActive => 'Active';

  @override
  String get deviceRevoked => 'Revoked';

  @override
  String get deviceCreated => 'Registered';

  @override
  String get deviceRevokedHelp =>
      'This device key has been revoked. It is retained locally and cannot be reused for enrollment.';

  @override
  String get revokeDevice => 'Revoke device';

  @override
  String revokeDeviceHelp(String name) {
    return 'Revoke access for $name? This identity cannot be enrolled again with the same key.';
  }

  @override
  String get keepDevice => 'Keep device';
}
