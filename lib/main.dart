import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'pages/home_page.dart';
import 'pages/loan_details_page.dart';
import 'services/database_service.dart';
import 'services/notification_service.dart';
import 'services/settings_service.dart';

/// کلید سراسری ناوبری برای باز کردن صفحه جزئیات وام پس از لمس نوتیفیکیشن
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // بارگذاری تنظیمات و آماده‌سازی دیتابیس
  await SettingsService.instance.load();
  await DatabaseService.instance.database;

  // راه‌اندازی نوتیفیکیشن و زمان‌بندی اقساط پرداخت‌نشده
  await NotificationService.instance.init(onTap: _handleNotificationTap);
  await NotificationService.instance.rescheduleAll();

  runApp(const VaamApp());

  // هشدار اقساط عقب‌افتاده هنگام شروع برنامه
  final overdueCount = await DatabaseService.instance.countOverdue();
  if (overdueCount > 0) {
    await NotificationService.instance.showOverdueNotice(overdueCount);
  }

  // اگر برنامه با لمس نوتیفیکیشن باز شده باشد، جزئیات وام نمایش داده می‌شود
  final launchLoanId = await NotificationService.instance.launchLoanId();
  if (launchLoanId != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      navigatorKey.currentState?.push(
        MaterialPageRoute<void>(
          builder: (_) => LoanDetailsPage(loanId: launchLoanId),
        ),
      );
    });
  }
}

void _handleNotificationTap(NotificationResponse response) {
  final loanId = NotificationService.loanIdFromPayload(response.payload);
  if (loanId != null) {
    navigatorKey.currentState?.push(
      MaterialPageRoute<void>(
        builder: (_) => LoanDetailsPage(loanId: loanId),
      ),
    );
  }
}

class VaamApp extends StatelessWidget {
  const VaamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'مدیریت اقساط وام',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      locale: const Locale('fa'),
      supportedLocales: const [Locale('fa')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF00695C),
        fontFamily: 'Vazirmatn',
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          isDense: true,
        ),
      ),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const HomePage(),
    );
  }
}
