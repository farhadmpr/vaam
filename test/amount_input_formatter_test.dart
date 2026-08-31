import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaam/utils/amount_input_formatter.dart';

void main() {
  final formatter = AmountInputFormatter();

  TextEditingValue edit(String oldText, String newText, {int? offset}) {
    return formatter.formatEditUpdate(
      TextEditingValue(text: oldText),
      TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: offset ?? newText.length,
        ),
      ),
    );
  }

  test('groups digits by thousands with commas', () {
    expect(AmountInputFormatter.format('2500000'), '2,500,000');
    expect(AmountInputFormatter.format('950'), '950');
    expect(AmountInputFormatter.format('1000'), '1,000');
    expect(AmountInputFormatter.format('12000000'), '12,000,000');
    expect(AmountInputFormatter.format(''), '');
  });

  test('converts persian digits and strips other separators', () {
    expect(AmountInputFormatter.format('۲,۵۰۰'), '2,500');
    expect(AmountInputFormatter.format('۱۲۳۴۵۶'), '123,456');
    expect(AmountInputFormatter.format('1٬250٬000'), '1,250,000');
  });

  test('caps the number of digits', () {
    final grouped = AmountInputFormatter.format('1' * 20);
    expect(grouped.replaceAll(',', '').length, 15);
  });

  test('formats while typing and keeps cursor at the end', () {
    expect(edit('', '2').text, '2');
    expect(edit('2', '25').text, '25');
    expect(edit('25', '250').text, '250');
    final value = edit('250', '2500');
    expect(value.text, '2,500');
    expect(value.selection.baseOffset, 5);
  });

  test('inserting a digit in the middle keeps relative cursor', () {
    // تایپ «۹» بعد از «۱» در «1,234»: مکان‌نما در متن جدید بعد از «۹» است
    final value = edit('1,234', '19,234', offset: 2);
    expect(value.text, '19,234');
    expect(value.selection.baseOffset, 2);
  });

  test('deleting a comma re-inserts it and keeps the cursor', () {
    // حذف کامای بعد از «۲» با Backspace
    final value = edit('2,500', '2500', offset: 1);
    expect(value.text, '2,500');
    expect(value.selection.baseOffset, 1);
  });

  test('empty text stays empty', () {
    final value = edit('', '');
    expect(value.text, '');
    expect(value.selection.baseOffset, 0);
  });
}
