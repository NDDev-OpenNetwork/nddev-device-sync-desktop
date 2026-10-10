// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'NDDev OpenNetwork';

  @override
  String get connectTitle => 'Подключение к NDS';

  @override
  String get connectHelp => 'Укажите HTTPS-адрес вашего сервера NDS.';

  @override
  String get serverAddress => 'Адрес сервера';

  @override
  String get connect => 'Подключиться';

  @override
  String get signIn => 'Вход';

  @override
  String get email => 'Электронная почта';

  @override
  String get sendCode => 'Получить код входа';

  @override
  String get emailHint => 'Если адрес разрешён, на него придёт код входа.';

  @override
  String get code => 'Восьмизначный код';

  @override
  String get verify => 'Подтвердить код';

  @override
  String get resend => 'Отправить новый код';

  @override
  String get github => 'Войти через GitHub';

  @override
  String get githubHelp =>
      'Сравните этот код с кодом на странице подтверждения NDS в браузере. Разрешайте вход, только если коды совпадают.';

  @override
  String get openGithub => 'Открыть GitHub';

  @override
  String get awaitApproval => 'Ожидается подтверждение в браузере';

  @override
  String get cancel => 'Отменить вход';

  @override
  String get unavailable => 'Недоступно на этом сервере';

  @override
  String get sessionTitle => 'Ваша сессия NDS';

  @override
  String get user => 'Пользователь';

  @override
  String get instance => 'Сервер';

  @override
  String get method => 'Способ входа';

  @override
  String get expires => 'Действует до';

  @override
  String get verified => 'Последняя проверка';

  @override
  String get unverified =>
      'Сессия не подтверждена повторно. Проверьте подключение к серверу.';

  @override
  String get refresh => 'Проверить сессию';

  @override
  String get logout => 'Отозвать сессию и выйти';

  @override
  String get changeServer => 'Сменить сервер';

  @override
  String get diagnostics => 'Диагностические логи на пять минут';

  @override
  String get diagnosticsOff => 'Отключить диагностические логи';

  @override
  String get privacy =>
      'Секреты сессии остаются в защищённом хранилище ОС. Вход не восстанавливает ключи хранилища.';

  @override
  String get endpointError =>
      'Укажите HTTPS-адрес сервера без пароля, пути, параметров и фрагмента.';

  @override
  String get inputError => 'Проверьте адрес почты и восьмизначный код.';

  @override
  String get networkError =>
      'Сервер недоступен. Актуальное состояние сессии не подтверждено.';

  @override
  String get storeError =>
      'Защищённое хранилище ОС недоступно. Незашифрованное хранение не используется.';

  @override
  String get authError =>
      'Не удалось подтвердить вход. Проверьте код или начните заново.';

  @override
  String get expiredError => 'Время для входа истекло. Начните заново.';

  @override
  String get rateError => 'Подождите перед следующей попыткой.';

  @override
  String get cancelledError => 'Вход отменён.';

  @override
  String get responseError => 'Ответ сервера не соответствует протоколу NDS.';

  @override
  String get genericError =>
      'Не удалось выполнить действие. Повторите попытку.';

  @override
  String get launchError => 'Не удалось открыть браузер для входа.';

  @override
  String get working => 'Выполняется…';

  @override
  String validFor(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: 'Действует ещё $seconds секунды',
      many: 'Действует ещё $seconds секунд',
      few: 'Действует ещё $seconds секунды',
      one: 'Действует ещё $seconds секунду',
    );
    return '$_temp0';
  }

  @override
  String retryIn(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: 'Повтор через $seconds секунды',
      many: 'Повтор через $seconds секунд',
      few: 'Повтор через $seconds секунды',
      one: 'Повтор через $seconds секунду',
    );
    return '$_temp0';
  }

  @override
  String get revalidationRequired =>
      'Секрет сессии мог сохраниться. Проверьте сессию перед продолжением.';

  @override
  String get emailMethod => 'Код по почте';

  @override
  String get sessionTab => 'Сессия NDS';

  @override
  String get localModules => 'Локальные модули';

  @override
  String get localReadOnly =>
      'Просмотр состояния инструментов, истории и плана обслуживания. Данные остаются у своих инструментов.';

  @override
  String get module => 'Модуль';

  @override
  String get systemInfo => 'Состояние системы';

  @override
  String get clipboardHistory => 'История буфера обмена';

  @override
  String get cleaner => 'Очистка';

  @override
  String get updater => 'Обновления';

  @override
  String get providerUnavailable => 'Локальный инструмент недоступен.';

  @override
  String get providerFailed => 'Локальный инструмент не выполнил запрос.';

  @override
  String get notChecked => 'Ещё не проверено';

  @override
  String get reachable => 'Доступен';

  @override
  String get noRecords => 'Записей нет.';

  @override
  String get nextPage => 'Следующая страница';

  @override
  String get openText => 'Прочитать текст';

  @override
  String get cpuUsage => 'Загрузка CPU';

  @override
  String get cpuTemperature => 'Температура CPU';

  @override
  String get memoryUsage => 'Использование памяти';

  @override
  String get swapUsage => 'Использование swap';

  @override
  String get gpuUsage => 'Загрузка GPU';

  @override
  String get gpuMemory => 'Использование памяти GPU';

  @override
  String get gpuTemperature => 'Температура GPU';

  @override
  String get diskRead => 'Чтение диска';

  @override
  String get diskWrite => 'Запись диска';

  @override
  String get diskTemperature => 'Температура диска';

  @override
  String get networkReceive => 'Приём данных';

  @override
  String get networkSend => 'Передача данных';

  @override
  String get errors => 'Ошибки';

  @override
  String get warnings => 'Предупреждения';

  @override
  String get checkOk => 'В порядке';

  @override
  String get checkWarning => 'Предупреждение';

  @override
  String get checkError => 'Ошибка';

  @override
  String get checkInfo => 'Сведения';

  @override
  String get mode => 'Режим';

  @override
  String get preview => 'Предпросмотр';

  @override
  String get executed => 'Выполнено';

  @override
  String get duration => 'Длительность';

  @override
  String get freedBytes => 'Освобождено';

  @override
  String get deleted => 'Удалено записей';

  @override
  String get skipped => 'Пропущено записей';

  @override
  String get failed => 'Не обработано записей';

  @override
  String get channel => 'Канал';

  @override
  String get result => 'Результат';

  @override
  String get exitClass => 'Класс завершения';

  @override
  String get branch => 'Ветка';

  @override
  String get upstream => 'Отслеживаемая ветка';

  @override
  String get aheadBehind => 'Впереди / позади';

  @override
  String get staged => 'Подготовлено изменений';

  @override
  String get unstaged => 'Изменений вне индекса';

  @override
  String get untracked => 'Неотслеживаемых файлов';

  @override
  String get conflicts => 'Конфликты';

  @override
  String get remoteFreshness => 'Актуальность удалённых данных';

  @override
  String get repositoryPath => 'Абсолютный путь репозитория';

  @override
  String get lastRun => 'Последний запуск';

  @override
  String get updatePlan => 'План обновления';

  @override
  String get moduleRefresh => 'Обновить';

  @override
  String get moduleCancel => 'Отменить запрос';

  @override
  String get moduleDiagnostics => 'Диагностика';

  @override
  String get moduleInputError =>
      'Проверьте путь репозитория или выбранную запись.';

  @override
  String get moduleNetworkError => 'Локальный инструмент не ответил вовремя.';

  @override
  String get moduleResponseError =>
      'Локальный инструмент вернул неподдерживаемый ответ.';

  @override
  String get moduleCancelled => 'Запрос отменён.';

  @override
  String get missingReading => 'Нет показания';

  @override
  String get textPreviewLimit => 'Предпросмотр текста, до 16 КиБ.';

  @override
  String get gdsInstall => 'Установка GDS';

  @override
  String get verifiedApplications => 'Проверенные приложения';

  @override
  String get aptObserve => 'Проверка пакетов APT';

  @override
  String get toolchainObserve => 'Проверка инструментов разработки';

  @override
  String get connected => 'Подключено';

  @override
  String get connecting => 'Подключение';

  @override
  String get diagnosticsUnavailable =>
      'Локальная диагностика недоступна. Вход в NDS остаётся доступен.';

  @override
  String get localDiagnosticsOnly =>
      'Локальная диагностика включена; внешняя доставка не настроена.';

  @override
  String diagnosticsDegraded(
    String rejected,
    String dropped,
    String failures,
    String pending,
  ) {
    return 'Диагностика: отклонено $rejected, потеряно $dropped, ошибок записи $failures, в очереди $pending.';
  }

  @override
  String get startupFailed =>
      'Не удалось запустить NDS. Перезапустите приложение. Если ошибка повторится, проверьте установку и локальную диагностику.';

  @override
  String get diagnosticsHttp => 'Диагностика сети';

  @override
  String get diagnosticsIo => 'Локальные операции';

  @override
  String get devicesTitle => 'Ваши устройства';

  @override
  String get devicesHelp =>
      'Зарегистрируйте эту установку с её собственным нативным ключом подписи. Регистрация устройства не открывает vault.';

  @override
  String get devicesUnverified =>
      'Список устройств ещё не подтверждён свежей проверкой.';

  @override
  String get deviceName => 'Имя устройства';

  @override
  String get enrollDevice => 'Зарегистрировать устройство';

  @override
  String get refreshDevices => 'Обновить устройства';

  @override
  String get thisDevice => 'Эта установка';

  @override
  String get deviceActive => 'Активно';

  @override
  String get deviceRevoked => 'Доступ отозван';

  @override
  String get deviceCreated => 'Зарегистрировано';

  @override
  String get deviceRevokedHelp =>
      'Ключ этого устройства отозван. Он сохранён локально и не может повторно использоваться для регистрации.';

  @override
  String get revokeDevice => 'Отозвать устройство';

  @override
  String revokeDeviceHelp(String name) {
    return 'Отозвать доступ для $name? Эта идентичность не сможет снова зарегистрироваться с тем же ключом.';
  }

  @override
  String get keepDevice => 'Оставить устройство';

  @override
  String get vaultTitle => 'Vault и синхронизация';

  @override
  String get vaultHelp =>
      'Ключи остаются в нативном защищённом хранилище. Сервер получает только зашифрованные записи. Потерянные ключи восстановить нельзя.';

  @override
  String get vaultLocked =>
      'Ключ vault недоступен. Подключитесь через доверенное устройство.';

  @override
  String get vaultUnlocked => 'Нативный ключ vault доступен.';

  @override
  String get vaultExisting =>
      'Существующий ключ vault нельзя заменить. Подключитесь через доверенное устройство.';

  @override
  String vaultCounts(int pending, int conflicts) {
    return 'В очереди: $pending · Конфликты: $conflicts';
  }

  @override
  String get vaultKeyIdentity => 'Идентичность ключа';

  @override
  String get vaultCreate => 'Создать первоначальный vault';

  @override
  String get vaultPairStart => 'Запросить ключ у доверенного устройства';

  @override
  String get vaultRecordTitle => 'Название записи';

  @override
  String get vaultUsername => 'Имя пользователя или аккаунта';

  @override
  String get vaultSecret => 'Секретное значение';

  @override
  String get vaultSave => 'Зашифровать и синхронизировать';

  @override
  String vaultRevision(String revision) {
    return 'Ревизия $revision';
  }

  @override
  String get vaultConflict => 'Конфликт не разрешён. Обе версии сохранены.';

  @override
  String get vaultPairHelp =>
      'Передайте код приглашения доверенному устройству, подтвердите получателя и перенесите зашифрованный ответ обратно. Приглашение действует пять минут.';

  @override
  String get vaultPairCode => 'Приглашение или зашифрованный ответ';

  @override
  String get vaultGrant => 'Подтвердить доверенную передачу ключа';

  @override
  String get vaultGrantConfirm =>
      'Подтвердите, что это приглашение получено напрямую от устройства, которому вы доверяете. Это даст зарегистрированному устройству доступ к вашему vault.';

  @override
  String get vaultImport => 'Принять зашифрованный ответ с ключом';

  @override
  String get vaultSync => 'Синхронизировать сейчас';

  @override
  String get vaultInputError =>
      'Проверьте поля записи или полный код подключения.';

  @override
  String get vaultProofError =>
      'Не удалось подтвердить передачу ключа или подлинность зашифрованных данных.';
}
