import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'
    show databaseFactoryFfiNoIsolate, sqfliteFfiInit;
import 'package:shamsi_date/shamsi_date.dart';
import 'package:vaam/models/loan.dart';
import 'package:vaam/models/repeat_unit.dart';
import 'package:vaam/services/database_service.dart';

Loan _loan(
  String name, {
  int count = 3,
  int startYear = 1404,
  int startMonth = 8,
  int startDay = 15,
}) {
  return Loan(
    name: name,
    bank: 'بانک ملت',
    startYear: startYear,
    startMonth: startMonth,
    startDay: startDay,
    installmentCount: count,
  );
}

void main() {
  // پیاده‌سازی ffi درون‌حافظه‌ای: هر فایل تست دیتابیس مجزای خودش را دارد
  // و تداخلی با فایل‌های تست دیگر (که موازی اجرا می‌شوند) ایجاد نمی‌کند
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfiNoIsolate;
  DatabaseService.instance.useInMemoryDatabaseForTest();

  setUpAll(() async {
    await DatabaseService.instance.resetForTest();
  });

  tearDownAll(() async {
    await DatabaseService.instance.resetForTest();
  });

  test('createLoan generates monthly installments', () async {
    final start = Jalali(1404, 8, 15);
    final id = await DatabaseService.instance.createLoan(
      _loan('وام خودرو', count: 4),
    );
    final installments = await DatabaseService.instance.getInstallments(id);

    expect(installments, hasLength(4));
    expect(installments[0].number, 1);
    expect(installments[0].isPaid, isFalse);

    // هر قسط باید یک ماه بعد از قسط قبل با همان روز ماه باشد
    for (var i = 0; i < installments.length; i++) {
      final jalali = Jalali.fromDateTime(
        DateTime.parse(installments[i].dueDate),
      );
      expect(jalali.year, start.year + (start.month - 1 + i) ~/ 12);
      expect(jalali.month, (start.month - 1 + i) % 12 + 1);
      expect(jalali.day, start.day);
    }
  });

  test('repeat interval generates due dates (day/week/month)', () async {
    final base = Jalali(1404, 8, 15).toDateTime();

    Loan repeatLoan(
      String name, {
      required int repeatCount,
      required RepeatUnit unit,
      int count = 4,
    }) {
      return Loan(
        name: name,
        bank: 'بانک ملت',
        startYear: 1404,
        startMonth: 8,
        startDay: 15,
        installmentCount: count,
        repeatCount: repeatCount,
        repeatUnit: unit,
      );
    }

    // هر ۳ روز: سررسیدها ۳ روز از هم فاصله دارند
    final dayId = await DatabaseService.instance.createLoan(
      repeatLoan('وام هر ۳ روز', repeatCount: 3, unit: RepeatUnit.day),
    );
    final dayItems = await DatabaseService.instance.getInstallments(dayId);
    expect(dayItems, hasLength(4));
    for (var i = 0; i < dayItems.length; i++) {
      expect(
        DateTime.parse(dayItems[i].dueDate),
        DateTime(base.year, base.month, base.day).add(Duration(days: 3 * i)),
      );
    }

    // هر ۱ هفته: فاصله ۷ روزه
    final weekId = await DatabaseService.instance.createLoan(
      repeatLoan('وام هر هفته', repeatCount: 1, unit: RepeatUnit.week),
    );
    final weekItems = await DatabaseService.instance.getInstallments(weekId);
    for (var i = 0; i < weekItems.length; i++) {
      expect(
        DateTime.parse(weekItems[i].dueDate),
        DateTime(base.year, base.month, base.day).add(Duration(days: 7 * i)),
      );
    }

    // هر ۲ ماه: ماه‌های ۸، ۱۰، ۱۲، ۱ (سال بعد)
    final monthId = await DatabaseService.instance.createLoan(
      repeatLoan('وام هر ۲ ماه', repeatCount: 2, unit: RepeatUnit.month),
    );
    final monthItems = await DatabaseService.instance.getInstallments(monthId);
    expect(monthItems[0].dueDate, base.toIso8601String().substring(0, 10));
    for (var i = 0; i < monthItems.length; i++) {
      final j = Jalali.fromDateTime(DateTime.parse(monthItems[i].dueDate));
      expect(j.day, 15);
      expect((j.year - 1404) * 12 + j.month - 8, 2 * i);
    }
  });

  test('repeatLabel formats nicely', () {
    Loan loanWith({
      required int repeatCount,
      required RepeatUnit unit,
    }) {
      return Loan(
        name: 'x',
        bank: 'y',
        startYear: 1404,
        startMonth: 1,
        startDay: 1,
        installmentCount: 1,
        repeatCount: repeatCount,
        repeatUnit: unit,
      );
    }

    expect(
      loanWith(repeatCount: 3, unit: RepeatUnit.day).repeatLabel,
      'هر ۳ روز',
    );
    expect(
      loanWith(repeatCount: 2, unit: RepeatUnit.week).repeatLabel,
      'هر ۲ هفته',
    );
    expect(
      loanWith(repeatCount: 1, unit: RepeatUnit.month).repeatLabel,
      'هر ماه',
    );
  });

  test('repeat units are limited to day, week and month', () {
    // واحد «ساعت» حذف شده است؛ فقط روز، هفته و ماه در فهرست فرم هستند
    expect(
      RepeatUnit.values.map((unit) => unit.name).toList(),
      ['day', 'week', 'month'],
    );
    expect(
      RepeatUnit.values.map((unit) => unit.label).toList(),
      ['روز', 'هفته', 'ماه'],
    );
  });

  test('legacy hourly repeat unit migrates to daily', () {
    expect(RepeatUnit.fromName('hour'), RepeatUnit.day);
    expect(RepeatUnit.fromName('day'), RepeatUnit.day);
    expect(RepeatUnit.fromName('week'), RepeatUnit.week);
    expect(RepeatUnit.fromName('month'), RepeatUnit.month);
    expect(RepeatUnit.fromName('unknown'), RepeatUnit.month);
    expect(RepeatUnit.fromName(null), RepeatUnit.month);
  });

  test('loan name must be unique', () async {
    final id = await DatabaseService.instance.createLoan(_loan('وام مسکن'));

    // جستجو با فاصله اضافه نباید وام دیگری پیدا کند
    final duplicate = await DatabaseService.instance.getLoanByName(
      '  وام مسکن  ',
    );
    expect(duplicate, isNotNull);
    expect(duplicate!.id, id);

    // درج وام تکراری باید خطای UNIQUE بدهد
    await expectLater(
      DatabaseService.instance.createLoan(_loan('وام مسکن')),
      throwsA(isA<Exception>()),
    );

    await DatabaseService.instance.deleteLoan(id);
  });

  test('unpaid installments are sorted from nearest to farthest', () async {
    final loanA = await DatabaseService.instance.createLoan(
      _loan('وام الف', count: 3),
    );
    final loanB = await DatabaseService.instance.createLoan(
      _loan('وام ب', count: 2),
    );

    final unpaid = await DatabaseService.instance.getUnpaidInstallments();
    expect(unpaid, isNotEmpty);
    for (var i = 1; i < unpaid.length; i++) {
      expect(
        unpaid[i].installment.dueDate
            .compareTo(unpaid[i - 1].installment.dueDate),
        greaterThanOrEqualTo(0),
      );
    }

    await DatabaseService.instance.deleteLoan(loanA);
    await DatabaseService.instance.deleteLoan(loanB);
  });

  test('mark installment as paid removes it from unpaid list', () async {
    final id = await DatabaseService.instance.createLoan(_loan('وام ج'));
    final installments = await DatabaseService.instance.getInstallments(id);
    final first = installments.first;

    await DatabaseService.instance.setInstallmentPaid(first.id!, true);
    var unpaid = await DatabaseService.instance.getUnpaidInstallments();
    expect(unpaid.any((item) => item.installment.id == first.id), isFalse);

    // برگرداندن پرداخت
    await DatabaseService.instance.setInstallmentPaid(first.id!, false);
    unpaid = await DatabaseService.instance.getUnpaidInstallments();
    expect(unpaid.any((item) => item.installment.id == first.id), isTrue);

    await DatabaseService.instance.deleteLoan(id);
  });

  test('updateLoan keeps paid status for same installment numbers', () async {
    final id = await DatabaseService.instance.createLoan(
      _loan('وام د', count: 3),
    );
    final before = await DatabaseService.instance.getInstallments(id);
    await DatabaseService.instance.setInstallmentPaid(before[0].id!, true);
    await DatabaseService.instance.setInstallmentPaid(before[2].id!, true);

    final existing = await DatabaseService.instance.getLoan(id);
    await DatabaseService.instance.updateLoan(
      existing!.copyWith(
        startYear: 1404,
        startMonth: 9,
        startDay: 1,
        installmentCount: 5,
      ),
    );

    final after = await DatabaseService.instance.getInstallments(id);
    expect(after, hasLength(5));
    expect(after[0].isPaid, isTrue);
    expect(after[1].isPaid, isFalse);
    expect(after[2].isPaid, isTrue);
    expect(after[3].isPaid, isFalse);
    expect(after[4].isPaid, isFalse);

    await DatabaseService.instance.deleteLoan(id);
  });

  test('deleteLoan removes its installments too', () async {
    final id = await DatabaseService.instance.createLoan(_loan('وام ه'));
    await DatabaseService.instance.deleteLoan(id);
    expect(await DatabaseService.instance.getLoan(id), isNull);
    expect(await DatabaseService.instance.getInstallments(id), isEmpty);
  });

  test('countOverdue counts past unpaid installments', () async {
    final id = await DatabaseService.instance.createLoan(
      _loan('وام قدیمی', count: 3, startYear: 1400, startMonth: 1, startDay: 1),
    );
    final overdue = await DatabaseService.instance.countOverdue();
    expect(overdue, greaterThanOrEqualTo(3));
    await DatabaseService.instance.deleteLoan(id);
  });

  test('getLoanProgress reports paid and total per loan', () async {
    final id = await DatabaseService.instance.createLoan(
      _loan('وام پیشرفت', count: 4),
    );
    final installments = await DatabaseService.instance.getInstallments(id);
    await DatabaseService.instance
        .setInstallmentPaid(installments[0].id!, true);
    await DatabaseService.instance
        .setInstallmentPaid(installments[1].id!, true);

    final progress = await DatabaseService.instance.getLoanProgress();
    expect(progress[id], isNotNull);
    expect(progress[id]!.total, 4);
    expect(progress[id]!.paid, 2);
    expect(progress[id]!.remaining, 2);

    await DatabaseService.instance.deleteLoan(id);
  });

}
