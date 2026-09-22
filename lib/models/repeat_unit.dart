/// واحد دوره تکرار سررسیدها
enum RepeatUnit {
  hour('ساعت'),
  day('روز'),
  week('هفته'),
  month('ماه');

  const RepeatUnit(this.label);

  final String label;

  /// خواندن واحد از دیتابیس/فایل پشتیبان؛ مقدار نامعتبر → ماهانه
  static RepeatUnit fromName(String? name) {
    return RepeatUnit.values.firstWhere(
      (unit) => unit.name == name,
      orElse: () => RepeatUnit.month,
    );
  }
}
