import 'package:shared_preferences/shared_preferences.dart';

/// نوع نوتیفیکیشن
enum NotificationType {
  systemDefault('پیش‌فرض سیستم'),
  sound('با صدا'),
  vibration('فقط لرزش'),
  silent('بی‌صدا');

  const NotificationType(this.label);

  final String label;
}

/// تنظیمات برنامه (ذخیره‌شده در SharedPreferences)
class SettingsService {
  SettingsService._();

  static final SettingsService instance = SettingsService._();

  static const String _keyEnabled = 'notify_enabled';
  static const String _keyHour = 'notify_hour';
  static const String _keyMinute = 'notify_minute';
  static const String _keyType = 'notify_type';
  static const String _keyHomeLimit = 'home_limit';

  /// حداکثر تعداد اقساط نمایش‌داده‌شده در صفحه اصلی
  static const int defaultHomeLimit = 10;
  static const int minHomeLimit = 1;
  static const int maxHomeLimit = 200;

  /// آیا نوتیفیکیشن فعال است
  bool notificationsEnabled = true;

  /// ساعت نمایش نوتیفیکیشن (۲۴ ساعته)
  int notifyHour = 9;
  int notifyMinute = 0;

  /// نوع نوتیفیکیشن
  NotificationType notificationType = NotificationType.systemDefault;

  /// حداکثر تعداد اقساط پرداخت‌نشده‌ای که در صفحه اصلی نمایش داده می‌شود
  int homeLimit = defaultHomeLimit;

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    notificationsEnabled = sp.getBool(_keyEnabled) ?? true;
    notifyHour = sp.getInt(_keyHour) ?? 9;
    notifyMinute = sp.getInt(_keyMinute) ?? 0;
    final typeName = sp.getString(_keyType);
    notificationType = NotificationType.values.firstWhere(
      (type) => type.name == typeName,
      orElse: () => NotificationType.systemDefault,
    );
    homeLimit = (sp.getInt(_keyHomeLimit) ?? defaultHomeLimit)
        .clamp(minHomeLimit, maxHomeLimit);
  }

  Future<void> save() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_keyEnabled, notificationsEnabled);
    await sp.setInt(_keyHour, notifyHour.clamp(0, 23));
    await sp.setInt(_keyMinute, notifyMinute.clamp(0, 59));
    await sp.setString(_keyType, notificationType.name);
    await sp.setInt(
      _keyHomeLimit,
      homeLimit.clamp(minHomeLimit, maxHomeLimit),
    );
  }
}
