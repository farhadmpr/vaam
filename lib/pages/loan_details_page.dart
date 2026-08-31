import 'package:flutter/material.dart';

import '../models/installment.dart';
import '../models/loan.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../utils/jalali_utils.dart';
import 'loan_form_page.dart';

/// جزئیات وام و لیست تمام اقساط آن
class LoanDetailsPage extends StatefulWidget {
  final int loanId;

  const LoanDetailsPage({super.key, required this.loanId});

  @override
  State<LoanDetailsPage> createState() => _LoanDetailsPageState();
}

class _LoanDetailsPageState extends State<LoanDetailsPage> {
  Loan? _loan;
  List<Installment> _installments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final loan = await DatabaseService.instance.getLoan(widget.loanId);
    var installments = <Installment>[];
    if (loan != null) {
      installments =
          await DatabaseService.instance.getInstallments(widget.loanId);
    }
    if (!mounted) return;
    setState(() {
      _loan = loan;
      _installments = installments;
      _loading = false;
    });
  }

  /// علامت‌گذاری قسط به‌عنوان پرداخت‌شده یا لغو آن
  Future<void> _togglePaid(Installment installment, bool paid) async {
    await DatabaseService.instance.setInstallmentPaid(installment.id!, paid);
    await NotificationService.instance.rescheduleAll();
    await _refresh();
  }

  Future<void> _edit() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => LoanFormPage(loan: _loan)),
    );
    if (saved == true) await _refresh();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف وام'),
        content: Text('وام «${_loan!.name}» و تمام اقساط آن حذف شود؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await DatabaseService.instance.deleteLoan(widget.loanId);
    await NotificationService.instance.rescheduleAll();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final loan = _loan;
    if (loan == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('وام یافت نشد')),
      );
    }
    final paidCount = _installments.where((item) => item.isPaid).length;
    return Scaffold(
      appBar: AppBar(
        title: Text(loan.name),
        actions: [
          IconButton(
            tooltip: 'ویرایش',
            icon: const Icon(Icons.edit_outlined),
            onPressed: _edit,
          ),
          IconButton(
            tooltip: 'حذف',
            icon: const Icon(Icons.delete_outline),
            onPressed: _delete,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _infoCard(loan, paidCount),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Text('اقساط', style: Theme.of(context).textTheme.titleMedium),
          ),
          for (final installment in _installments)
            _installmentTile(installment),
        ],
      ),
    );
  }

  Widget _infoCard(Loan loan, int paidCount) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.account_balance, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(loan.bank, style: theme.textTheme.titleMedium)),
              ],
            ),
            const Divider(height: 24),
            _infoRow('تاریخ شروع اقساط', JalaliUtils.formatJalali(loan.startJalali)),
            _infoRow(
              'تعداد اقساط',
              '${JalaliUtils.toPersianDigits('${loan.installmentCount}')} قسط',
            ),
            if (loan.amount != null)
              _infoRow(
                'مبلغ هر قسط',
                '${JalaliUtils.formatAmount(loan.amount!)} تومان',
              ),
            if (loan.description != null && loan.description!.isNotEmpty)
              _infoRow('توضیحات', loan.description!),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: loan.installmentCount == 0
                        ? 0
                        : paidCount / loan.installmentCount,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${JalaliUtils.toPersianDigits('$paidCount')} از '
                  '${JalaliUtils.toPersianDigits('${loan.installmentCount}')} پرداخت شده',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _installmentTile(Installment installment) {
    final theme = Theme.of(context);
    final days = JalaliUtils.daysFromToday(installment.dueDateTime);
    final paid = installment.isPaid;
    final color = paid
        ? Colors.green.shade700
        : days < 0
            ? theme.colorScheme.error
            : days == 0
                ? Colors.orange.shade800
                : theme.colorScheme.primary;

    final subtitle = StringBuffer(
      'سررسید: ${JalaliUtils.formatDateTime(installment.dueDateTime)}',
    );
    if (paid) {
      subtitle.write(' • پرداخت‌شده');
    } else {
      subtitle.write(' • ${JalaliUtils.remainingLabel(days)}');
    }

    return Card(
      child: CheckboxListTile(
        value: paid,
        onChanged: (value) => _togglePaid(installment, value ?? false),
        controlAffinity: ListTileControlAffinity.leading,
        title: Text(
          'قسط ${JalaliUtils.toPersianDigits('${installment.number}')}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            decoration: paid ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Text(
          subtitle.toString(),
          style: paid ? null : TextStyle(color: color),
        ),
        secondary: Icon(
          paid ? Icons.check_circle : Icons.radio_button_unchecked,
          color: color,
        ),
      ),
    );
  }

}
