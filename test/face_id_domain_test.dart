import 'package:fintech_fe/core/models/transaction_flow_data.dart';
import 'package:fintech_fe/features/face_id/domain/face_id_policy.dart';
import 'package:fintech_fe/features/face_id/domain/face_id_token.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FaceIdPolicy', () {
    TransactionFlowData transaction(TransactionType type, int amount) {
      return TransactionFlowData(
        type: type,
        fromName: 'Sender',
        toName: 'Recipient',
        amount: amount,
      );
    }

    test('does not require Face ID for a transfer below ten million VND', () {
      expect(
        FaceIdPolicy.isRequiredFor(
          transaction(TransactionType.transfer, 9999999),
        ),
        isFalse,
      );
    });

    test('requires Face ID for transfers at and above ten million VND', () {
      expect(
        FaceIdPolicy.isRequiredFor(
          transaction(TransactionType.transfer, 10000000),
        ),
        isTrue,
      );
      expect(
        FaceIdPolicy.isRequiredFor(
          transaction(TransactionType.transfer, 10000001),
        ),
        isTrue,
      );
    });

    test('never requires Face ID for deposits or withdrawals', () {
      expect(
        FaceIdPolicy.isRequiredFor(
          transaction(TransactionType.deposit, 100000000),
        ),
        isFalse,
      );
      expect(
        FaceIdPolicy.isRequiredFor(
          transaction(TransactionType.withdraw, 100000000),
        ),
        isFalse,
      );
    });

    test('captures the frame sequence expected by passive liveness', () {
      expect(FaceIdPolicy.transactionFrameCount, 5);
      expect(
        FaceIdPolicy.transactionFrameInterval,
        const Duration(milliseconds: 150),
      );
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

    test('marks direct Python verification results as demo-only', () {
      final token = FaceIdToken.fromJson({
        'faceIdToken': 'TXN-12345678',
        'expiresInSeconds': 300,
        'directDemo': true,
      }, issuedAt: issuedAt);

      expect(token.isDirectDemo, isTrue);
    });
  });
}
