import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'
    show databaseFactoryFfiNoIsolate, sqfliteFfiInit;
import 'package:vaam/models/loan.dart';
import 'package:vaam/services/backup_service.dart';
import 'package:vaam/services/database_service.dart';

Loan _loan(String name, {int count = 3}) {
  return Loan(
    name: name,
    bank: 'بانک ملت',
    startYear: 1404,
    startMonth: 8,
    startDay: 15,
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

  test('backup json round trip preserves all data', () async {
    final loanA = await DatabaseService.instance.createLoan(
      _loan('وام الف', count: 3),
    );
    await DatabaseService.instance.createLoan(_loan('وام ب', count: 2));

    // یک قسط را پرداخت‌شده علامت بزن
    final installmentsA =
        await DatabaseService.instance.getInstallments(loanA);
    await DatabaseService.instance.setInstallmentPaid(installmentsA[0].id!, true);

    // ساخت پشتیبان
    final json = await BackupService.instance.buildBackupJson();
    final map = jsonDecode(json) as Map<String, dynamic>;
    expect(map['app'], 'vaam');
    expect(map['backupVersion'], 1);
    expect(map['loans'], hasLength(2));
    expect(map['installments'], hasLength(5));

    // حذف همه اطلاعات فعلی
    await DatabaseService.instance.deleteLoan(loanA);
    await DatabaseService.instance.deleteLoan(2);
    expect(await DatabaseService.instance.getLoans(), isEmpty);
    expect(await DatabaseService.instance.getAllInstallments(), isEmpty);

    // بازیابی از پشتیبان
    final summary = await BackupService.instance.restoreFromJson(json);
    expect(summary.loans, 2);
    expect(summary.installments, 5);

    // داده‌ها باید کامل برگشته باشند (حتی وضعیت پرداخت)
    final loans = await DatabaseService.instance.getLoans();
    expect(loans, hasLength(2));
    final restoredA = await DatabaseService.instance.getInstallments(loanA);
    expect(restoredA, hasLength(3));
    expect(restoredA[0].isPaid, isTrue);
    expect(restoredA[1].isPaid, isFalse);

    final unpaid = await DatabaseService.instance.getUnpaidInstallments();
    expect(unpaid, hasLength(4));
  });

  test('restoreFromJson replaces existing data completely', () async {
    // پشتیبان در وضعیت فعلی (۲ وام) گرفته می‌شود
    final json = await BackupService.instance.buildBackupJson();

    // وام اضافه‌ای بساز که در پشتیبان نیست
    final extra = await DatabaseService.instance.createLoan(_loan('وام اضافه'));
    expect((await DatabaseService.instance.getLoans()), hasLength(3));

    await BackupService.instance.restoreFromJson(json);

    // فقط وام‌های موجود در پشتیبان باید باقی بمانند
    final loans = await DatabaseService.instance.getLoans();
    expect(loans, hasLength(2));
    expect(loans.any((l) => l.name == 'وام اضافه'), isFalse);
    // اقساط وام حذف‌شده هم باید حذف شده باشند
    expect(await DatabaseService.instance.getInstallments(extra), isEmpty);
  });

  test('restoreFromJson throws on invalid content', () async {
    expect(
      () => BackupService.instance.restoreFromJson('این یک JSON نیست'),
      throwsFormatException,
    );
    expect(
      () => BackupService.instance.restoreFromJson('{"app": "other-app"}'),
      throwsFormatException,
    );
    expect(
      () => BackupService.instance.restoreFromJson('{"app": "vaam", "loans": "no"}'),
      throwsFormatException,
    );
  });
}
