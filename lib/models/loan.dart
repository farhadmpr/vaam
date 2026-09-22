import 'package:shamsi_date/shamsi_date.dart';

import '../utils/jalali_utils.dart';
import '../utils/search_utils.dart';
import 'repeat_unit.dart';

/// مدل وام بانکی
class Loan {
  final int? id;

  /// نام وام (باید یکتا باشد)
  final String name;

  /// نام بانک
  final String bank;

  /// تاریخ شروع اقساط (شمسی)
  final int startYear;
  final int startMonth;
  final int startDay;

  /// تعداد کل اقساط
  final int installmentCount;

  /// فاصله تکرار سررسیدها (مثلاً ۳ در «هر ۳ روز»)
  final int repeatCount;

  /// واحد دوره تکرار سررسیدها
  final RepeatUnit repeatUnit;

  /// مبلغ هر قسط (اختیاری)
  final double? amount;

  /// توضیحات (اختیاری)
  final String? description;

  final String? createdAt;

  const Loan({
    this.id,
    required this.name,
    required this.bank,
    required this.startYear,
    required this.startMonth,
    required this.startDay,
    required this.installmentCount,
    this.repeatCount = 1,
    this.repeatUnit = RepeatUnit.month,
    this.amount,
    this.description,
    this.createdAt,
  });

  Jalali get startJalali => Jalali(startYear, startMonth, startDay);

  /// برچسب خوانا برای دوره تکرار (مثل «هر ۳ روز» یا «هر ماه»)
  String get repeatLabel {
    final count = repeatCount < 1 ? 1 : repeatCount;
    if (count == 1) return 'هر ${repeatUnit.label}';
    return 'هر ${JalaliUtils.toPersianDigits('$count')} ${repeatUnit.label}';
  }

  /// بررسی تطابق وام با عبارت جستجو بر اساس نام وام، نام بانک و توضیحات
  /// (جستجوی چندواژه‌ای: همه واژه‌ها باید در متن وام باشند)
  bool matchesQuery(String rawQuery) {
    final words = SearchUtils.queryWords(rawQuery);
    if (words.isEmpty) return true;
    final haystack = SearchUtils.normalize('$name $bank ${description ?? ''}');
    return words.every(haystack.contains);
  }

  factory Loan.fromMap(Map<String, Object?> map) {
    return Loan(
      id: map['id'] as int?,
      name: map['name'] as String,
      bank: map['bank'] as String,
      startYear: map['start_year'] as int,
      startMonth: map['start_month'] as int,
      startDay: map['start_day'] as int,
      installmentCount: map['installment_count'] as int,
      repeatCount: (map['repeat_count'] as int?) ?? 1,
      repeatUnit: RepeatUnit.fromName(map['repeat_unit'] as String?),
      amount: (map['amount'] as num?)?.toDouble(),
      description: map['description'] as String?,
      createdAt: map['created_at'] as String?,
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name.trim(),
      'bank': bank.trim(),
      'start_year': startYear,
      'start_month': startMonth,
      'start_day': startDay,
      'installment_count': installmentCount,
      'repeat_count': repeatCount < 1 ? 1 : repeatCount,
      'repeat_unit': repeatUnit.name,
      'amount': amount,
      'description': (description == null || description!.trim().isEmpty)
          ? null
          : description!.trim(),
      if (createdAt != null) 'created_at': createdAt,
    };
  }

  Loan copyWith({
    int? id,
    String? name,
    String? bank,
    int? startYear,
    int? startMonth,
    int? startDay,
    int? installmentCount,
    int? repeatCount,
    RepeatUnit? repeatUnit,
    double? amount,
    bool clearAmount = false,
    String? description,
    bool clearDescription = false,
    String? createdAt,
  }) {
    return Loan(
      id: id ?? this.id,
      name: name ?? this.name,
      bank: bank ?? this.bank,
      startYear: startYear ?? this.startYear,
      startMonth: startMonth ?? this.startMonth,
      startDay: startDay ?? this.startDay,
      installmentCount: installmentCount ?? this.installmentCount,
      repeatCount: repeatCount ?? this.repeatCount,
      repeatUnit: repeatUnit ?? this.repeatUnit,
      amount: clearAmount ? null : (amount ?? this.amount),
      description: clearDescription
          ? null
          : (description ?? this.description),
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
