import 'package:flutter/material.dart';

import '../services/backup_service.dart';
import '../services/notification_service.dart';
import '../services/settings_service.dart';
import '../utils/jalali_utils.dart';

/// تنظیمات نوتیفیکیشن
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  SettingsService get _settings => SettingsService.instance;

  Future<void> _apply() async {
    await _settings.save();
    await NotificationService.instance.rescheduleAll();
    if (mounted) setState(() {});
  }

  Future<void> _toggleEnabled(bool value) async {
    _settings.notificationsEnabled = value;
    await _apply();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: _settings.notifyHour,
        minute: _settings.notifyMinute,
      ),
    );
    if (picked == null) return;
    _settings.notifyHour = picked.hour;
    _settings.notifyMinute = picked.minute;
    await _apply();
  }

  Future<void> _setType(NotificationType type) async {
    _settings.notificationType = type;
    await _apply();
  }

  Future<void> _sendTestNotification() async {
    await NotificationService.instance.showTestNotification();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('نوتیفیکیشن آزمایشی ارسال شد')),
    );
  }

  bool _busy = false;

  void _showSnack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? Theme.of(context).colorScheme.error : null,
        ),
      );
  }

  /// تهیه فایل پشتیبان و ذخیره در محل انتخابی کاربر
  Future<void> _createBackup() async {
    setState(() => _busy = true);
    try {
      final uri = await BackupService.instance.saveBackupFile();
      if (!mounted) return;
      if (uri == null) {
        _showSnack('انصراف از ذخیره فایل پشتیبان');
      } else {
        _showSnack('فایل پشتیبان با موفقیت ذخیره شد ✅');
      }
    } catch (_) {
      if (!mounted) return;
      _showSnack('خطا در تهیه فایل پشتیبان؛ دوباره تلاش کنید', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// انتخاب فایل پشتیبان و جایگزینی اطلاعات فعلی با آن
  Future<void> _restoreBackup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('بازیابی پشتیبان'),
        content: const Text(
          'تمام وام‌ها و اقساط فعلی حذف و با اطلاعات فایل پشتیبان '
          'جایگزین می‌شود. ادامه می‌دهید؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('بازیابی'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      final summary = await BackupService.instance.restoreFromPickedFile();
      if (!mounted) return;
      if (summary == null) {
        _showSnack('انصراف از بازیابی');
        return;
      }
      // نوتیفیکیشن‌ها بر اساس اطلاعات جدید زمان‌بندی می‌شوند
      await NotificationService.instance.rescheduleAll();
      if (!mounted) return;
      _showSnack(
        'بازیابی انجام شد: '
        '${JalaliUtils.toPersianDigits('${summary.loans}')} وام و '
        '${JalaliUtils.toPersianDigits('${summary.installments}')} قسط',
      );
    } on FormatException catch (e) {
      if (!mounted) return;
      _showSnack(e.message, error: true);
    } catch (_) {
      if (!mounted) return;
      _showSnack('خطا در بازیابی؛ فایل را بررسی کنید و دوباره تلاش کنید', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _settings.notificationsEnabled;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('تنظیمات')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.notifications_active_outlined),
            title: const Text('نمایش نوتیفیکیشن'),
            subtitle: const Text('یادآوری سررسید اقساط'),
            value: enabled,
            onChanged: _toggleEnabled,
          ),
          ListTile(
            enabled: enabled,
            leading: const Icon(Icons.schedule),
            title: const Text('ساعت نمایش نوتیفیکیشن'),
            subtitle: Text(
              JalaliUtils.formatTime(_settings.notifyHour, _settings.notifyMinute),
              style: theme.textTheme.titleMedium,
            ),
            trailing: const Icon(Icons.edit_outlined),
            onTap: enabled ? _pickTime : null,
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('نوع نوتیفیکیشن', style: theme.textTheme.titleSmall),
          ),
          for (final type in NotificationType.values)
            ListTile(
              enabled: enabled,
              leading: Icon(_typeIcon(type)),
              title: Text(type.label),
              trailing: Icon(
                _settings.notificationType == type
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: _settings.notificationType == type
                    ? theme.colorScheme.primary
                    : null,
              ),
              onTap: enabled ? () => _setType(type) : null,
            ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              onPressed: enabled ? _sendTestNotification : null,
              icon: const Icon(Icons.notifications_none),
              label: const Text('ارسال نوتیفیکیشن آزمایشی'),
            ),
          ),
          const Divider(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('پشتیبان‌گیری و بازیابی', style: theme.textTheme.titleSmall),
          ),
          ListTile(
            enabled: !_busy,
            leading: const Icon(Icons.backup_outlined),
            title: const Text('تهیه فایل پشتیبان'),
            subtitle: const Text('ذخیره همه وام‌ها و اقساط در یک فایل JSON'),
            onTap: _busy ? null : _createBackup,
          ),
          ListTile(
            enabled: !_busy,
            leading: const Icon(Icons.restore_outlined),
            title: const Text('بازیابی از فایل پشتیبان'),
            subtitle: const Text('اطلاعات فعلی با فایل پشتیبان جایگزین می‌شود'),
            onTap: _busy ? null : _restoreBackup,
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'نوتیفیکیشن هر قسط در روز سررسید و ساعت انتخاب‌شده بالا نمایش '
              'داده می‌شود. سررسیدهای گذشته نوتیفیکیشن ندارند و در صفحه اصلی '
              'با برچسب «عقب‌افتاده» نمایش داده می‌شوند.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  IconData _typeIcon(NotificationType type) {
    switch (type) {
      case NotificationType.systemDefault:
        return Icons.tune;
      case NotificationType.sound:
        return Icons.volume_up_outlined;
      case NotificationType.vibration:
        return Icons.vibration;
      case NotificationType.silent:
        return Icons.notifications_off_outlined;
    }
  }
}
