import 'package:flutter/material.dart';

import '../models/installment.dart';
import '../models/loan.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../services/settings_service.dart';
import '../utils/jalali_utils.dart';
import 'loan_details_page.dart';
import 'loan_form_page.dart';
import 'loans_page.dart';
import 'settings_page.dart';

/// صفحه اصلی: لیست اقساط پرداخت‌نشده از نزدیک‌ترین سررسید به دورترین
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<UnpaidInstallment> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final items = await DatabaseService.instance.getUnpaidInstallments();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _markPaid(UnpaidInstallment item) async {
    final installmentId = item.installment.id!;
    await DatabaseService.instance.setInstallmentPaid(installmentId, true);
    await NotificationService.instance.rescheduleAll();
    await _refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('قسط «${item.loan.name}» به‌عنوان پرداخت‌شده ثبت شد'),
          action: SnackBarAction(
            label: 'برگرداندن',
            onPressed: () async {
              await DatabaseService.instance
                  .setInstallmentPaid(installmentId, false);
              await NotificationService.instance.rescheduleAll();
              await _refresh();
            },
          ),
        ),
      );
  }

  Future<void> _openLoanForm([Loan? loan]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => LoanFormPage(loan: loan)),
    );
    if (saved == true) await _refresh();
  }

  Future<void> _openLoanDetails(int loanId) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => LoanDetailsPage(loanId: loanId)),
    );
    await _refresh();
  }

  Future<void> _openLoans() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const LoansPage()),
    );
    await _refresh();
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const SettingsPage()),
    );
    await NotificationService.instance.rescheduleAll();
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final overdueCount = _items
        .where((item) =>
            JalaliUtils.daysFromToday(item.installment.dueDateTime) < 0)
        .length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('اقساط وام'),
        actions: [
          IconButton(
            tooltip: 'وام‌ها',
            icon: const Icon(Icons.account_balance_outlined),
            onPressed: _openLoans,
          ),
          IconButton(
            tooltip: 'تنظیمات',
            icon: const Icon(Icons.settings_outlined),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child:
                  _items.isEmpty ? _buildEmpty() : _buildList(overdueCount),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openLoanForm(),
        icon: const Icon(Icons.add),
        label: const Text('وام جدید'),
      ),
    );
  }

  Widget _buildEmpty() {
    final theme = Theme.of(context);
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.22),
        Icon(
          Icons.event_available,
          size: 72,
          color: theme.colorScheme.primary.withValues(alpha: 0.4),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            'قسط پرداخت‌نشده‌ای وجود ندارد 🎉',
            style: theme.textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: 8),
        const Center(child: Text('برای ثبت وام جدید از دکمه پایین استفاده کنید')),
      ],
    );
  }

  /// اقساطی که با توجه به محدودیت تنظیم‌شده (تنظیمات) در صفحه اصلی
  /// نمایش داده می‌شوند — نزدیک‌ترین سررسیدها اول
  List<UnpaidInstallment> get _visibleItems =>
      _items.take(SettingsService.instance.homeLimit).toList();

  Widget _buildList(int overdueCount) {
    final visible = _visibleItems;
    final hiddenCount = _items.length - visible.length;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      itemCount: visible.length + 1 + (hiddenCount > 0 ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (index == 0) return _buildSummary(overdueCount);
        if (index == visible.length + 1) {
          return _buildHiddenNotice(hiddenCount);
        }
        return _buildTile(visible[index - 1]);
      },
    );
  }

  Widget _buildHiddenNotice(int hiddenCount) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Text(
        '${JalaliUtils.toPersianDigits('$hiddenCount')} قسط دیگر نمایش داده '
        'نمی‌شود؛ تعداد نمایش را می‌توانید از تنظیمات تغییر دهید.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }

  Widget _buildSummary(int overdueCount) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            _stat(
              JalaliUtils.toPersianDigits('${_items.length}'),
              'قسط باز',
              theme.colorScheme.primary,
            ),
            const SizedBox(width: 24),
            _stat(
              JalaliUtils.toPersianDigits('$overdueCount'),
              'عقب‌افتاده',
              theme.colorScheme.error,
            ),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('نزدیک‌ترین سررسید', style: theme.textTheme.bodySmall),
                Text(
                  JalaliUtils.formatDateTime(_items.first.installment.dueDateTime),
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String value, String label, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _buildTile(UnpaidInstallment item) {
    final days = JalaliUtils.daysFromToday(item.installment.dueDateTime);
    final color = days < 0
        ? Theme.of(context).colorScheme.error
        : days == 0
            ? Colors.orange.shade800
            : Theme.of(context).colorScheme.primary;
    return Card(
      child: ListTile(
        onTap: () => _openLoanDetails(item.loan.id!),
        leading: _badge(days, color),
        title: Text(item.loan.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.loan.bank),
            Text('سررسید: ${JalaliUtils.formatDateTime(item.installment.dueDateTime)}'),
            if (item.loan.amount != null)
              Text('مبلغ: ${JalaliUtils.formatAmount(item.loan.amount!)} تومان'),
          ],
        ),
        trailing: IconButton(
          tooltip: 'علامت‌گذاری به‌عنوان پرداخت شده',
          icon: Icon(Icons.check_circle_outline, color: color, size: 28),
          onPressed: () => _markPaid(item),
        ),
      ),
    );
  }

  Widget _badge(int days, Color color) {
    final String top;
    final String bottom;
    if (days < 0) {
      top = JalaliUtils.toPersianDigits('${-days}');
      bottom = 'روز عقب';
    } else if (days == 0) {
      top = '۰';
      bottom = 'امروز';
    } else {
      top = JalaliUtils.toPersianDigits('$days');
      bottom = 'روز مانده';
    }
    return Container(
      width: 56,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              top,
              style:
                  TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(bottom, style: TextStyle(color: color, fontSize: 10)),
          ],
        ),
      ),
    );
  }

}
