import 'jalali_utils.dart';

/// ابزارهای نرمال‌سازی و جستجوی متنی فارسی
class SearchUtils {
  SearchUtils._();

  static final RegExp _whitespace = RegExp(r'\s+');

  /// نرمال‌سازی متن برای جستجو:
  /// تبدیل ارقام فارسی/عربی به انگلیسی، یکسان‌سازی «ي/ك» عربی با «ی/ک»
  /// فارسی، حذف نیم‌فاصله و تبدیل به حروف کوچک
  static String normalize(String input) {
    var text = JalaliUtils.toEnglishDigits(input).toLowerCase();
    text = text
        .replaceAll('ي', 'ی')
        .replaceAll('ك', 'ک')
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('ٱ', 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('\u200C', '');
    return text;
  }

  /// واژه‌های عبارت جستجو؛ جستجوی چندواژه‌ای با منطق «شامل همه واژه‌ها»
  static List<String> queryWords(String rawQuery) {
    return normalize(rawQuery)
        .split(_whitespace)
        .where((word) => word.isNotEmpty)
        .toList();
  }
}
