import 'package:drishtipay/utils/upi_validation.dart';
import 'package:drishtipay/utils/upi_voice_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UpiValidation', () {
    test('normalizeIndianMobile strips country code and validates', () {
      expect(UpiValidation.normalizeIndianMobile('9876543210'), '9876543210');
      expect(UpiValidation.normalizeIndianMobile('919876543210'), '9876543210');
      expect(UpiValidation.normalizeIndianMobile('+91 98765 43210'), '9876543210');
      expect(UpiValidation.normalizeIndianMobile('5876543210'), isNull);
      expect(UpiValidation.normalizeIndianMobile('987654321'), isNull);
    });

    test('VPA shape', () {
      expect(UpiValidation.normalizeVpa('user@okaxis'), 'user@okaxis');
      expect(UpiValidation.normalizeVpa('User@Okaxis'), 'user@okaxis');
      expect(UpiValidation.isValidVpa('x@y'), isFalse);
    });
  });

  group('parsePayeeFromSpeech', () {
    test('digit run mobile', () {
      final r = parsePayeeFromSpeech('my number is 9876543210');
      expect(r.isValid, isTrue);
      expect(r.normalized, '9876543210');
      expect(r.kind, PayeeParseKind.mobile);
    });

    test('spoken digits', () {
      final r = parsePayeeFromSpeech(
        'nine eight seven six five four three two one zero',
      );
      expect(r.isValid, isTrue);
      expect(r.normalized, '9876543210');
    });

    test('vpa with at', () {
      final r = parsePayeeFromSpeech('rahulverma at okaxis');
      expect(r.isValid, isTrue);
      expect(r.normalized, 'rahulverma@okaxis');
      expect(r.kind, PayeeParseKind.vpa);
    });

    test('confirm only', () {
      expect(isConfirmUtterance('yes please'), isTrue);
      expect(isConfirmUtterance('9876543210'), isFalse);
    });
  });
}
