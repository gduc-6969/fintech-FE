import 'dart:typed_data';

import 'package:fintech_fe/core/models/transaction_flow_data.dart';
import 'package:fintech_fe/features/face_id/domain/face_capture_batch.dart';
import 'package:fintech_fe/features/face_id/domain/face_id_frame_payload.dart';
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

    test('does not require Face ID below ten million VND', () {
      for (final type in TransactionType.values) {
        expect(
          FaceIdPolicy.isRequiredFor(transaction(type, 9999999)),
          isFalse,
          reason: '${type.name} below the threshold must skip Face ID',
        );
      }
    });

    test('requires Face ID for every type at and above ten million VND', () {
      for (final type in TransactionType.values) {
        expect(
          FaceIdPolicy.isRequiredFor(transaction(type, 10000000)),
          isTrue,
          reason: '${type.name} at the threshold must require Face ID',
        );
        expect(
          FaceIdPolicy.isRequiredFor(transaction(type, 10000001)),
          isTrue,
          reason: '${type.name} above the threshold must require Face ID',
        );
      }
    });

    test('captures the frame sequence expected by passive liveness', () {
      expect(FaceIdPolicy.enrollmentFrameCount, 5);
      expect(FaceIdPolicy.transactionFrameCount, 5);
      expect(
        FaceIdPolicy.transactionFrameInterval,
        const Duration(milliseconds: 150),
      );
    });
  });

  group('FaceIdToken', () {
    final issuedAt = DateTime.utc(2026, 8, 15, 12);

    test('applies an expiry safety margin to the backend TTL', () {
      final token = FaceIdToken.fromJson({
        'faceIdToken': 'one-time-token',
        'expiresInSeconds': 300,
      }, issuedAt: issuedAt);

      expect(
        token.isExpired(at: issuedAt.add(const Duration(seconds: 289))),
        isFalse,
      );
      expect(
        token.isExpired(at: issuedAt.add(const Duration(seconds: 290))),
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

    test('rejects blank tokens and invalid TTL values', () {
      for (final response in <Map<String, dynamic>>[
        {'faceIdToken': '   ', 'expiresInSeconds': 300},
        {'faceIdToken': 'token'},
        {'faceIdToken': 'token', 'expiresInSeconds': 0},
        {'faceIdToken': 'token', 'expiresInSeconds': -1},
        {'faceIdToken': 'token', 'expiresInSeconds': 601},
      ]) {
        expect(
          () => FaceIdToken.fromJson(response, issuedAt: issuedAt),
          throwsFormatException,
        );
      }
    });
  });

  group('FaceIdFramePayload', () {
    test('accepts exactly five bounded JPEG data URLs', () {
      final frames = List<String>.generate(5, (_) => _validJpegPayload());

      expect(
        () => FaceIdFramePayload.validateBatch(
          frames,
          expectedFrameCount: FaceIdPolicy.transactionFrameCount,
        ),
        returnsNormally,
      );
    });

    test('rejects every frame count except five', () {
      for (final count in [0, 1, 2, 4, 6, 10]) {
        final frames = List<String>.generate(count, (_) => _validJpegPayload());
        expect(
          () => FaceIdFramePayload.validateBatch(
            frames,
            expectedFrameCount: FaceIdPolicy.transactionFrameCount,
          ),
          throwsArgumentError,
          reason: '$count frames must be rejected',
        );
      }
    });

    test('rejects non-JPEG and undersized payloads', () {
      final invalidFrames = List<String>.filled(
        5,
        'data:image/png;base64,AAAA',
      );
      expect(
        () => FaceIdFramePayload.validateBatch(
          invalidFrames,
          expectedFrameCount: FaceIdPolicy.transactionFrameCount,
        ),
        throwsFormatException,
      );

      expect(
        () => FaceIdFramePayload.encodeJpeg(<int>[0xFF, 0xD8, 0xFF, 0xD9]),
        throwsFormatException,
      );
    });
  });

  group('FaceCaptureBatch', () {
    const quality = FaceImageQuality(
      brightness: 128,
      contrast: 20,
      sharpness: 8,
    );

    CapturedFaceFrame frame(String id) =>
        CapturedFaceFrame(payload: id, quality: quality);

    test('rolls back a partial attempt before a clean retry', () {
      final batch = FaceCaptureBatch(expectedFrameCount: 5);
      final checkpoint = batch.checkpoint();
      batch.add(frame('stale-1'));
      batch.add(frame('stale-2'));
      batch.rollbackTo(checkpoint);

      for (var index = 0; index < 5; index++) {
        batch.add(frame('fresh-$index'));
      }

      expect(batch.complete(), [
        'fresh-0',
        'fresh-1',
        'fresh-2',
        'fresh-3',
        'fresh-4',
      ]);
      expect(batch.isEmpty, isTrue);
    });

    test('refuses to complete an incomplete capture', () {
      final batch = FaceCaptureBatch(expectedFrameCount: 5)..add(frame('one'));
      expect(batch.complete, throwsStateError);
    });
  });

  group('FaceImageQuality', () {
    test('rejects a uniformly dark frame', () {
      final rgba = _rgbaFrame(16, 16, (_, _) => 5);
      final quality = FaceImageQuality.fromRgba(rgba, width: 16, height: 16);

      expect(quality.isAcceptable, isFalse);
      expect(quality.rejectionMessage, contains('quá tối'));
    });

    test('accepts a clear, normally exposed frame', () {
      final rgba = _rgbaFrame(16, 16, (x, y) => (x + y).isEven ? 80 : 180);
      final quality = FaceImageQuality.fromRgba(rgba, width: 16, height: 16);

      expect(quality.isAcceptable, isTrue);
    });
  });
}

String _validJpegPayload() {
  final bytes = Uint8List(FaceIdFramePayload.minimumFrameBytes);
  bytes[0] = 0xFF;
  bytes[1] = 0xD8;
  bytes[2] = 0xFF;
  bytes[bytes.length - 2] = 0xFF;
  bytes[bytes.length - 1] = 0xD9;
  return FaceIdFramePayload.encodeJpeg(bytes);
}

Uint8List _rgbaFrame(
  int width,
  int height,
  int Function(int x, int y) luminance,
) {
  final rgba = Uint8List(width * height * 4);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final offset = (y * width + x) * 4;
      final value = luminance(x, y);
      rgba[offset] = value;
      rgba[offset + 1] = value;
      rgba[offset + 2] = value;
      rgba[offset + 3] = 255;
    }
  }
  return rgba;
}
