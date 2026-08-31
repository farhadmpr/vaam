import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'
    show databaseFactoryFfiNoIsolate, sqfliteFfiInit;
import 'package:vaam/main.dart';
import 'package:vaam/services/database_service.dart';

void main() {
  // پیاده‌سازی ffi بدون ایزولیت تا در FakeAsync تست ویجت کار کند
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfiNoIsolate;
  // دیتابیس درون‌حافظه‌ای: بدون file IO ناهمگام که در FakeAsync متوقف می‌ماند
  DatabaseService.instance.useInMemoryDatabaseForTest();

  setUpAll(() async {
    await DatabaseService.instance.resetForTest();
  });

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
}
