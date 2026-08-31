import 'package:flutter/material.dart';

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
