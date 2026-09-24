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
  static const String _keyType = 'notify_type';
  static const String _keyHomeLimit = 'home_limit';

  /// کلیدهای قدیمیِ «ساعت نوتیفیکیشن سراسری» (نسخه‌های پیشین برنامه).
  /// از این نسخه، فعال بودن یادآوری و ساعت آن برای هر وام جداگانه در خودِ
  /// وام ذخیره می‌شود (`Loan.notifyEnabled` / `notifyHour` / `notifyMinute`)
  /// و این کلیدها فقط برای مهاجرت یک‌بارهٔ داده‌ها در
  /// `DatabaseService._onUpgrade` خوانده می‌شوند.
  static const String legacyNotifyHourKey = 'notify_hour';
  static const String legacyNotifyMinuteKey = 'notify_minute';

  /// حداکثر تعداد اقساط نمایش‌داده‌شده در صفحه اصلی
  static const int defaultHomeLimit = 10;
  static const int minHomeLimit = 1;
  static const int maxHomeLimit = 200;

  /// کلید اصلی همه یادآوری‌ها؛ با خاموش شدن آن هیچ نوتیفیکیشنی برای هیچ
  /// وامی زمان‌بندی نمی‌شود. فعال/غیرفعال بودن و ساعت یادآوری هر وام در
  /// فرم ثبت/ویرایش همان وام تعیین می‌شود.
  bool notificationsEnabled = true;

  /// نوع نوتیفیکیشن
  NotificationType notificationType = NotificationType.systemDefault;

  /// حداکثر تعداد اقساط پرداخت‌نشده‌ای که در صفحه اصلی نمایش داده می‌شود
  int homeLimit = defaultHomeLimit;

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    notificationsEnabled = sp.getBool(_keyEnabled) ?? true;
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
    await sp.setString(_keyType, notificationType.name);
    await sp.setInt(
      _keyHomeLimit,
      homeLimit.clamp(minHomeLimit, maxHomeLimit),
    );
  }
}
