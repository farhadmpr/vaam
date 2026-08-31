import 'package:flutter_test/flutter_test.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:vaam/utils/jalali_utils.dart';

void main() {
  group('JalaliUtils.addMonths', () {
    test('adds months within the same year', () {
      final result = JalaliUtils.addMonths(Jalali(1404, 2, 10), 3);
      expect(result.year, 1404);
      expect(result.month, 5);
      expect(result.day, 10);
    });

    test('rolls over to the next year', () {
      final result = JalaliUtils.addMonths(Jalali(1404, 10, 25), 4);
      expect(result.year, 1405);
      expect(result.month, 2);
      expect(result.day, 25);
    });

    test('clamps day 31 when the target month is shorter', () {
      // شهریور ۳۱ روز دارد ولی مهر ۳۰ روز؛ پس ۳۱ شهریور + ۱ ماه = ۳۰ مهر
      final result = JalaliUtils.addMonths(Jalali(1404, 6, 31), 1);
      expect(result.year, 1404);
      expect(result.month, 7);
      expect(result.day, 30);
    });

    test('clamps 30th of a leap Esfand in a non-leap year', () {
      // ۱۳۹۹ کبیسه است (اسفند ۳۰ روز)؛ ۱۴۰۰ کبیسه نیست
      final result = JalaliUtils.addMonths(Jalali(1399, 12, 30), 12);
      expect(result.year, 1400);
      expect(result.month, 12);
      expect(result.day, 29);
    });

    test('does not modify the original date', () {
      final base = Jalali(1404, 6, 31);
      JalaliUtils.addMonths(base, 5);
      expect(base.year, 1404);
      expect(base.month, 6);
      expect(base.day, 31);
    });
  });

  group('digits', () {
    test('toPersianDigits', () {
      expect(JalaliUtils.toPersianDigits('1404/08/15'), '۱۴۰۴/۰۸/۱۵');
      expect(JalaliUtils.toPersianDigits('قسط 3 از 12'), 'قسط ۳ از ۱۲');
    });

    test('toEnglishDigits', () {
      expect(JalaliUtils.toEnglishDigits('۱۴۰۴'), '1404');
      expect(JalaliUtils.toEnglishDigits('٢٥'), '25');
    });
  });

  test('formatJalali', () {
    expect(
      JalaliUtils.formatJalali(Jalali(1404, 8, 15)),
      '۱۵ آبان ۱۴۰۴',
    );
  });

  test('formatTime', () {
    expect(JalaliUtils.formatTime(9, 30), '۰۹:۳۰');
    expect(JalaliUtils.formatTime(21, 5), '۲۱:۰۵');
  });

  test('formatAmount', () {
    expect(JalaliUtils.formatAmount(1200000), '۱٬۲۰۰٬۰۰۰');
    expect(JalaliUtils.formatAmount(950), '۹۵۰');
  });

  test('toIsoDate', () {
    expect(JalaliUtils.toIsoDate(DateTime(2025, 11, 6)), '2025-11-06');
  });

  test('remainingLabel', () {
    expect(JalaliUtils.remainingLabel(0), 'امروز');
    expect(JalaliUtils.remainingLabel(1), 'فردا');
    expect(JalaliUtils.remainingLabel(7), '۷ روز مانده');
    expect(JalaliUtils.remainingLabel(-3), '۳ روز عقب‌افتاده');
  });

  test('Jalali/DateTime conversion round trip', () {
    final date = Jalali(1404, 8, 15);
    final dateTime = date.toDateTime();
    final converted = Jalali.fromDateTime(dateTime);
    expect(converted.year, date.year);
    expect(converted.month, date.month);
    expect(converted.day, date.day);
  });
}
