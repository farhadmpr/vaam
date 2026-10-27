import 'package:flutter/material.dart';

import '../models/statistics.dart';
import '../services/statistics_service.dart';
import '../utils/jalali_utils.dart';

/// صفحه آمار و گزارش‌های وام‌ها بر اساس تقویم شمسی
class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  StatsRange _range = StatsRange.currentMonth;
  JalaliRange _selected = StatsRange.currentMonth.resolve();
  Statistics _stats = const Statistics.empty();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final now = DateTime.now();
    final selected = _range.resolve(now);
    final stats = await StatisticsService.instance.getStatistics(
      _range,
      now: now,
    );
    if (!mounted) return;
    setState(() {
      _stats = stats;
      _selected = selected;
      _loading = false;
    });
  }

  Future<void> _selectRange(StatsRange range) async {
    if (range == _range) return;
    setState(() {
      _range = range;
      _loading = true;
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('آمار و گزارش‌ها'),
        actions: [
          IconButton(
            tooltip: 'به‌روزرسانی',
            icon: const Icon(Icons.refresh),
            onPressed: _loading
                ? null
                : () {
                    setState(() => _loading = true);
                    _load();
                  },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                children: [
                  _buildRangeSelector(),
                  const SizedBox(height: 8),
                  _buildOverviewCard(),
                  const SizedBox(height: 8),
                  _buildRangeInstallmentsCard(),
                  const SizedBox(height: 8),
                  _buildPaymentsCard(),
                  const SizedBox(height: 8),
                  _buildGlobalCard(),
                  const SizedBox(height: 8),
                  _buildAmountsCard(),
                  const SizedBox(height: 8),
                  _buildBankCard(),
                  if (_stats.unknownAmountCount > 0) ...[
                    const SizedBox(height: 8),
                    _buildUnknownAmountNote(),
                  ],
                ],
              ),
            ),
    );
  }

  /// انتخاب بازه زمانی (ماه جاری، ماه قبل، ۳ ماه اخیر، سال جاری، همه)
  Widget _buildRangeSelector() {
    final theme = Theme.of(context);
    return _card(
      title: 'بازه زمانی',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final range in StatsRange.values)
                ChoiceChip(
                  label: Text(range.label),
                  selected: _range == range,
                  onSelected: (_) => _selectRange(range),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'بازه انتخابی: ${_selected.label}',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  /// خلاصه بازه: تعداد وام فعال، تعداد اقساط و درصد پرداخت
  Widget _buildOverviewCard() {
    final theme = Theme.of(context);
    return _card(
      child: Row(
        children: [
          _bigStat(
            _num(_stats.activeLoansCount),
            'وام فعال',
            theme.colorScheme.primary,
          ),
          const SizedBox(width: 20),
          _bigStat(
            _num(_stats.totalInstallments),
            'قسط در بازه',
            theme.colorScheme.secondary,
          ),
          const SizedBox(width: 20),
          _bigStat(
            '${_num(_stats.paidPercent)}٪',
            'پرداخت‌شده',
            theme.colorScheme.tertiary,
          ),
        ],
      ),
    );
  }

  /// اقساط بازه بر اساس سررسید: پرداخت‌شده و باقی‌مانده
  Widget _buildRangeInstallmentsCard() {
    final theme = Theme.of(context);
    return _card(
      title: 'اقساط بازه (بر اساس سررسید)',
      child: Column(
        children: [
          _statRow(
            'پرداخت‌شده',
            '${_num(_stats.paidCount)} قسط • ${_money(_stats.paidAmount)}',
            color: theme.colorScheme.primary,
          ),
          const Divider(height: 16),
          _statRow(
            'باقی‌مانده',
            '${_num(_stats.unpaidCount)} قسط • ${_money(_stats.unpaidAmount)}',
            color: theme.colorScheme.error,
          ),
        ],
      ),
    );
  }

  /// پرداخت‌های انجام‌شده در بازه (بر اساس تاریخ پرداخت)
  Widget _buildPaymentsCard() {
    final theme = Theme.of(context);
    return _card(
      title: 'پرداخت‌های ثبت‌شده در بازه',
      child: _stats.paidDuringRangeCount == 0
          ? Text(
              'در این بازه پرداختی ثبت نشده است',
              style: theme.textTheme.bodySmall,
            )
          : Column(
              children: [
                _statRow(
                  'تعداد پرداخت',
                  '${_num(_stats.paidDuringRangeCount)} قسط',
                  color: theme.colorScheme.primary,
                ),
                const Divider(height: 16),
                _statRow(
                  'مجموع مبلغ پرداخت‌شده',
                  _money(_stats.paidDuringRangeAmount),
                  color: theme.colorScheme.primary,
                ),
              ],
            ),
    );
  }

  /// وضعیت کلی (مستقل از بازه انتخابی)
  Widget _buildGlobalCard() {
    final theme = Theme.of(context);
    return _card(
      title: 'وضعیت کلی (بدون فیلتر بازه)',
      child: Column(
        children: [
          _statRow(
            'مجموع بدهی باقی‌مانده',
            '${_num(_stats.totalRemainingDebtCount)} قسط • '
                '${_money(_stats.totalRemainingDebtAmount)}',
          ),
          const Divider(height: 16),
          _statRow(
            'اقساط عقب‌افتاده',
            '${_num(_stats.overdueCount)} قسط • ${_money(_stats.overdueAmount)}',
            color: _stats.overdueCount > 0 ? theme.colorScheme.error : null,
          ),
          const Divider(height: 16),
          _statRow(
            'سررسید ${_num(StatisticsService.upcomingDays)} روز آینده',
            '${_num(_stats.upcomingCount)} قسط • '
                '${_money(_stats.upcomingAmount)}',
          ),
        ],
      ),
    );
  }

  /// بیشترین و کمترین مبلغ قسط در بازه
  Widget _buildAmountsCard() {
    final theme = Theme.of(context);
    final hasAmount = _stats.maxInstallmentAmount > 0;
    return _card(
      title: 'مبالغ قسط در بازه',
      child: !hasAmount
          ? Text(
              'مبلغی برای اقساط این بازه ثبت نشده است',
              style: theme.textTheme.bodySmall,
            )
          : Column(
              children: [
                _statRow(
                  'بیشترین قسط',
                  _money(_stats.maxInstallmentAmount),
                ),
                const Divider(height: 16),
                _statRow(
                  'کمترین قسط',
                  _money(_stats.minInstallmentAmount),
                ),
              ],
            ),
    );
  }

  /// تفکیک اقساط باقی‌مانده بر اساس بانک
  Widget _buildBankCard() {
    final theme = Theme.of(context);
    final banks = _stats.bankStats;
    return _card(
      title: 'تفکیک بانک‌ها در بازه',
      child: banks.isEmpty
          ? Text(
              'در این بازه وامی ثبت نشده است',
              style: theme.textTheme.bodySmall,
            )
          : Column(
              children: [
                for (var i = 0; i < banks.length; i++) ...[
                  if (i > 0) const Divider(height: 16),
                  _bankTile(banks[i]),
                ],
              ],
            ),
    );
  }

  Widget _bankTile(BankStat stat) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                stat.bank,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                '${_num(stat.loanCount)} وام • '
                '${_num(stat.remainingCount)} قسط باقی‌مانده',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _money(stat.remainingAmount),
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.error,
          ),
        ),
      ],
    );
  }

  /// یادآوری اقساطی که مبلغشان ثبت نشده است
  Widget _buildUnknownAmountNote() {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'مبلغ ${_num(_stats.unknownAmountCount)} قسط در این بازه '
                'ثبت نشده و در جمع مبالغ لحاظ نشده است.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// کارت با عنوان اختیاری
  Widget _card({String? title, required Widget child}) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(
                title,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
            ],
            child,
          ],
        ),
      ),
    );
  }

  Widget _bigStat(String value, String label, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style:
              TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _statRow(String label, String value, {Color? color}) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
        Text(
          value,
          style: theme.textTheme.bodyMedium
              ?.copyWith(fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  /// عدد با ارقام فارسی
  String _num(int value) => JalaliUtils.toPersianDigits('$value');

  /// مبلغ با جداکننده هزارگان و ارقام فارسی
  String _money(double value) => '${JalaliUtils.formatAmount(value)} تومان';
}
