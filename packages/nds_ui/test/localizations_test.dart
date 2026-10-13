import 'package:flutter_test/flutter_test.dart';
import 'package:nds_ui/l10n/app_localizations_en.dart';
import 'package:nds_ui/l10n/app_localizations_ru.dart';
import 'package:nds_native/gds.dart' as gds;
import 'package:nds_ui/modules_screen.dart';

void main() {
  test('Git comparison shows only Rust-computed available counts in en/ru', () {
    gds.Branch branch(String state, {int ahead = 0, int behind = 0}) =>
        gds.Branch(
          upstreamState: 'missing',
          comparisonState: state,
          ahead: ahead,
          behind: behind,
          diverged: false,
        );
    for (final l in [AppLocalizationsEn(), AppLocalizationsRu()]) {
      expect(localGitComparisonText(branch('available'), l), '0 / 0');
      expect(
        localGitComparisonText(branch('available', ahead: 3, behind: 2), l),
        '3 / 2',
      );
      expect(
        localGitComparisonText(branch('not-applicable'), l),
        l.gdsComparisonNotApplicable,
      );
      for (final state in ['unavailable', 'unknown']) {
        expect(
          localGitComparisonText(branch(state, ahead: 99, behind: 88), l),
          l.gdsUnavailable,
        );
      }
    }
  });
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
