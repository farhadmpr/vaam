import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'
    show databaseFactoryFfiNoIsolate, sqfliteFfiInit;
import 'package:vaam/main.dart';
import 'package:vaam/models/loan.dart';
import 'package:vaam/services/database_service.dart';
import 'package:vaam/services/settings_service.dart';

void main() {
  // پیاده‌سازی ffi بدون ایزولیت تا در FakeAsync تست ویجت کار کند
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfiNoIsolate;
  // دیتابیس درون‌حافظه‌ای: بدون file IO ناهمگام که در FakeAsync متوقف می‌ماند
  DatabaseService.instance.useInMemoryDatabaseForTest();

  setUpAll(() async {
    await DatabaseService.instance.resetForTest();
  });

  /// ساخت مجدد درخت ویجت تا تنظیمات جدید خوانده شود
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(const VaamApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  /// اسکرول تا انتهای لیست تا آیتم‌های تنبلِ پایین (مثل پیام مخفی‌شدن)
  /// ساخته شوند
  Future<void> scrollToBottom(WidgetTester tester) async {
    await tester.drag(find.byType(ListView).first, const Offset(0, -30000));
    await tester.pumpAndSettle();
  }

  testWidgets('app builds and shows the home page', (tester) async {
    await tester.pumpWidget(const VaamApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // عنوان صفحه اصلی
    expect(find.text('اقساط وام'), findsOneWidget);

    // لودینگ باید تمام شده باشد
    expect(
      find.byType(CircularProgressIndicator),
      findsNothing,
      reason: 'Loading indicator should disappear after data loads',
    );

    // چون دیتابیس خالی است، حالت خالی نمایش داده می‌شود
    expect(find.text('قسط پرداخت‌نشده‌ای وجود ندارد 🎉'), findsOneWidget);
  });

  testWidgets('home page limits the visible installments', (tester) async {
    // ۱۲ وام تک‌قسطی با سررسید آینده
    for (var i = 1; i <= 12; i++) {
      await DatabaseService.instance.createLoan(
        Loan(
          name: 'وام تست $i',
          bank: 'بانک تست',
          startYear: 1410,
          startMonth: 1,
          startDay: 10,
          installmentCount: 1,
        ),
      );
    }

    // پیش‌فرض: ۱۰ قسط نزدیک نمایش داده می‌شود و ۲ قسط مخفی می‌ماند
    SettingsService.instance.homeLimit = SettingsService.defaultHomeLimit;
    await pumpApp(tester);
    // خلاصه: کل اقساط پرداخت‌نشده
    expect(find.text('۱۲'), findsOneWidget);
    await scrollToBottom(tester);
    // پیام مخفی‌شدن: ۱۲ - ۱۰ = ۲
    expect(find.textContaining('۲ قسط دیگر'), findsOneWidget);

    // تغییر محدودیت به ۵ قسط: ۷ قسط مخفی می‌شود
    SettingsService.instance.homeLimit = 5;
    await pumpApp(tester);
    await scrollToBottom(tester);
    expect(find.textContaining('۷ قسط دیگر'), findsOneWidget);

    // با محدودیت بزرگ‌تر از تعداد اقساط، پیام مخفی‌شدن نمایش داده نمی‌شود
    SettingsService.instance.homeLimit = 50;
    await pumpApp(tester);
    await scrollToBottom(tester);
    expect(find.textContaining('قسط دیگر'), findsNothing);
  });

  testWidgets('home page search filters installments', (tester) async {
    // دو وام با نام/توضیحات متمایز (تست قبلی ۱۲ «وام تست» ساخته است)
    await DatabaseService.instance.createLoan(
      Loan(
        name: 'وام مسکن شهری',
        bank: 'بانک ملت',
        startYear: 1410,
        startMonth: 2,
        startDay: 10,
        installmentCount: 1,
        description: 'تسهیل خرید ملک',
      ),
    );
    await DatabaseService.instance.createLoan(
      Loan(
        name: 'وام خودرو',
        bank: 'بانک سامان',
        startYear: 1410,
        startMonth: 3,
        startDay: 10,
        installmentCount: 1,
        description: 'خرید خودرو صفر',
      ),
    );

    await pumpApp(tester);

    // باز کردن جستجو و تایپ عبارت
    await tester.tap(find.byIcon(Icons.search));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'خودرو');
    await tester.pumpAndSettle();

    // فقط وام خودرو باید دیده شود
    expect(find.text('وام خودرو'), findsOneWidget);
    expect(find.text('وام مسکن شهری'), findsNothing);

    // جستجو بر اساس توضیحات
    await tester.enterText(find.byType(TextField), 'خرید ملک');
    await tester.pumpAndSettle();
    expect(find.text('وام مسکن شهری'), findsOneWidget);
    expect(find.text('وام خودرو'), findsNothing);

    // بستن جستجو: عبارت پاک و همه اقساط برمی‌گردند
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(find.text('۱۴'), findsOneWidget); // ۱۲ تست + ۲ جدید
  });

  testWidgets('loans page search filters loans', (tester) async {
    await DatabaseService.instance.createLoan(
      Loan(
        name: 'وام آلفا',
        bank: 'بانک آلفا',
        startYear: 1410,
        startMonth: 4,
        startDay: 10,
        installmentCount: 1,
      ),
    );

    await pumpApp(tester);

    // رفتن به صفحه وام‌ها
    await tester.tap(find.byIcon(Icons.account_balance_outlined));
    await tester.pumpAndSettle();

    // باز کردن جستجو و تایپ
    await tester.tap(find.byIcon(Icons.search));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'آلفا');
    await tester.pumpAndSettle();
    expect(find.text('وام آلفا'), findsOneWidget);
    expect(find.text('وام تست 1'), findsNothing);

    // بستن جستجو: «وام آلفا» به‌عنوان اولین وام (ترتیب الفبایی) دیده می‌شود
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text('وام آلفا'), findsOneWidget);
  });
}
