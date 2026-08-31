import 'loan.dart';

/// مدل قسط وام
class Installment {
  final int? id;
  final int loanId;

  /// شماره قسط (۱ تا تعداد کل)
  final int number;

  /// تاریخ سررسید با فرمت yyyy-MM-dd (میلادی؛ برای نمایش به شمسی تبدیل می‌شود)
  final String dueDate;

  /// آیا پرداخت شده است
  final bool isPaid;

  /// زمان ثبت پرداخت
  final String? paidAt;

  const Installment({
    this.id,
    required this.loanId,
    required this.number,
    required this.dueDate,
    this.isPaid = false,
    this.paidAt,
  });

  DateTime get dueDateTime => DateTime.parse(dueDate);

  factory Installment.fromMap(Map<String, Object?> map) {
    return Installment(
      id: map['id'] as int?,
      loanId: map['loan_id'] as int,
      number: map['number'] as int,
      dueDate: map['due_date'] as String,
      isPaid: (map['is_paid'] as int? ?? 0) == 1,
      paidAt: map['paid_at'] as String?,
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'loan_id': loanId,
      'number': number,
      'due_date': dueDate,
      'is_paid': isPaid ? 1 : 0,
      'paid_at': paidAt,
    };
  }

  Installment copyWith({
    bool? isPaid,
    String? paidAt,
    bool clearPaidAt = false,
  }) {
    return Installment(
      id: id,
      loanId: loanId,
      number: number,
      dueDate: dueDate,
      isPaid: isPaid ?? this.isPaid,
      paidAt: clearPaidAt ? null : (paidAt ?? this.paidAt),
    );
  }
}

/// قسط به همراه وام مرتبط آن (برای نمایش در صفحه اصلی)
class UnpaidInstallment {
  final Installment installment;
  final Loan loan;

  const UnpaidInstallment({
    required this.installment,
    required this.loan,
  });
}
