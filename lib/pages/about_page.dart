import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// صفحه «درباره ما»: معرفی پروژه، سازنده و سورس باز
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  static const String _repoUrl = 'https://github.com/farhadmpr/vaam';
  static const String _author = 'فرهاد مرتضی‌پور';

  void _copyRepoUrl(BuildContext context) {
    Clipboard.setData(const ClipboardData(text: _repoUrl));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('آدرس گیت‌هاب کپی شد ✅')),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final urlStyle = theme.textTheme.bodySmall?.copyWith(
      color: colorScheme.primary,
      decoration: TextDecoration.underline,
      decorationColor: colorScheme.primary,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('درباره ما')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                // لوگو و نام برنامه
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.receipt_long,
                        size: 44,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'مدیریت اقساط وام',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Vaam',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'اپلیکیشنی ساده و کاربردی برای ثبت و مدیریت اقساط وام‌های '
                  'بانکی، با تقویم شمسی، یادآوری سررسیدها و گزارش‌های دقیق؛ '
                  'تا هیچ قسطی فراموش نشود.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                // ویژگی‌ها
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _featureRow(
                          theme,
                          Icons.calendar_month_outlined,
                          'تقویم شمسی',
                          'تاریخ‌ها کاملاً بر اساس تقویم هجری شمسی',
                        ),
                        const SizedBox(height: 12),
                        _featureRow(
                          theme,
                          Icons.notifications_active_outlined,
                          'یادآوری اقساط',
                          'نوتیفیکیشن سررسید برای هر وام به‌صورت جداگانه',
                        ),
                        const SizedBox(height: 12),
                        _featureRow(
                          theme,
                          Icons.insights_outlined,
                          'آمار و گزارش',
                          'خلاصه وضعیت بدهی، پرداخت‌ها و بانک‌ها',
                        ),
                        const SizedBox(height: 12),
                        _featureRow(
                          theme,
                          Icons.cloud_off_outlined,
                          'کاملاً آفلاین',
                          'اطلاعات شما فقط روی دستگاه خودتان ذخیره می‌شود',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // بخش سورس باز
                Card(
                  margin: EdgeInsets.zero,
                  color: colorScheme.secondaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.code,
                              size: 20,
                              color: colorScheme.onSecondaryContainer,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'سورس باز',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSecondaryContainer,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'این پروژه به‌صورت متن‌باز توسعه داده شده و کد کامل آن '
                          'با فریم‌ورک فلاتر در گیت‌هاب در دسترس است؛ اگر '
                          'پیشنهادی دارید یا می‌خواهید مشارکت کنید، خوش‌آمدید!',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSecondaryContainer,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                _repoUrl,
                                textAlign: TextAlign.center,
                                style: urlStyle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              tooltip: 'کپی آدرس',
                              icon: Icon(
                                Icons.copy,
                                size: 18,
                                color: colorScheme.onSecondaryContainer,
                              ),
                              onPressed: () => _copyRepoUrl(context),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // سازنده و فلاتر
                Text(
                  'ساخته‌شده با ❤️ و کمک هوش مصنوعی',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'توسعه‌دهنده: $_author',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.flutter_dash,
                      size: 18,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'ساخته‌شده با فلاتر (Flutter)',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _featureRow(
    ThemeData theme,
    IconData icon,
    String title,
    String subtitle,
  ) {
    final colorScheme = theme.colorScheme;
    return Row(
      children: [
        Icon(icon, color: colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
