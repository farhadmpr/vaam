import 'package:shamsi_date/shamsi_date.dart';

import '../utils/jalali_utils.dart';

/// بازه‌های آماری قابل انتخاب در صفحه آمار
enum StatsRange {
  currentMonth('این ماه'),
  previousMonth('ماه قبل'),
  last3Months('۳ ماه اخیر'),
  currentYear('سال جاری'),
  all('همه زمان‌ها');

  const StatsRange(this.label);

  /// برچسب فارسی بازه
  final String label;

  /// بازه شمسی متناظر با این انتخاب ([now] پیش‌فرض: همین لحظه)
  JalaliRange resolve([DateTime? now]) {
    final today = Jalali.fromDateTime(now ?? DateTime.now());
    switch (this) {
      case StatsRange.currentMonth:
        return _monthRange(today.year, today.month);
      case StatsRange.previousMonth:
        final previous = JalaliUtils.addMonths(
          Jalali(today.year, today.month, 1),
          -1,
        );
        return _monthRange(previous.year, previous.month);
      case StatsRange.last3Months:
        final first = JalaliUtils.addMonths(
          Jalali(today.year, today.month, 1),
          -2,
        );
        return JalaliRange(
          start: Jalali(first.year, first.month, 1),
          end: _lastDayOfMonth(today.year, today.month),
        );
      case StatsRange.currentYear:
        return JalaliRange(
          start: Jalali(today.year, 1, 1),
          end: _lastDayOfMonth(today.year, 12),
        );
      case StatsRange.all:
        return const JalaliRange.all();
    }
  }

  /// بازه یک ماه کامل شمسی
  static JalaliRange _monthRange(int year, int month) => JalaliRange(
        start: Jalali(year, month, 1),
        end: _lastDayOfMonth(year, month),
      );

  static Jalali _lastDayOfMonth(int year, int month) =>
      Jalali(year, month, Jalali(year, month, 1).monthLength);
}

/// بازه تاریخ شمسی (هر دو سر شامل)
class JalaliRange {
  /// اولین روز بازه (شمسی)
  final Jalali? start;

  /// آخرین روز بازه (شمسی)
  final Jalali? end;

  const JalaliRange({this.start, this.end});

  /// بازه نامحدود (همه زمان‌ها)
  const JalaliRange.all()
      : start = null,
        end = null;

  /// آیا بازه محدود نیست؟
  bool get isAll => start == null || end == null;

  /// آیا [date] (میلادی) داخل بازه است؟ (مقایسه فقط بر اساس روز)
  bool contains(DateTime date) {
    final from = start;
    final to = end;
    if (from == null || to == null) return true;
    final value = _dayOnly(date);
    return !value.isBefore(_dayOnly(from.toDateTime())) &&
        !value.isAfter(_dayOnly(to.toDateTime()));
  }

  /// برچسب فارسی بازه، مثل «مرداد ۱۴۰۵» یا «خرداد تا مرداد ۱۴۰۵»
  String get label {
    final from = start;
    final to = end;
    if (from == null || to == null) return 'همه زمان‌ها';
    final startMonth = JalaliUtils.monthNames[from.month - 1];
    final endMonth = JalaliUtils.monthNames[to.month - 1];
    final startYear = JalaliUtils.toPersianDigits('${from.year}');
    final endYear = JalaliUtils.toPersianDigits('${to.year}');
    if (from.year == to.year && from.month == to.month) {
      return '$startMonth $startYear';
    }
    if (from.year == to.year) return '$startMonth تا $endMonth $endYear';
    return '$startMonth $startYear تا $endMonth $endYear';
  }
}

DateTime _dayOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

/// آمار و گزارش‌های وام‌ها برای یک بازه زمانی
///
/// شاخص‌هایی که در توضیحات آن‌ها «کل» آمده مستقل از بازه انتخابی هستند
/// (همیشه روی همه داده‌ها محاسبه می‌شوند)؛ بقیه شاخص‌ها فقط اقساطی را
/// در نظر می‌گیرند که سررسیدشان داخل بازه انتخابی است.
class Statistics {
  /// تعداد وام‌هایی که در بازه حداقل یک قسط پرداخت‌نشده دارند
  final int activeLoansCount;

  /// تعداد کل اقساط با سررسید داخل بازه
  final int totalInstallments;

  /// تعداد اقساطِ سررسید داخل بازه که پرداخت شده‌اند
  final int paidCount;

  /// مجموع مبلغ اقساطِ سررسید داخل بازه که پرداخت شده‌اند
  final double paidAmount;

  /// تعداد اقساطِ سررسید داخل بازه که پرداخت نشده‌اند
  final int unpaidCount;

  /// مجموع مبلغ اقساطِ سررسید داخل بازه که پرداخت نشده‌اند
  final double unpaidAmount;

  /// تعداد اقساطی که «تاریخ پرداخت» آن‌ها داخل بازه است
  final int paidDuringRangeCount;

  /// مجموع مبلغ اقساطی که «تاریخ پرداخت» آن‌ها داخل بازه است
  final double paidDuringRangeAmount;

  /// تعداد همه اقساط پرداخت‌نشده (کل)
  final int totalRemainingDebtCount;

  /// مجموع مبلغ همه اقساط پرداخت‌نشده (کل)
  final double totalRemainingDebtAmount;

  /// تعداد اقساط عقب‌افتاده (کل)
  final int overdueCount;

  /// مجموع مبلغ اقساط عقب‌افتاده (کل)
  final double overdueAmount;

  /// تعداد اقساط سررسیددار در ۳۰ روز آینده (کل)
  final int upcomingCount;

  /// مجموع مبلغ اقساط سررسیددار در ۳۰ روز آینده (کل)
  final double upcomingAmount;

  /// بیشترین مبلغ قسط در بازه (۰: مبلغی ثبت نشده است)
  final double maxInstallmentAmount;

  /// کمترین مبلغ قسط در بازه (۰: مبلغی ثبت نشده است)
  final double minInstallmentAmount;

  /// تعداد اقساط بازه که مبلغشان ثبت نشده و در جمع‌ها لحاظ نشده‌اند
  final int unknownAmountCount;

  /// آمار تفکیک‌شده بر اساس بانک (مرتب‌شده بر اساس مبلغ باقیمانده)
  final List<BankStat> bankStats;

  const Statistics({
    required this.activeLoansCount,
    required this.totalInstallments,
    required this.paidCount,
    required this.paidAmount,
    required this.unpaidCount,
    required this.unpaidAmount,
    required this.paidDuringRangeCount,
    required this.paidDuringRangeAmount,
    required this.totalRemainingDebtCount,
    required this.totalRemainingDebtAmount,
    required this.overdueCount,
    required this.overdueAmount,
    required this.upcomingCount,
    required this.upcomingAmount,
    required this.maxInstallmentAmount,
    required this.minInstallmentAmount,
    required this.unknownAmountCount,
    required this.bankStats,
  });

  /// آمار خالی (برای حالت بارگذاری/نبود داده)
  const Statistics.empty()
      : activeLoansCount = 0,
        totalInstallments = 0,
        paidCount = 0,
        paidAmount = 0,
        unpaidCount = 0,
        unpaidAmount = 0,
        paidDuringRangeCount = 0,
        paidDuringRangeAmount = 0,
        totalRemainingDebtCount = 0,
        totalRemainingDebtAmount = 0,
        overdueCount = 0,
        overdueAmount = 0,
        upcomingCount = 0,
        upcomingAmount = 0,
        maxInstallmentAmount = 0,
        minInstallmentAmount = 0,
        unknownAmountCount = 0,
        bankStats = const [];

  /// آیا در این بازه هیچ قسطی وجود ندارد؟
  bool get isEmpty => totalInstallments == 0;

  /// درصد اقساط پرداخت‌شده در بازه (۰ تا ۱۰۰)
  int get paidPercent {
    if (totalInstallments == 0) return 0;
    return (paidCount * 100 / totalInstallments).round();
  }
}

/// آمار یک بانک در بازه انتخابی
class BankStat {
  /// نام بانک
  final String bank;

  /// تعداد وام‌های این بانک که در بازه قسط دارند
  final int loanCount;

  /// تعداد اقساط پرداخت‌نشده این بانک در بازه
  final int remainingCount;

  /// مجموع مبلغ باقیمانده این بانک در بازه
  final double remainingAmount;

  const BankStat({
    required this.bank,
    required this.loanCount,
    required this.remainingCount,
    required this.remainingAmount,
  });
}
