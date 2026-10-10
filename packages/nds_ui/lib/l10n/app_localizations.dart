import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'NDDev OpenNetwork'**
  String get appTitle;

  /// No description provided for @connectTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect to NDS'**
  String get connectTitle;

  /// No description provided for @connectHelp.
  ///
  /// In en, this message translates to:
  /// **'Enter the HTTPS address of your self-hosted NDS server.'**
  String get connectHelp;

  /// No description provided for @serverAddress.
  ///
  /// In en, this message translates to:
  /// **'Server address'**
  String get serverAddress;

  /// No description provided for @connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get email;

  /// No description provided for @sendCode.
  ///
  /// In en, this message translates to:
  /// **'Send sign-in code'**
  String get sendCode;

  /// No description provided for @emailHint.
  ///
  /// In en, this message translates to:
  /// **'If this address is permitted, a sign-in code will arrive.'**
  String get emailHint;

  /// No description provided for @code.
  ///
  /// In en, this message translates to:
  /// **'Eight-digit code'**
  String get code;

  /// No description provided for @verify.
  ///
  /// In en, this message translates to:
  /// **'Verify code'**
  String get verify;

  /// No description provided for @resend.
  ///
  /// In en, this message translates to:
  /// **'Send another code'**
  String get resend;

  /// No description provided for @github.
  ///
  /// In en, this message translates to:
  /// **'Sign in with GitHub'**
  String get github;

  /// No description provided for @githubHelp.
  ///
  /// In en, this message translates to:
  /// **'Compare this code with the NDS approval page in your browser. Approve only when both codes match.'**
  String get githubHelp;

  /// No description provided for @openGithub.
  ///
  /// In en, this message translates to:
  /// **'Open GitHub'**
  String get openGithub;

  /// No description provided for @awaitApproval.
  ///
  /// In en, this message translates to:
  /// **'Waiting for explicit browser approval'**
  String get awaitApproval;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel sign-in'**
  String get cancel;

  /// No description provided for @unavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable on this server'**
  String get unavailable;

  /// No description provided for @sessionTitle.
  ///
  /// In en, this message translates to:
  /// **'Your NDS session'**
  String get sessionTitle;

  /// No description provided for @user.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get user;

  /// No description provided for @instance.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get instance;

  /// No description provided for @method.
  ///
  /// In en, this message translates to:
  /// **'Sign-in method'**
  String get method;

  /// No description provided for @expires.
  ///
  /// In en, this message translates to:
  /// **'Expires'**
  String get expires;

  /// No description provided for @verified.
  ///
  /// In en, this message translates to:
  /// **'Last verified'**
  String get verified;

  /// No description provided for @unverified.
  ///
  /// In en, this message translates to:
  /// **'This session has not been revalidated. Check the server connection.'**
  String get unverified;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Revalidate session'**
  String get refresh;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Revoke session and sign out'**
  String get logout;

  /// No description provided for @changeServer.
  ///
  /// In en, this message translates to:
  /// **'Change server'**
  String get changeServer;

  /// No description provided for @diagnostics.
  ///
  /// In en, this message translates to:
  /// **'Diagnostic logs for five minutes'**
  String get diagnostics;

  /// No description provided for @diagnosticsOff.
  ///
  /// In en, this message translates to:
  /// **'Stop diagnostic logs'**
  String get diagnosticsOff;

  /// No description provided for @privacy.
  ///
  /// In en, this message translates to:
  /// **'Session secrets stay in native secure storage. Sign-in does not recover vault keys.'**
  String get privacy;

  /// No description provided for @endpointError.
  ///
  /// In en, this message translates to:
  /// **'Use an HTTPS server origin without credentials, path, query or fragment.'**
  String get endpointError;

  /// No description provided for @inputError.
  ///
  /// In en, this message translates to:
  /// **'Check the email address and the eight-digit code.'**
  String get inputError;

  /// No description provided for @networkError.
  ///
  /// In en, this message translates to:
  /// **'The server could not be reached. No fresh session state is confirmed.'**
  String get networkError;

  /// No description provided for @storeError.
  ///
  /// In en, this message translates to:
  /// **'The native credential store is unavailable. No plaintext fallback is used.'**
  String get storeError;

  /// No description provided for @authError.
  ///
  /// In en, this message translates to:
  /// **'Sign-in could not be confirmed. Check the code or start again.'**
  String get authError;

  /// No description provided for @expiredError.
  ///
  /// In en, this message translates to:
  /// **'This sign-in attempt expired. Start again.'**
  String get expiredError;

  /// No description provided for @rateError.
  ///
  /// In en, this message translates to:
  /// **'Please wait before trying again.'**
  String get rateError;

  /// No description provided for @cancelledError.
  ///
  /// In en, this message translates to:
  /// **'Sign-in cancelled.'**
  String get cancelledError;

  /// No description provided for @responseError.
  ///
  /// In en, this message translates to:
  /// **'The server response does not match the NDS contract.'**
  String get responseError;

  /// No description provided for @genericError.
  ///
  /// In en, this message translates to:
  /// **'The operation failed. Try again.'**
  String get genericError;

  /// No description provided for @launchError.
  ///
  /// In en, this message translates to:
  /// **'The authorization browser could not be opened.'**
  String get launchError;

  /// No description provided for @working.
  ///
  /// In en, this message translates to:
  /// **'Working…'**
  String get working;

  /// No description provided for @validFor.
  ///
  /// In en, this message translates to:
  /// **'{seconds, plural, one{Valid for {seconds} second} other{Valid for {seconds} seconds}}'**
  String validFor(int seconds);

  /// No description provided for @retryIn.
  ///
  /// In en, this message translates to:
  /// **'{seconds, plural, one{Retry in {seconds} second} other{Retry in {seconds} seconds}}'**
  String retryIn(int seconds);

  /// No description provided for @revalidationRequired.
  ///
  /// In en, this message translates to:
  /// **'The credential write may have completed. Revalidate the session before continuing.'**
  String get revalidationRequired;

  /// No description provided for @emailMethod.
  ///
  /// In en, this message translates to:
  /// **'Email code'**
  String get emailMethod;

  /// No description provided for @sessionTab.
  ///
  /// In en, this message translates to:
  /// **'NDS session'**
  String get sessionTab;

  /// No description provided for @localModules.
  ///
  /// In en, this message translates to:
  /// **'Local modules'**
  String get localModules;

  /// No description provided for @localReadOnly.
  ///
  /// In en, this message translates to:
  /// **'Inspect local tools, history and planned maintenance. Tools retain control of their data.'**
  String get localReadOnly;

  /// No description provided for @module.
  ///
  /// In en, this message translates to:
  /// **'Module'**
  String get module;

  /// No description provided for @systemInfo.
  ///
  /// In en, this message translates to:
  /// **'System information'**
  String get systemInfo;

  /// No description provided for @clipboardHistory.
  ///
  /// In en, this message translates to:
  /// **'Clipboard history'**
  String get clipboardHistory;

  /// No description provided for @cleaner.
  ///
  /// In en, this message translates to:
  /// **'Cleaner'**
  String get cleaner;

  /// No description provided for @updater.
  ///
  /// In en, this message translates to:
  /// **'Updates'**
  String get updater;

  /// No description provided for @providerUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The local tool is unavailable.'**
  String get providerUnavailable;

  /// No description provided for @providerFailed.
  ///
  /// In en, this message translates to:
  /// **'The local tool could not complete this request.'**
  String get providerFailed;

  /// No description provided for @notChecked.
  ///
  /// In en, this message translates to:
  /// **'Not checked'**
  String get notChecked;

  /// No description provided for @reachable.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get reachable;

  /// No description provided for @noRecords.
  ///
  /// In en, this message translates to:
  /// **'No records.'**
  String get noRecords;

  /// No description provided for @nextPage.
  ///
  /// In en, this message translates to:
  /// **'Next page'**
  String get nextPage;

  /// No description provided for @openText.
  ///
  /// In en, this message translates to:
  /// **'Read text'**
  String get openText;

  /// No description provided for @cpuUsage.
  ///
  /// In en, this message translates to:
  /// **'CPU usage'**
  String get cpuUsage;

  /// No description provided for @cpuTemperature.
  ///
  /// In en, this message translates to:
  /// **'CPU temperature'**
  String get cpuTemperature;

  /// No description provided for @memoryUsage.
  ///
  /// In en, this message translates to:
  /// **'Memory used'**
  String get memoryUsage;

  /// No description provided for @swapUsage.
  ///
  /// In en, this message translates to:
  /// **'Swap used'**
  String get swapUsage;

  /// No description provided for @gpuUsage.
  ///
  /// In en, this message translates to:
  /// **'GPU usage'**
  String get gpuUsage;

  /// No description provided for @gpuMemory.
  ///
  /// In en, this message translates to:
  /// **'GPU memory used'**
  String get gpuMemory;

  /// No description provided for @gpuTemperature.
  ///
  /// In en, this message translates to:
  /// **'GPU temperature'**
  String get gpuTemperature;

  /// No description provided for @diskRead.
  ///
  /// In en, this message translates to:
  /// **'Disk read rate'**
  String get diskRead;

  /// No description provided for @diskWrite.
  ///
  /// In en, this message translates to:
  /// **'Disk write rate'**
  String get diskWrite;

  /// No description provided for @diskTemperature.
  ///
  /// In en, this message translates to:
  /// **'Disk temperature'**
  String get diskTemperature;

  /// No description provided for @networkReceive.
  ///
  /// In en, this message translates to:
  /// **'Network receive rate'**
  String get networkReceive;

  /// No description provided for @networkSend.
  ///
  /// In en, this message translates to:
  /// **'Network send rate'**
  String get networkSend;

  /// No description provided for @errors.
  ///
  /// In en, this message translates to:
  /// **'Errors'**
  String get errors;

  /// No description provided for @warnings.
  ///
  /// In en, this message translates to:
  /// **'Warnings'**
  String get warnings;

  /// No description provided for @checkOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get checkOk;

  /// No description provided for @checkWarning.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get checkWarning;

  /// No description provided for @checkError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get checkError;

  /// No description provided for @checkInfo.
  ///
  /// In en, this message translates to:
  /// **'Information'**
  String get checkInfo;

  /// No description provided for @mode.
  ///
  /// In en, this message translates to:
  /// **'Mode'**
  String get mode;

  /// No description provided for @preview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get preview;

  /// No description provided for @executed.
  ///
  /// In en, this message translates to:
  /// **'Executed'**
  String get executed;

  /// No description provided for @duration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get duration;

  /// No description provided for @freedBytes.
  ///
  /// In en, this message translates to:
  /// **'Reclaimed space'**
  String get freedBytes;

  /// No description provided for @deleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted entries'**
  String get deleted;

  /// No description provided for @skipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped entries'**
  String get skipped;

  /// No description provided for @failed.
  ///
  /// In en, this message translates to:
  /// **'Failed entries'**
  String get failed;

  /// No description provided for @channel.
  ///
  /// In en, this message translates to:
  /// **'Channel'**
  String get channel;

  /// No description provided for @result.
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get result;

  /// No description provided for @exitClass.
  ///
  /// In en, this message translates to:
  /// **'Exit classification'**
  String get exitClass;

  /// No description provided for @branch.
  ///
  /// In en, this message translates to:
  /// **'Branch'**
  String get branch;

  /// No description provided for @upstream.
  ///
  /// In en, this message translates to:
  /// **'Upstream'**
  String get upstream;

  /// No description provided for @aheadBehind.
  ///
  /// In en, this message translates to:
  /// **'Ahead / behind'**
  String get aheadBehind;

  /// No description provided for @staged.
  ///
  /// In en, this message translates to:
  /// **'Staged changes'**
  String get staged;

  /// No description provided for @unstaged.
  ///
  /// In en, this message translates to:
  /// **'Unstaged changes'**
  String get unstaged;

  /// No description provided for @untracked.
  ///
  /// In en, this message translates to:
  /// **'Untracked files'**
  String get untracked;

  /// No description provided for @conflicts.
  ///
  /// In en, this message translates to:
  /// **'Conflicts'**
  String get conflicts;

  /// No description provided for @remoteFreshness.
  ///
  /// In en, this message translates to:
  /// **'Remote data freshness'**
  String get remoteFreshness;

  /// No description provided for @repositoryPath.
  ///
  /// In en, this message translates to:
  /// **'Absolute repository path'**
  String get repositoryPath;

  /// No description provided for @lastRun.
  ///
  /// In en, this message translates to:
  /// **'Last run'**
  String get lastRun;

  /// No description provided for @updatePlan.
  ///
  /// In en, this message translates to:
  /// **'Update plan'**
  String get updatePlan;

  /// No description provided for @moduleRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get moduleRefresh;

  /// No description provided for @moduleCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel request'**
  String get moduleCancel;

  /// No description provided for @moduleDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get moduleDiagnostics;

  /// No description provided for @moduleInputError.
  ///
  /// In en, this message translates to:
  /// **'Check the repository path or selected entry.'**
  String get moduleInputError;

  /// No description provided for @moduleNetworkError.
  ///
  /// In en, this message translates to:
  /// **'The local tool did not respond in time.'**
  String get moduleNetworkError;

  /// No description provided for @moduleResponseError.
  ///
  /// In en, this message translates to:
  /// **'The local tool returned an unsupported response.'**
  String get moduleResponseError;

  /// No description provided for @moduleCancelled.
  ///
  /// In en, this message translates to:
  /// **'Request cancelled.'**
  String get moduleCancelled;

  /// No description provided for @missingReading.
  ///
  /// In en, this message translates to:
  /// **'No reading'**
  String get missingReading;

  /// No description provided for @textPreviewLimit.
  ///
  /// In en, this message translates to:
  /// **'Text preview, up to 16 KiB.'**
  String get textPreviewLimit;

  /// No description provided for @gdsInstall.
  ///
  /// In en, this message translates to:
  /// **'GDS installation'**
  String get gdsInstall;

  /// No description provided for @verifiedApplications.
  ///
  /// In en, this message translates to:
  /// **'Verified applications'**
  String get verifiedApplications;

  /// No description provided for @aptObserve.
  ///
  /// In en, this message translates to:
  /// **'APT package observation'**
  String get aptObserve;

  /// No description provided for @toolchainObserve.
  ///
  /// In en, this message translates to:
  /// **'Toolchain observation'**
  String get toolchainObserve;

  /// No description provided for @connected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connected;

  /// No description provided for @connecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting'**
  String get connecting;

  /// No description provided for @diagnosticsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Local diagnostics are unavailable. Sign-in can continue.'**
  String get diagnosticsUnavailable;

  /// No description provided for @localDiagnosticsOnly.
  ///
  /// In en, this message translates to:
  /// **'Local diagnostics are initialized; external delivery is not configured.'**
  String get localDiagnosticsOnly;

  /// No description provided for @diagnosticsDegraded.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics: rejected {rejected}, dropped {dropped}, write failures {failures}, pending {pending}.'**
  String diagnosticsDegraded(
    String rejected,
    String dropped,
    String failures,
    String pending,
  );
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
