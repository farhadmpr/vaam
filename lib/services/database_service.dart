import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shamsi_date/shamsi_date.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../models/installment.dart';
import '../models/loan.dart';
import '../models/repeat_unit.dart';
import '../utils/jalali_utils.dart';
import 'settings_service.dart';

/// آمار پیشرفت پرداخت یک وام
class LoanProgress {
  final int total;
  final int paid;

  const LoanProgress({required this.total, required this.paid});

  int get remaining => total - paid;
}

/// سرویس ذخیره‌سازی (SQLite) برای وام‌ها و اقساط
class DatabaseService {
  DatabaseService._();

  static final DatabaseService instance = DatabaseService._();

  static const String _dbName = 'vaam.db';
  static const int _dbVersion = 3;

  Database? _db;

  /// فقط برای تست: در صورت فعال‌سازی، دیتابیس درون‌حافظه‌ای استفاده می‌شود
  String? _debugPathOverride;

  @visibleForTesting
  void useInMemoryDatabaseForTest() {
    _debugPathOverride = inMemoryDatabasePath;
  }

  /// فقط برای تست: استفاده از دیتابیس موجود در مسیر دلخواه
  /// (برای بررسی مهاجرت نسخه‌های قدیمی)
  @visibleForTesting
  void useDatabasePathForTest(String path) {
    _debugPathOverride = path;
  }

  Future<Database> get database async {
    final existing = _db;
    if (existing != null) return existing;
    final opened = await _open();
    _db = opened;
    return opened;
  }

  Future<Database> _open() async {
    final pathOverride = _debugPathOverride;
    if (pathOverride != null) {
      return openDatabase(
        pathOverride,
        version: _dbVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
    }
    final dir = await getDatabasesPath();
    return openDatabase(
      p.join(dir, _dbName),
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
        await db.execute('''
          CREATE TABLE loans (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE,
            bank TEXT NOT NULL,
            start_year INTEGER NOT NULL,
            start_month INTEGER NOT NULL,
            start_day INTEGER NOT NULL,
            installment_count INTEGER NOT NULL,
            repeat_count INTEGER NOT NULL DEFAULT 1,
            repeat_unit TEXT NOT NULL DEFAULT 'month',
            amount REAL,
            description TEXT,
            notify_enabled INTEGER NOT NULL DEFAULT 1,
            notify_hour INTEGER NOT NULL DEFAULT 9,
            notify_minute INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE installments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            loan_id INTEGER NOT NULL,
            number INTEGER NOT NULL,
            due_date TEXT NOT NULL,
            is_paid INTEGER NOT NULL DEFAULT 0,
            paid_at TEXT,
            FOREIGN KEY (loan_id) REFERENCES loans (id) ON DELETE CASCADE
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_installments_loan_id ON installments(loan_id)',
        );
        await db.execute(
          'CREATE INDEX idx_installments_unpaid ON installments(is_paid, due_date)',
        );
  }

  /// ارتقای ساختار دیتابیس از نسخه‌های قدیمی‌تر
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // افزودن دوره تکرار سررسیدها (وام‌های قبلی: ماهانه)
      await db.execute(
        'ALTER TABLE loans ADD COLUMN repeat_count INTEGER NOT NULL DEFAULT 1',
      );
      await db.execute(
        "ALTER TABLE loans ADD COLUMN repeat_unit TEXT NOT NULL DEFAULT 'month'",
      );
    }
    if (oldVersion < 3) {
      // از این نسخه، فعال بودن یادآوری و ساعت آن برای هر وام جداگانه ذخیره
      // می‌شود. ساعتِ تنظیماتِ سراسریِ نسخه‌های قبلی به عنوان مقدار اولیه
      // وام‌های موجود منتقل می‌شود تا انتخاب قبلی کاربر حفظ شود.
      final legacy = await _legacyNotifyTime();
      await db.execute(
        'ALTER TABLE loans ADD COLUMN notify_enabled INTEGER NOT NULL DEFAULT 1',
      );
      await db.execute(
        'ALTER TABLE loans ADD COLUMN notify_hour '
        'INTEGER NOT NULL DEFAULT ${legacy.$1}',
      );
      await db.execute(
        'ALTER TABLE loans ADD COLUMN notify_minute '
        'INTEGER NOT NULL DEFAULT ${legacy.$2}',
      );
    }
  }

  /// ساعت یادآوریِ تنظیماتِ سراسری نسخه‌های پیشین برنامه (پیش‌فرض: ۹:۰۰)
  static Future<(int, int)> _legacyNotifyTime() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final hour =
          (sp.getInt(SettingsService.legacyNotifyHourKey) ??
                  Loan.defaultNotifyHour)
              .clamp(0, 23);
      final minute =
          (sp.getInt(SettingsService.legacyNotifyMinuteKey) ??
                  Loan.defaultNotifyMinute)
              .clamp(0, 59);
      return (hour, minute);
    } catch (_) {
      // اگر تنظیمات در دسترس نبود، مقدار پیش‌فرض استفاده می‌شود
      return (Loan.defaultNotifyHour, Loan.defaultNotifyMinute);
    }
  }

  /// تولید تاریخ‌های سررسید بر اساس دوره تکرار وام:
  /// ماهانه بر اساس تقویم شمسی (با اصلاح روز)؛
  /// هفته و روز با گام ثابت از تاریخ شروع
  static List<String> generateDueDates(Loan loan) {
    final count = loan.installmentCount;
    final step = loan.repeatCount < 1 ? 1 : loan.repeatCount;
    switch (loan.repeatUnit) {
      case RepeatUnit.month:
        final start = loan.startJalali;
        return [
          for (var i = 0; i < count; i++)
            JalaliUtils.toIsoDate(
              JalaliUtils.addMonths(start, step * i).toDateTime(),
            ),
        ];
      case RepeatUnit.week:
        return _stepDates(loan.startJalali, Duration(days: 7 * step), count);
      case RepeatUnit.day:
        return _stepDates(loan.startJalali, Duration(days: step), count);
    }
  }

  /// گام‌برداری ثابت روی تاریخ‌ها (در UTC تا تغییر ساعت روی تاریخ اثر نگذارد)
  static List<String> _stepDates(Jalali start, Duration step, int count) {
    final gregorian = start.toGregorian();
    final base = DateTime.utc(gregorian.year, gregorian.month, gregorian.day);
    return [
      for (var i = 0; i < count; i++) JalaliUtils.toIsoDate(base.add(step * i)),
    ];
  }

  // ---------- وام‌ها ----------

  /// لیست همه وام‌ها مرتب بر اساس نام
  Future<List<Loan>> getLoans() async {
    final db = await database;
    final rows = await db.query('loans', orderBy: 'name COLLATE NOCASE');
    return [for (final row in rows) Loan.fromMap(row)];
  }

  Future<Loan?> getLoan(int id) async {
    final db = await database;
    final rows = await db.query(
      'loans',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Loan.fromMap(rows.first);
  }

  /// جستجوی وام بر اساس نام (بدون حساسیت به فاصله و حروف بزرگ/کوچک)
  Future<Loan?> getLoanByName(String name) async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT * FROM loans WHERE LOWER(TRIM(name)) = LOWER(?) LIMIT 1',
      [name.trim()],
    );
    return rows.isEmpty ? null : Loan.fromMap(rows.first);
  }

  /// ثبت وام جدید به همراه اقساط آن بر اساس دوره تکرار
  Future<int> createLoan(Loan loan) async {
    final db = await database;
    final dueDates = generateDueDates(loan);
    return db.transaction((txn) async {
      final map = loan.toMap();
      map['created_at'] ??= DateTime.now().toIso8601String();
      final id = await txn.insert('loans', map);
      final batch = txn.batch();
      for (var i = 0; i < dueDates.length; i++) {
        batch.insert(
          'installments',
          Installment(
            loanId: id,
            number: i + 1,
            dueDate: dueDates[i],
          ).toMap(),
        );
      }
      await batch.commit(noResult: true);
      return id;
    });
  }

  /// ویرایش وام. اگر تاریخ شروع، دوره تکرار یا تعداد اقساط تغییر کند اقساط
  /// از نو ساخته می‌شوند و وضعیت «پرداخت‌شده» اقساطی که شماره یکسانی دارند
  /// حفظ می‌شود.
  Future<void> updateLoan(Loan loan) async {
    final db = await database;
    final dueDates = generateDueDates(loan);
    await db.transaction((txn) async {
      final oldRows = await txn.query(
        'installments',
        where: 'loan_id = ?',
        whereArgs: [loan.id],
        columns: ['number', 'is_paid', 'paid_at'],
      );
      final paidByNumber = <int, String?>{
        for (final row in oldRows)
          if ((row['is_paid'] as int) == 1)
            row['number'] as int: row['paid_at'] as String?,
      };

      await txn.update(
        'loans',
        loan.toMap(),
        where: 'id = ?',
        whereArgs: [loan.id],
      );
      await txn.delete('installments', where: 'loan_id = ?', whereArgs: [loan.id]);

      final batch = txn.batch();
      for (var i = 0; i < dueDates.length; i++) {
        final number = i + 1;
        final wasPaid = paidByNumber.containsKey(number);
        batch.insert(
          'installments',
          Installment(
            loanId: loan.id!,
            number: number,
            dueDate: dueDates[i],
            isPaid: wasPaid,
            paidAt: wasPaid
                ? (paidByNumber[number] ?? DateTime.now().toIso8601String())
                : null,
          ).toMap(),
        );
      }
      await batch.commit(noResult: true);
    });
  }

  /// حذف وام به همراه تمام اقساط آن
  Future<void> deleteLoan(int loanId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('installments', where: 'loan_id = ?', whereArgs: [loanId]);
      await txn.delete('loans', where: 'id = ?', whereArgs: [loanId]);
    });
  }

  // ---------- اقساط ----------

  /// همه اقساط یک وام (به ترتیب سررسید)
  Future<List<Installment>> getInstallments(int loanId) async {
    final db = await database;
    final rows = await db.query(
      'installments',
      where: 'loan_id = ?',
      whereArgs: [loanId],
      orderBy: 'due_date ASC, number ASC',
    );
    return [for (final row in rows) Installment.fromMap(row)];
  }

  /// همه اقساط همه وام‌ها (برای تهیه فایل پشتیبان)
  Future<List<Installment>> getAllInstallments() async {
    final db = await database;
    final rows = await db.query(
      'installments',
      orderBy: 'loan_id ASC, number ASC',
    );
    return [for (final row in rows) Installment.fromMap(row)];
  }

  /// بازگرداندن کامل اطلاعات از فایل پشتیبان:
  /// تمام داده‌های فعلی حذف و داده‌های پشتیبان (با همان شناسه‌ها) درج می‌شوند
  Future<void> restoreAll({
    required List<Loan> loans,
    required List<Installment> installments,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('installments');
      await txn.delete('loans');

      final batch = txn.batch();
      for (final loan in loans) {
        batch.insert(
          'loans',
          loan.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final installment in installments) {
        batch.insert(
          'installments',
          installment.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  /// اقساط پرداخت‌نشده همه وام‌ها مرتب‌شده از نزدیک‌ترین سررسید به دورترین
  Future<List<UnpaidInstallment>> getUnpaidInstallments() async {
    final db = await database;
    final rows = await db.query(
      'installments',
      where: 'is_paid = 0',
      orderBy: 'due_date ASC, number ASC',
    );
    if (rows.isEmpty) return [];

    final loans = <int, Loan>{
      for (final row in await db.query('loans'))
        row['id'] as int: Loan.fromMap(row),
    };

    final result = <UnpaidInstallment>[];
    for (final row in rows) {
      final loan = loans[row['loan_id'] as int];
      if (loan != null) {
        result.add(
          UnpaidInstallment(
            installment: Installment.fromMap(row),
            loan: loan,
          ),
        );
      }
    }
    return result;
  }

  /// تعداد اقساط عقب‌افتاده (سررسید گذشته و پرداخت‌نشده)
  Future<int> countOverdue() async {
    final db = await database;
    final today = JalaliUtils.toIsoDate(DateTime.now());
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM installments WHERE is_paid = 0 AND due_date < ?',
      [today],
    );
    return (rows.first['c'] as int?) ?? 0;
  }

  /// علامت‌گذاری قسط به‌عنوان پرداخت‌شده یا لغو پرداخت
  Future<void> setInstallmentPaid(int installmentId, bool paid) async {
    final db = await database;
    await db.update(
      'installments',
      {
        'is_paid': paid ? 1 : 0,
        'paid_at': paid ? DateTime.now().toIso8601String() : null,
      },
      where: 'id = ?',
      whereArgs: [installmentId],
    );
  }

  /// آمار پرداخت هر وام (کل / پرداخت‌شده)
  Future<Map<int, LoanProgress>> getLoanProgress() async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT loan_id, COUNT(*) AS total, SUM(is_paid) AS paid '
      'FROM installments GROUP BY loan_id',
    );
    return {
      for (final row in rows)
        row['loan_id'] as int: LoanProgress(
          total: (row['total'] as int?) ?? 0,
          paid: (row['paid'] as int?) ?? 0,
        ),
    };
  }

  /// فقط برای تست‌ها: بستن و حذف کامل دیتابیس
  @visibleForTesting
  Future<void> resetForTest() async {
    final existing = _db;
    _db = null;
    await existing?.close();
    final pathOverride = _debugPathOverride;
    if (pathOverride != null && pathOverride == inMemoryDatabasePath) {
      return; // دیتابیس درون‌حافظه‌ای است
    }
    final path = pathOverride ?? p.join(await getDatabasesPath(), _dbName);
    if (await databaseExists(path)) {
      await deleteDatabase(path);
    }
  }

}
