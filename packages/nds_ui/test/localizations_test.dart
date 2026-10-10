import 'package:flutter_test/flutter_test.dart';
import 'package:nds_ui/l10n/app_localizations_en.dart';
import 'package:nds_ui/l10n/app_localizations_ru.dart';

void main() {
  test('Russian countdown uses ICU one, few and many forms', () {
    final l = AppLocalizationsRu();
    expect(l.validFor(1), contains('1 секунду'));
    expect(l.validFor(2), contains('2 секунды'));
    expect(l.validFor(5), contains('5 секунд'));
    expect(l.retryIn(21), contains('21 секунду'));
  });
  test('English countdown remains singular for one second', () {
    final l = AppLocalizationsEn();
    expect(l.retryIn(1), 'Retry in 1 second');
    expect(l.retryIn(2), 'Retry in 2 seconds');
  });
}
