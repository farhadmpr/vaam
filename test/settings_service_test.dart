import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaam/services/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('homeLimit defaults to 10', () async {
    await SettingsService.instance.load();
    expect(
      SettingsService.instance.homeLimit,
      SettingsService.defaultHomeLimit,
    );
    expect(SettingsService.instance.homeLimit, 10);
  });

  test('homeLimit persists after save and reload', () async {
    await SettingsService.instance.load();
    SettingsService.instance.homeLimit = 25;
    await SettingsService.instance.save();

    // شبیه‌سازی اجرای دوباره برنامه
    await SettingsService.instance.load();
    expect(SettingsService.instance.homeLimit, 25);
  });

  test('homeLimit is clamped to the valid range', () async {
    await SettingsService.instance.load();

    SettingsService.instance.homeLimit = 5000;
    await SettingsService.instance.save();
    await SettingsService.instance.load();
    expect(SettingsService.instance.homeLimit, SettingsService.maxHomeLimit);

    SettingsService.instance.homeLimit = -3;
    await SettingsService.instance.save();
    await SettingsService.instance.load();
    expect(SettingsService.instance.homeLimit, SettingsService.minHomeLimit);
  });
}
