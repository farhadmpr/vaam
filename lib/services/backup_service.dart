import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../models/installment.dart';
import '../models/loan.dart';
import 'database_service.dart';

/// خلاصه نتیجه بازیابی پشتیبان
class RestoreSummary {
  final int loans;
  final int installments;

  const RestoreSummary({required this.loans, required this.installments});
}

/// تهیه و بازیابی فایل پشتیبان (JSON) با انتخاب محل توسط کاربر
class BackupService {
  BackupService._();

  static final BackupService instance = BackupService._();

  static const int _backupVersion = 1;

  /// ساخت محتوای JSON پشتیبان از اطلاعات فعلی
  Future<String> buildBackupJson() async {
    final loans = await DatabaseService.instance.getLoans();
    final installments = await DatabaseService.instance.getAllInstallments();
    final map = <String, Object?>{
      'app': 'vaam',
      'backupVersion': _backupVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'loans': [for (final loan in loans) loan.toMap()],
      'installments': [for (final installment in installments) installment.toMap()],
    };
    return const JsonEncoder.withIndent('  ').convert(map);
  }

  /// ذخیره فایل پشتیبان؛ محل ذخیره توسط کاربر انتخاب می‌شود.
  /// خروجی null یعنی کاربر انصراف داده است.
  Future<Uri?> saveBackupFile() async {
    final json = await buildBackupJson();
    final now = DateTime.now();
    final fileName = 'vaam-backup'
        '-${now.year.toString().padLeft(4, '0')}'
        '-${now.month.toString().padLeft(2, '0')}'
        '-${now.day.toString().padLeft(2, '0')}.json';

    return FilePicker.saveFile(
      dialogTitle: 'ذخیره فایل پشتیبان',
      fileName: fileName,
      bytes: Uint8List.fromList(utf8.encode(json)),
    );
  }

  /// انتخاب فایل پشتیبان توسط کاربر و بازیابی آن.
  /// خروجی null یعنی کاربر انصراف داده است.
  Future<RestoreSummary?> restoreFromPickedFile() async {
    final file = await FilePicker.pickFile(
      dialogTitle: 'انتخاب فایل پشتیبان',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    return restoreFromJson(utf8.decode(bytes, allowMalformed: false));
  }

  /// بازیابی از متن JSON با اعتبارسنجی ساختار
  Future<RestoreSummary> restoreFromJson(String raw) async {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw const FormatException('فایل انتخاب‌شده یک JSON معتبر نیست.');
    }

    if (decoded is! Map<String, dynamic> ||
        decoded['app'] != 'vaam' ||
        decoded['backupVersion'] != _backupVersion) {
      throw const FormatException('این فایل یک پشتیبان معتبر برنامه نیست.');
    }

    final loansJson = decoded['loans'];
    final installmentsJson = decoded['installments'];
    if (loansJson is! List || installmentsJson is! List) {
      throw const FormatException('این فایل یک پشتیبان معتبر برنامه نیست.');
    }

    final loans = <Loan>[
      for (final item in loansJson)
        if (item is Map<String, dynamic>) Loan.fromMap(item),
    ];
    final installments = <Installment>[
      for (final item in installmentsJson)
        if (item is Map<String, dynamic>) Installment.fromMap(item),
    ];

    await DatabaseService.instance
        .restoreAll(loans: loans, installments: installments);
    return RestoreSummary(
      loans: loans.length,
      installments: installments.length,
    );
  }
}
