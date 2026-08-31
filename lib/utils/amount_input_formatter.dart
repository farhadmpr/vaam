import 'package:flutter/services.dart';

import 'jalali_utils.dart';

/// فرمتر فیلد مبلغ: تبدیل ارقام فارسی/عربی به انگلیسی و نمایش با
/// جداکننده هزارگان (کاما). مثلاً «2500000» به «2,500,000» تبدیل می‌شود.
class AmountInputFormatter extends TextInputFormatter {
  AmountInputFormatter();

  static final RegExp _nonDigits = RegExp(r'[^0-9]');

  /// حداکثر طول مبلغ (۱۵ رقم تا در محدوده عددی باقی بماند)
  static const int _maxDigits = 15;

  /// گروه‌بندی رقم‌ها سه‌تا سه‌تا با کاما
  static String format(String raw) {
    var digits = JalaliUtils.toEnglishDigits(raw).replaceAll(_nonDigits, '');
    if (digits.length > _maxDigits) {
      digits = digits.substring(0, _maxDigits);
    }
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      buffer.write(digits[i]);
      final remaining = digits.length - i - 1;
      if (remaining > 0 && remaining % 3 == 0) {
        buffer.write(',');
      }
    }
    return buffer.toString();
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // تعداد رقم‌های قبل از مکان‌نما (کاماها نادیده گرفته می‌شوند) تا
    // مکان‌نما بعد از ویرایش در جای درستی بماند.
    final selection = newValue.selection;
    final clampedOffset = selection.baseOffset.clamp(0, newValue.text.length);
    final digitsBeforeCursor = newValue.text
        .substring(0, clampedOffset)
        .replaceAll(_nonDigits, '')
        .length;

    final grouped = format(newValue.text);

    // مکان‌نما بعد از [digitsBeforeCursor]امین رقم قرار می‌گیرد
    var offset = 0;
    var seen = 0;
    while (offset < grouped.length && seen < digitsBeforeCursor) {
      if (_nonDigits.hasMatch(grouped[offset])) {
        offset++;
        continue;
      }
      seen++;
      offset++;
    }

    return TextEditingValue(
      text: grouped,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}
