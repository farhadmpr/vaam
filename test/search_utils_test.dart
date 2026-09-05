import 'package:flutter_test/flutter_test.dart';
import 'package:vaam/models/loan.dart';
import 'package:vaam/utils/search_utils.dart';

void main() {
  group('SearchUtils.normalize', () {
    test('converts persian digits and lowercases', () {
      expect(SearchUtils.normalize('وام ۱۲۳ ABC'), 'وام 123 abc');
    });

    test('unifies arabic yeh/kaf with persian ones', () {
      expect(SearchUtils.normalize('مسكن'), 'مسکن');
      expect(SearchUtils.normalize('ي'), 'ی');
    });

    test('removes ZWNJ', () {
      expect(SearchUtils.normalize('پرداخت‌شده'), 'پرداختشده');
    });
  });

  group('SearchUtils.queryWords', () {
    test('splits on whitespace and drops empties', () {
      expect(SearchUtils.queryWords('  مسکن   ملت  '), ['مسکن', 'ملت']);
      expect(SearchUtils.queryWords('   '), isEmpty);
    });
  });

  group('Loan.matchesQuery', () {
    final loan = Loan(
      name: 'وام مسکن بانک ملت',
      bank: 'بانک ملت',
      startYear: 1404,
      startMonth: 8,
      startDay: 15,
      installmentCount: 12,
      description: 'تسهیل مسکن نوساز',
    );

    test('empty query matches everything', () {
      expect(loan.matchesQuery(''), isTrue);
      expect(loan.matchesQuery('   '), isTrue);
    });

    test('matches by name', () {
      expect(loan.matchesQuery('مسکن'), isTrue);
      expect(loan.matchesQuery('وام مسکن'), isTrue);
    });

    test('matches by bank', () {
      expect(loan.matchesQuery('بانک ملت'), isTrue);
      expect(loan.matchesQuery('ملت'), isTrue);
    });

    test('matches by description', () {
      expect(loan.matchesQuery('نوساز'), isTrue);
      expect(loan.matchesQuery('تسهیل'), isTrue);
    });

    test('does not match unrelated queries', () {
      expect(loan.matchesQuery('خودرو'), isFalse);
      expect(loan.matchesQuery('بانک سامان'), isFalse);
    });

    test('multi-word query requires all words (AND)', () {
      expect(loan.matchesQuery('مسکن ملت'), isTrue);
      expect(loan.matchesQuery('مسکن خودرو'), isFalse);
    });

    test('is tolerant to arabic yeh/kaf and ZWNJ', () {
      expect(loan.matchesQuery('مسكن'), isTrue); // كاف عربی
      expect(loan.matchesQuery('تسهيل'), isTrue); // ي عربی
    });

    test('is tolerant to persian digits', () {
      final numberedLoan = Loan(
        name: 'وام مسکن 1404',
        bank: 'بانک ملت',
        startYear: 1404,
        startMonth: 8,
        startDay: 15,
        installmentCount: 12,
      );
      expect(numberedLoan.matchesQuery('۱۴۰۴'), isTrue);
      expect(numberedLoan.matchesQuery('۱۴۰۵'), isFalse);
    });

    test('null description does not break matching', () {
      final loanNoDesc = Loan(
        name: 'وام ساده',
        bank: 'بانک',
        startYear: 1404,
        startMonth: 1,
        startDay: 1,
        installmentCount: 1,
      );
      expect(loanNoDesc.matchesQuery('ساده'), isTrue);
    });
  });
}
