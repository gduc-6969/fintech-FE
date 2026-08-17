import 'package:fintech_fe/features/face_id/domain/face_id_policy.dart';
import 'package:fintech_fe/features/face_id/domain/face_id_token.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FaceIdPolicy', () {
    test('does not require Face ID below ten million VND', () {
      expect(FaceIdPolicy.isRequiredFor(9999999), isFalse);
    });

    test('requires Face ID at and above ten million VND', () {
      expect(FaceIdPolicy.isRequiredFor(10000000), isTrue);
      expect(FaceIdPolicy.isRequiredFor(10000001), isTrue);
    });
  });

  group('FaceIdToken', () {
    final issuedAt = DateTime.utc(2026, 8, 15, 12);

    test('uses the backend TTL and expires at the boundary', () {
      final token = FaceIdToken.fromJson({
        'faceIdToken': 'one-time-token',
        'expiresInSeconds': 300,
      }, issuedAt: issuedAt);

      expect(
        token.isExpired(at: issuedAt.add(const Duration(seconds: 299))),
        isFalse,
      );
      expect(
        token.isExpired(at: issuedAt.add(const Duration(seconds: 300))),
        isTrue,
      );
    });

    test('rejects a response without a token', () {
      expect(
        () =>
            FaceIdToken.fromJson({'expiresInSeconds': 300}, issuedAt: issuedAt),
        throwsFormatException,
      );
    });
  });
}
