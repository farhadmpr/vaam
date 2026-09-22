/// واحد دوره تکرار سررسیدها
enum RepeatUnit {
  day('روز'),
  week('هفته'),
  month('ماه');

  const RepeatUnit(this.label);

  final String label;

  /// خواندن واحد از دیتابیس/فایل پشتیبان؛
  /// واحد حذف‌شده «ساعت» (hour) به «روز» مهاجرت می‌کند و
  /// مقادیر نامعتبر به «ماه» برمی‌گردند
  static RepeatUnit fromName(String? name) {
    switch (name) {
      case 'hour':
      case 'day':
        return RepeatUnit.day;
      case 'week':
        return RepeatUnit.week;
      case 'month':
        return RepeatUnit.month;
      default:
        return RepeatUnit.month;
    }
  }
}

