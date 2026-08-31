import 'package:flutter/material.dart';

import '../models/loan.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../utils/jalali_utils.dart';
import 'loan_details_page.dart';
import 'loan_form_page.dart';

/// لیست همه وام‌های ثبت‌شده
class LoansPage extends StatefulWidget {
  const LoansPage({super.key});

  @override
  State<LoansPage> createState() => _LoansPageState();
}

class _LoansPageState extends State<LoansPage> {
  List<Loan> _loans = [];
  Map<int, LoanProgress> _progress = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final loans = await DatabaseService.instance.getLoans();
    final progress = await DatabaseService.instance.getLoanProgress();
    if (!mounted) return;
    setState(() {
      _loans = loans;
      _progress = progress;
      _loading = false;
    });
  }

  Future<void> _openForm([Loan? loan]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => LoanFormPage(loan: loan)),
    );
    if (saved == true) await _refresh();
  }

  Future<void> _openDetails(int loanId) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => LoanDetailsPage(loanId: loanId)),
    );
    await _refresh();
  }

  Future<void> _deleteLoan(Loan loan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف وام'),
        content: Text('وام «${loan.name}» و تمام اقساط آن حذف شود؟'),
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
    await DatabaseService.instance.deleteLoan(loan.id!);
    await NotificationService.instance.rescheduleAll();
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('وام‌ها')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('وام جدید'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loans.isEmpty
              ? ListView(
                  children: [
                    SizedBox(
                        height: MediaQuery.of(context).size.height * 0.25),
                    const Center(child: Text('هنوز وامی ثبت نشده است')),
                  ],
                )
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                    itemCount: _loans.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) =>
                        _tile(_loans[index]),
                  ),
                ),
    );
  }

  Widget _tile(Loan loan) {
    final progress =
        _progress[loan.id] ?? const LoanProgress(total: 0, paid: 0);
    return Card(
      child: ListTile(
        onTap: () => _openDetails(loan.id!),
        leading: CircleAvatar(
          backgroundColor:
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
          child: Icon(Icons.account_balance,
              color: Theme.of(context).colorScheme.primary),
        ),
        title: Text(loan.name,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(loan.bank),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value:
                        progress.total == 0 ? 0 : progress.paid / progress.total,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${JalaliUtils.toPersianDigits('${progress.paid}')}/${JalaliUtils.toPersianDigits('${progress.total}')}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              _openForm(loan);
            } else if (value == 'delete') {
              _deleteLoan(loan);
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: 'edit',
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.edit_outlined),
                title: Text('ویرایش'),
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.delete_outline),
                title: Text('حذف'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
