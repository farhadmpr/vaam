import 'package:flutter_test/flutter_test.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'
    show databaseFactoryFfiNoIsolate, sqfliteFfiInit;
import 'package:vaam/models/loan.dart';
import 'package:vaam/models/statistics.dart';
import 'package:vaam/services/database_service.dart';
import 'package:vaam/services/statistics_service.dart';

/// ساخت وام تست با اقساط تولیدشده در دیتابیس
Future<int> _createLoan({
  required String name,
  String bank = 'بانک ملت',
  int startYear = 1404,
  int startMonth = 8,
  int startDay = 15,
  int count = 3,
  double? amount,
}) {
  return DatabaseService.instance.createLoan(
    Loan(
      name: name,
      bank: bank,
      startYear: startYear,
      startMonth: startMonth,
      startDay: startDay,
      installmentCount: count,
      amount: amount,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // دیتابیس درون‌حافظه‌ای و بدون ایزولیت، تا با FakeAsync تست‌ها سازگار باشد
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfiNoIsolate;
  DatabaseService.instance.useInMemoryDatabaseForTest();

  // هر تست با دیتابیس خالی شروع می‌شود
  setUp(() async {
    await DatabaseService.instance.resetForTest();
  });

  tearDownAll(() async {
    await DatabaseService.instance.resetForTest();
  });

  test('all range counts installments, amounts and banks', () async {
    await _createLoan(name: 'وام ملت', amount: 500000, count: 3);

    final stats = await StatisticsService.instance.getStatistics(
      StatsRange.all,
    );

    expect(stats.totalInstallments, 3);
    expect(stats.activeLoansCount, 1);
    expect(stats.paidCount, 0);
    expect(stats.paidAmount, 0);
    expect(stats.unpaidCount, 3);
    expect(stats.unpaidAmount, 1500000);
    expect(stats.maxInstallmentAmount, 500000);
    expect(stats.minInstallmentAmount, 500000);
    expect(stats.unknownAmountCount, 0);
    expect(stats.paidPercent, 0);

    expect(stats.bankStats, hasLength(1));
    final bank = stats.bankStats.single;
    expect(bank.bank, 'بانک ملت');
    expect(bank.loanCount, 1);
    expect(bank.remainingCount, 3);
    expect(bank.remainingAmount, 1500000);
  });

  test('current month range only counts installments of that month', () async {
    await _createLoan(name: 'وام مسکن', bank: 'بانک مسکن', amount: 1000000);

    // ۲۰ آبان ۱۴۰۴: قسط ۱۵ آبان عقب‌افتاده، قسط ۱۵ آذر در ۳۰ روز آینده
    final now = Jalali(1404, 8, 20).toDateTime();
    final stats = await StatisticsService.instance.getStatistics(
      StatsRange.currentMonth,
      now: now,
    );

    expect(stats.totalInstallments, 1);
    expect(stats.activeLoansCount, 1);
    expect(stats.unpaidCount, 1);
    expect(stats.unpaidAmount, 1000000);

    // شاخص‌های کل مستقل از بازه هستند
    expect(stats.totalRemainingDebtCount, 3);
    expect(stats.totalRemainingDebtAmount, 3000000);
    expect(stats.overdueCount, 1);
    expect(stats.overdueAmount, 1000000);
    expect(stats.upcomingCount, 1);
    expect(stats.upcomingAmount, 1000000);
  });
}
