import 'dart:typed_data';

import 'package:fintech_fe/features/face_id/data/silent_camera_frame.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image_lib;

void main() {
  test('encodes a padded BGRA preview frame as an oriented JPEG', () {
    const width = 4;
    const height = 2;
    const rowStride = 20;
    final bytes = Uint8List(rowStride * height);

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final offset = y * rowStride + x * 4;
        bytes[offset] = 20 + x * 20;
        bytes[offset + 1] = 70 + y * 30;
        bytes[offset + 2] = 160;
        bytes[offset + 3] = 255;
      }
    }

    final jpeg = SilentCameraFrame.bgra8888(
      width: width,
      height: height,
      rowStride: rowStride,
      rotationDegrees: 90,
      bytes: bytes,
    ).encodeJpeg(quality: 100);
    final decoded = image_lib.decodeJpg(jpeg);

    expect(jpeg.sublist(0, 3), [0xFF, 0xD8, 0xFF]);
    expect(decoded, isNotNull);
    expect(decoded!.width, height);
    expect(decoded.height, width);
  });

  test('encodes an NV21 preview frame as a JPEG', () {
    const width = 4;
    const height = 2;
    final bytes = Uint8List(width * height * 3 ~/ 2);
    bytes.fillRange(0, width * height, 128);
    for (var offset = width * height; offset < bytes.length; offset += 2) {
      bytes[offset] = 128;
      bytes[offset + 1] = 128;
    }

    final jpeg = SilentCameraFrame.nv21(
      width: width,
      height: height,
      rotationDegrees: 0,
      bytes: bytes,
    ).encodeJpeg(quality: 100);
    final decoded = image_lib.decodeJpg(jpeg);

    expect(jpeg.sublist(0, 3), [0xFF, 0xD8, 0xFF]);
    expect(decoded, isNotNull);
    expect(decoded!.width, width);
    expect(decoded.height, height);
  });
}
