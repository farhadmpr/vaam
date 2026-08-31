import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';

import '../models/loan.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../utils/amount_input_formatter.dart';
import '../utils/jalali_utils.dart';

/// فرم ثبت وام جدید یا ویرایش وام موجود
class LoanFormPage extends StatefulWidget {
  final Loan? loan;

  const LoanFormPage({super.key, this.loan});

  @override
  State<LoanFormPage> createState() => _LoanFormPageState();
}

class _LoanFormPageState extends State<LoanFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bankController = TextEditingController();
  final _amountController = TextEditingController();
  final _countController = TextEditingController();
  final _descriptionController = TextEditingController();

  late Jalali _startDate;
  bool _saving = false;

  bool get _isEditing => widget.loan != null;

  @override
  void initState() {
    super.initState();
    final loan = widget.loan;
    if (loan != null) {
      _nameController.text = loan.name;
      _bankController.text = loan.bank;
      if (loan.amount != null) {
        _amountController.text = AmountInputFormatter.format(
          loan.amount!.round().toString(),
        );
      }
      _countController.text = loan.installmentCount.toString();
      _descriptionController.text = loan.description ?? '';
      _startDate = loan.startJalali;
    } else {
      _startDate = Jalali.now();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bankController.dispose();
    _amountController.dispose();
    _countController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final picked = await showPersianDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: Jalali(1390, 1, 1),
      lastDate: Jalali(1450, 1, 1),
      // نام ماه و سال باید شمسی باشد (مثل «شهریور ۱۴۰۵»). به‌صورت پیش‌فرض
      // MaterialLocalizations ماه میلادی برمی‌گرداند (مثل «اوت 2026»)؛
      // با این override، داخل دیالوگ از نسخه شمسیِ خود پکیج استفاده می‌شود.
      builder: (context, child) => Localizations(
        locale: const Locale('fa'),
        delegates: const [
          PersianMaterialLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _startDate = picked);
    }
  }

  /// پارس مبلغ با پشتیبانی از ارقام فارسی و جداکننده هزارگان
  double? _parseAmount(String raw) {
    final cleaned = JalaliUtils.toEnglishDigits(raw).replaceAll(
      RegExp(r'[,\u060C\u066C\s]'),
      '',
    );
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final name = _nameController.text.trim();

    // بررسی یکتا بودن نام وام
    final duplicate = await DatabaseService.instance.getLoanByName(name);
    if (duplicate != null && duplicate.id != widget.loan?.id) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('این نام قبلاً ثبت شده است؛ نام دیگری انتخاب کنید'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final count =
        int.parse(JalaliUtils.toEnglishDigits(_countController.text.trim()));
    final amount = _parseAmount(_amountController.text);
    final description = _descriptionController.text.trim();

    final loan = Loan(
      id: widget.loan?.id,
      name: name,
      bank: _bankController.text.trim(),
      startYear: _startDate.year,
      startMonth: _startDate.month,
      startDay: _startDate.day,
      installmentCount: count,
      amount: amount,
      description: description.isEmpty ? null : description,
      createdAt: widget.loan?.createdAt,
    );

    try {
      if (_isEditing) {
        await DatabaseService.instance.updateLoan(loan);
      } else {
        await DatabaseService.instance.createLoan(loan);
      }
      await NotificationService.instance.rescheduleAll();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('خطا در ذخیره‌سازی؛ لطفاً دوباره تلاش کنید'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'ویرایش وام' : 'ثبت وام جدید'),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed: _saving ? null : _save,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('ذخیره', style: TextStyle(fontSize: 16)),
            ),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'نام وام *',
                hintText: 'مثلاً: وام مسکن',
              ),
              textInputAction: TextInputAction.next,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'نام وام الزامی است';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _bankController,
              decoration: const InputDecoration(
                labelText: 'نام بانک *',
                hintText: 'مثلاً: بانک ملت',
              ),
              textInputAction: TextInputAction.next,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'نام بانک الزامی است';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            // تاریخ شروع اقساط (شمسی)
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: _pickStartDate,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'تاریخ شروع اقساط (شمسی) *',
                  suffixIcon: const Icon(Icons.calendar_month_outlined),
                  errorStyle: const TextStyle(color: Colors.red),
                ),
                child: Text(JalaliUtils.formatJalali(_startDate)),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _countController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'تعداد اقساط *',
                hintText: 'مثلاً: 12',
              ),
              textInputAction: TextInputAction.next,
              validator: (value) {
                final count =
                    int.tryParse(JalaliUtils.toEnglishDigits(value ?? ''));
                if (count == null || count < 1 || count > 360) {
                  return 'تعداد اقساط باید عددی بین ۱ تا ۳۶۰ باشد';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              // نمایش اعداد با جداکننده هزارگان (کاما) هنگام تایپ
              inputFormatters: [AmountInputFormatter()],
              decoration: const InputDecoration(
                labelText: 'مبلغ هر قسط (تومان)',
                hintText: 'اختیاری - مثلاً: 2,500,000',
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'توضیحات',
                hintText: 'اختیاری',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'اقساط به‌صورت ماهانه از تاریخ شروع محاسبه می‌شوند؛ '
              'در روز سررسید هر قسط، نوتیفیکیشن یادآوری ارسال می‌شود.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

}
