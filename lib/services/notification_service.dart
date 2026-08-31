import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../utils/jalali_utils.dart';
import 'database_service.dart';
import 'settings_service.dart';

/// سرویس نوتیفیکیشن: زمان‌بندی یادآوری سررسید اقساط
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // کانال‌های مجزا برای هر نوع نوتیفیکیشن (اندروید ۸ به بالا تنظیمات کانال
  // را در اولین نمایش قفل می‌کند، بنابراین هر نوع کانال خودش را دارد)
  static const String _channelDefault = 'loan_reminders_default';
  static const String _channelSound = 'loan_reminders_sound';
  static const String _channelVibration = 'loan_reminders_vibration';
  static const String _channelSilent = 'loan_reminders_silent';

  static const String _payloadPrefix = 'loan:';

  /// ساخت payload برای باز کردن جزئیات وام پس از لمس نوتیفیکیشن
  static String loanPayload(int loanId) => '$_payloadPrefix$loanId';

  /// استخراج شناسه وام از payload
  static int? loanIdFromPayload(String? payload) {
    if (payload == null || !payload.startsWith(_payloadPrefix)) return null;
    return int.tryParse(payload.substring(_payloadPrefix.length));
  }

  Future<void> init({
    void Function(NotificationResponse response)? onTap,
  }) async {
    if (_initialized) return;

    // راه‌اندازی پایگاه داده مناطق زمانی و تنظیم منطقه محلی دستگاه
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // در صورت خطا، tz.local روی UTC باقی می‌ماند
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
    );

    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (response) => onTap?.call(response),
    );

    // درخواست مجوزها (اندروید ۱۳ به بالا برای نمایش و اندروید ۱۲ به بالا
    // برای زمان‌بندی دقیق)
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      try {
        await android?.requestNotificationsPermission();
      } catch (_) {}
      try {
        await android?.requestExactAlarmsPermission();
      } catch (_) {}
    }

    _initialized = true;
  }

  AndroidNotificationDetails _androidDetails() {
    const channelName = 'یادآوری اقساط وام';
    const channelDescription = 'نوتیفیکیشن سررسید اقساط وام‌های بانکی';
    const bigText = BigTextStyleInformation('');

    switch (SettingsService.instance.notificationType) {
      case NotificationType.sound:
        return const AndroidNotificationDetails(
          _channelSound,
          channelName,
          channelDescription: channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: false,
          styleInformation: bigText,
        );
      case NotificationType.vibration:
        return const AndroidNotificationDetails(
          _channelVibration,
          channelName,
          channelDescription: channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          playSound: false,
          enableVibration: true,
          styleInformation: bigText,
        );
      case NotificationType.silent:
        return const AndroidNotificationDetails(
          _channelSilent,
          channelName,
          channelDescription: channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          playSound: false,
          enableVibration: false,
          styleInformation: bigText,
        );
      case NotificationType.systemDefault:
        return const AndroidNotificationDetails(
          _channelDefault,
          channelName,
          channelDescription: channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: bigText,
        );
    }
  }

  NotificationDetails get _details => NotificationDetails(
        android: _androidDetails(),
        iOS: const DarwinNotificationDetails(),
      );

  Future<bool> get _canScheduleExact async {
    if (defaultTargetPlatform != TargetPlatform.android) return true;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    final can = await android?.canScheduleExactNotifications();
    return can ?? false;
  }

  /// زمان‌بندی مجدد تمام نوتیفیکیشن‌ها بر اساس اقساط پرداخت‌نشده و تنظیمات
  ///
  /// برای هر قسط پرداخت‌نشده‌ای که سررسید آن در آینده است، یک نوتیفیکیشن
  /// در «روز سررسید + ساعت تنظیم‌شده» زمان‌بندی می‌شود.
  Future<void> rescheduleAll() async {
    if (!_initialized) return;

    await _plugin.cancelAll();

    final settings = SettingsService.instance;
    if (!settings.notificationsEnabled) return;

    final unpaid = await DatabaseService.instance.getUnpaidInstallments();
    final now = DateTime.now();

    // سقف تعداد زمان‌بندی برای جلوگیری از فشار بیش از حد روی AlarmManager
    const maxScheduled = 100;
    var scheduled = 0;

    for (final item in unpaid) {
      final due = item.installment.dueDateTime;
      final notifyAt = DateTime(
        due.year,
        due.month,
        due.day,
        settings.notifyHour,
        settings.notifyMinute,
      );
      // سررسید گذشته در برنامه نمایش داده می‌شود و نوتیفیکیشن ندارد
      if (!notifyAt.isAfter(now)) continue;
      if (scheduled >= maxScheduled) break;

      final body = StringBuffer('بانک ${item.loan.bank}')
        ..write(' • سررسید: ${JalaliUtils.formatDateTime(due)}');
      if (item.loan.amount != null) {
        body.write(
            ' • مبلغ: ${JalaliUtils.formatAmount(item.loan.amount!)} تومان');
      }

      await _schedule(
        id: item.installment.id!,
        title: 'قسط ${JalaliUtils.toPersianDigits('${item.installment.number}')} '
            'از ${JalaliUtils.toPersianDigits('${item.loan.installmentCount}')} '
            '— ${item.loan.name}',
        body: body.toString(),
        when: tz.TZDateTime.from(notifyAt, tz.local),
        payload: loanPayload(item.loan.id!),
      );
      scheduled++;
    }
  }

  Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime when,
    required String payload,
  }) async {
    final scheduleMode = (await _canScheduleExact)
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: when,
        notificationDetails: _details,
        androidScheduleMode: scheduleMode,
        payload: payload,
      );
    } catch (_) {
      // در صورت خطای زمان‌بندی دقیق، با حالت inexact تلاش می‌شود
      try {
        await _plugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: when,
          notificationDetails: _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: payload,
        );
      } catch (_) {
        // نادیده گرفتن؛ در اجرای بعدی برنامه دوباره زمان‌بندی می‌شود
      }
    }
  }

  /// نوتیفیکیشن آزمایشی برای بررسی تنظیمات
  Future<void> showTestNotification() async {
    await _plugin.show(
      id: 2147480001,
      title: 'نوتیفیکیشن آزمایشی',
      body: 'تنظیمات نوتیفیکیشن با موفقیت اعمال شد ✅',
      notificationDetails: _details,
    );
  }

  /// هشدار اقساط عقب‌افتاده هنگام شروع برنامه
  Future<void> showOverdueNotice(int count) async {
    await _plugin.show(
      id: 2147480002,
      title: 'یادآوری اقساط',
      body: '${JalaliUtils.toPersianDigits('$count')} قسط عقب‌افتاده '
          'پرداخت‌نشده دارید. برنامه را باز کنید.',
      notificationDetails: _details,
    );
  }

  /// اگر برنامه با لمس نوتیفیکیشن اجرا شده باشد، شناسه وام برمی‌گرداند
  Future<int?> launchLoanId() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp != true) return null;
    return loanIdFromPayload(details?.notificationResponse?.payload);
  }


}
