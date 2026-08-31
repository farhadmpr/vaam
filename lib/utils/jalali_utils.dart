import 'package:shamsi_date/shamsi_date.dart';

/// ابزارهای تاریخ شمسی، ارقام فارسی و قالب‌بندی
class JalaliUtils {
  JalaliUtils._();

  static const List<String> monthNames = [
    'فروردین',
    'اردیبهشت',
    'خرداد',
    'تیر',
    'مرداد',
    'شهریور',
    'مهر',
    'آبان',
    'آذر',
    'دی',
    'بهمن',
    'اسفند',
  ];

  static const List<String> _englishDigits = [
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
  ];

  static const List<String> _persianDigits = [
    '۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹',
  ];

  /// تبدیل ارقام انگلیسی به فارسی
  static String toPersianDigits(String input) {
    final buffer = StringBuffer();
    for (final code in input.runes) {
      final ch = String.fromCharCode(code);
      final index = _englishDigits.indexOf(ch);
      buffer.write(index >= 0 ? _persianDigits[index] : ch);
    }
    return buffer.toString();
  }

  /// تبدیل ارقام فارسی و عربی به انگلیسی (برای پارس ورودی کاربر)
  static String toEnglishDigits(String input) {
    final buffer = StringBuffer();
    for (final code in input.runes) {
      final ch = String.fromCharCode(code);
      var index = _persianDigits.indexOf(ch);
      if (index < 0) {
        // ارقام عربی ٠..٩
        final arabic = const ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩']
            .indexOf(ch);
        index = arabic;
      }
      buffer.write(index >= 0 ? _englishDigits[index] : ch);
    }
    return buffer.toString();
  }

  /// افزودن [months] ماه به تاریخ شمسی با اصلاح روز
  /// (مثلاً روز ۳۱ در ماه ۳۰روزه به روز آخر آن ماه تبدیل می‌شود)
  static Jalali addMonths(Jalali base, int months) {
    final total = base.year * 12 + (base.month - 1) + months;
    final year = total ~/ 12;
    final month = total % 12 + 1;
    final maxDay = Jalali(year, month, 1).monthLength;
    return Jalali(year, month, base.day > maxDay ? maxDay : base.day);
  }

  /// قالب «۱۵ آبان ۱۴۰۴»
  static String formatJalali(Jalali date) {
    return '${toPersianDigits('${date.day}')} '
        '${monthNames[date.month - 1]} '
        '${toPersianDigits('${date.year}')}';
  }

  /// نمایش تاریخ میلادی به فرمت شمسی
  static String formatDateTime(DateTime dateTime) {
    return formatJalali(Jalali.fromDateTime(dateTime));
  }

  /// قالب ساعت «۰۹:۳۰»
  static String formatTime(int hour, int minute) {
    return toPersianDigits('${_pad2(hour)}:${_pad2(minute)}');
  }

  /// جداسازی هزارگان و تبدیل به ارقام فارسی: ۱۲۰۰۰۰۰ ← ۱٬۲۰۰٬۰۰۰
  static String formatAmount(num value) {
    final grouped = value
        .round()
        .toString()
        .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '٬');
    return toPersianDigits(grouped);
  }

  /// فاصله روز از امروز (مثبت: آینده، صفر: امروز، منفی: گذشته)
  static int daysFromToday(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    return target.difference(today).inDays;
  }

  /// برچسب وضعیت سررسید
  static String remainingLabel(int days) {
    if (days < 0) return '${toPersianDigits('${-days}')} روز عقب‌افتاده';
    if (days == 0) return 'امروز';
    if (days == 1) return 'فردا';
    return '${toPersianDigits('$days')} روز مانده';
  }

  /// تاریخ به فرمت yyyy-MM-dd (برای ذخیره‌سازی)
  static String toIsoDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}'
        '-${_pad2(date.month)}-${_pad2(date.day)}';
  }

  static String _pad2(int value) => value.toString().padLeft(2, '0');
}
