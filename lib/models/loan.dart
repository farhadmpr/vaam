import 'package:shamsi_date/shamsi_date.dart';

import '../utils/search_utils.dart';

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
    this.amount,
    this.description,
    this.createdAt,
  });

  Jalali get startJalali => Jalali(startYear, startMonth, startDay);

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
      amount: clearAmount ? null : (amount ?? this.amount),
      description: clearDescription
          ? null
          : (description ?? this.description),
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
