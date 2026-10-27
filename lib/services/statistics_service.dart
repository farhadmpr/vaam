import '../models/statistics.dart';
import 'database_service.dart';

/// یک قسط به همراه اطلاعات وام مرتبط (برای محاسبه آمار)
class _InstallmentRow {
  final int loanId;
  final bool isPaid;
  final DateTime dueDate;
  final DateTime? paidAt;
  final String bank;
  final double? amount;

  const _InstallmentRow({
    required this.loanId,
    required this.isPaid,
    required this.dueDate,
    required this.paidAt,
    required this.bank,
    required this.amount,
  });

  factory _InstallmentRow.fromMap(Map<String, Object?> map) {
    final paidAtRaw = map['paid_at'] as String?;
    return _InstallmentRow(
      loanId: map['loan_id'] as int,
      isPaid: (map['is_paid'] as int? ?? 0) == 1,
      dueDate: DateTime.parse(map['due_date'] as String),
      paidAt: paidAtRaw == null ? null : DateTime.tryParse(paidAtRaw),
      bank: (map['bank'] as String?) ?? 'بدون بانک',
      amount: (map['amount'] as num?)?.toDouble(),
    );
  }
}

/// سرویس محاسبه آمار و گزارش‌های وام‌ها
///
/// مبلغ هر قسط از فیلد `amount` خودِ وام خوانده می‌شود؛ اگر مبلغ وام ثبت
/// نشده باشد، قسط در «تعداد»ها شمرده می‌شود ولی در «مبلغ»ها لحاظ نمی‌شود
/// و تعدادشان در [Statistics.unknownAmountCount] گزارش می‌شود.
class StatisticsService {
  StatisticsService._();

  static final StatisticsService instance = StatisticsService._();

  /// تعداد روزهای پیش‌بینی سررسیدهای آینده
  static const int upcomingDays = 30;

  /// محاسبه آمار بازه [range]؛ [now] فقط برای تزریق زمان در تست‌هاست
  Future<Statistics> getStatistics(StatsRange range, {DateTime? now}) async {
    final db = await DatabaseService.instance.database;
    final rows = await db.rawQuery(
      'SELECT i.loan_id, i.is_paid, i.due_date, i.paid_at, '
      'l.bank AS bank, l.amount AS amount '
      'FROM installments i '
      'LEFT JOIN loans l ON l.id = i.loan_id',
    );
    return _calculate(
      rows.map(_InstallmentRow.fromMap).toList(growable: false),
      range.resolve(now),
      now: now,
    );
  }

  /// محاسبه آمار از روی ردیف‌های قسط
  Statistics _calculate(
    List<_InstallmentRow> rows,
    JalaliRange selected, {
    DateTime? now,
  }) {
    final today = _dayOnly(now ?? DateTime.now());
    final horizon = today.add(const Duration(days: upcomingDays));

    // ---- شاخص‌های مستقل از بازه (کل) ----
    var totalRemainingDebtCount = 0;
    var totalRemainingDebtAmount = 0.0;
    var overdueCount = 0;
    var overdueAmount = 0.0;
    var upcomingCount = 0;
    var upcomingAmount = 0.0;

    // ---- شاخص‌های بازه انتخابی ----
    var totalInstallments = 0;
    var paidCount = 0;
    var paidAmount = 0.0;
    var unpaidCount = 0;
    var unpaidAmount = 0.0;
    var paidDuringRangeCount = 0;
    var paidDuringRangeAmount = 0.0;
    var unknownAmountCount = 0;
    double? maxAmount;
    double? minAmount;

    final activeLoanIds = <int>{};
    final loansPerBank = <String, Set<int>>{};
    final remainingCountPerBank = <String, int>{};
    final remainingAmountPerBank = <String, double>{};

    for (final row in rows) {
      final amount = row.amount;
      final dueDate = _dayOnly(row.dueDate);
      final paidAt = row.paidAt;

      if (!row.isPaid) {
        totalRemainingDebtCount++;
        totalRemainingDebtAmount += amount ?? 0;
        if (dueDate.isBefore(today)) {
          overdueCount++;
          overdueAmount += amount ?? 0;
        } else if (!dueDate.isAfter(horizon)) {
          upcomingCount++;
          upcomingAmount += amount ?? 0;
        }
      }

      // پرداخت‌های انجام‌شده در بازه (بر اساس تاریخ پرداخت)
      if (row.isPaid && paidAt != null && selected.contains(paidAt)) {
        paidDuringRangeCount++;
        paidDuringRangeAmount += amount ?? 0;
      }

      if (!selected.contains(row.dueDate)) continue;

      totalInstallments++;
      (loansPerBank[row.bank] ??= <int>{}).add(row.loanId);
      if (amount == null) {
        unknownAmountCount++;
      } else {
        if (maxAmount == null || amount > maxAmount) maxAmount = amount;
        if (minAmount == null || amount < minAmount) minAmount = amount;
      }

      if (row.isPaid) {
        paidCount++;
        paidAmount += amount ?? 0;
      } else {
        activeLoanIds.add(row.loanId);
        unpaidCount++;
        unpaidAmount += amount ?? 0;
        remainingCountPerBank[row.bank] =
            (remainingCountPerBank[row.bank] ?? 0) + 1;
        remainingAmountPerBank[row.bank] =
            (remainingAmountPerBank[row.bank] ?? 0) + (amount ?? 0);
      }
    }

    final bankStats = loansPerBank.keys
        .map(
          (bank) => BankStat(
            bank: bank,
            loanCount: loansPerBank[bank]!.length,
            remainingCount: remainingCountPerBank[bank] ?? 0,
            remainingAmount: remainingAmountPerBank[bank] ?? 0,
          ),
        )
        .toList()
      ..sort((a, b) {
        final byAmount = b.remainingAmount.compareTo(a.remainingAmount);
        if (byAmount != 0) return byAmount;
        final byLoans = b.loanCount.compareTo(a.loanCount);
        if (byLoans != 0) return byLoans;
        return a.bank.compareTo(b.bank);
      });

    return Statistics(
      activeLoansCount: activeLoanIds.length,
      totalInstallments: totalInstallments,
      paidCount: paidCount,
      paidAmount: paidAmount,
      unpaidCount: unpaidCount,
      unpaidAmount: unpaidAmount,
      paidDuringRangeCount: paidDuringRangeCount,
      paidDuringRangeAmount: paidDuringRangeAmount,
      totalRemainingDebtCount: totalRemainingDebtCount,
      totalRemainingDebtAmount: totalRemainingDebtAmount,
      overdueCount: overdueCount,
      overdueAmount: overdueAmount,
      upcomingCount: upcomingCount,
      upcomingAmount: upcomingAmount,
      maxInstallmentAmount: maxAmount ?? 0,
      minInstallmentAmount: minAmount ?? 0,
      unknownAmountCount: unknownAmountCount,
      bankStats: List<BankStat>.unmodifiable(bankStats),
    );
  }
}

/// حذف بخش ساعت از تاریخ (مقایسه فقط بر اساس روز)
DateTime _dayOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);
