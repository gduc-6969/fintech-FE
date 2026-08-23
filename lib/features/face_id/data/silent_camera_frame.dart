import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:image/image.dart' as image_lib;

enum SilentCameraPixelFormat { bgra8888, nv21 }

/// An isolate-safe copy of a camera preview frame.
///
/// Transaction verification uses preview frames instead of [CameraController]
/// still captures so iOS and Android do not play repeated shutter sounds.
class SilentCameraFrame {
  final int width;
  final int height;
  final int rowStride;
  final int rotationDegrees;
  final SilentCameraPixelFormat pixelFormat;
  final Uint8List bytes;

  const SilentCameraFrame._({
    required this.width,
    required this.height,
    required this.rowStride,
    required this.rotationDegrees,
    required this.pixelFormat,
    required this.bytes,
  });

  factory SilentCameraFrame.fromCameraImage(
    CameraImage frame, {
    required int rotationDegrees,
  }) {
    if (frame.planes.isEmpty) {
      throw const FormatException('Camera preview frame has no image plane.');
    }

    final plane = frame.planes.first;
    switch (frame.format.group) {
      case ImageFormatGroup.bgra8888:
        return SilentCameraFrame.bgra8888(
          width: frame.width,
          height: frame.height,
          rowStride: plane.bytesPerRow,
          rotationDegrees: rotationDegrees,
          bytes: Uint8List.fromList(plane.bytes),
        );
      case ImageFormatGroup.nv21:
        return SilentCameraFrame.nv21(
          width: frame.width,
          height: frame.height,
          rotationDegrees: rotationDegrees,
          bytes: Uint8List.fromList(plane.bytes),
        );
      default:
        throw FormatException(
          'Unsupported silent camera format: ${frame.format.group.name}.',
        );
    }
  }

  factory SilentCameraFrame.bgra8888({
    required int width,
    required int height,
    required int rowStride,
    required int rotationDegrees,
    required Uint8List bytes,
  }) {
    _validateDimensions(width, height);
    if (rowStride < width * 4 || bytes.length < rowStride * height) {
      throw const FormatException('Invalid BGRA camera preview buffer.');
    }
    return SilentCameraFrame._(
      width: width,
      height: height,
      rowStride: rowStride,
      rotationDegrees: _normalizeRotation(rotationDegrees),
      pixelFormat: SilentCameraPixelFormat.bgra8888,
      bytes: bytes,
    );
  }

  factory SilentCameraFrame.nv21({
    required int width,
    required int height,
    required int rotationDegrees,
    required Uint8List bytes,
  }) {
    _validateDimensions(width, height);
    final minimumLength = width * height * 3 ~/ 2;
    if (bytes.length < minimumLength) {
      throw const FormatException('Invalid NV21 camera preview buffer.');
    }
    return SilentCameraFrame._(
      width: width,
      height: height,
      rowStride: width,
      rotationDegrees: _normalizeRotation(rotationDegrees),
      pixelFormat: SilentCameraPixelFormat.nv21,
      bytes: bytes,
    );
  }

  Uint8List encodeJpeg({int quality = 88}) {
    if (quality < 1 || quality > 100) {
      throw RangeError.range(quality, 1, 100, 'quality');
    }

    final decoded = switch (pixelFormat) {
      SilentCameraPixelFormat.bgra8888 => _decodeBgra(),
      SilentCameraPixelFormat.nv21 => _decodeNv21(),
    };
    final oriented = rotationDegrees == 0
        ? decoded
        : image_lib.copyRotate(decoded, angle: rotationDegrees);
    return image_lib.encodeJpg(oriented, quality: quality);
  }

  image_lib.Image _decodeBgra() {
    return image_lib.Image.fromBytes(
      width: width,
      height: height,
      bytes: bytes.buffer,
      bytesOffset: bytes.offsetInBytes,
      rowStride: rowStride,
      numChannels: 4,
      order: image_lib.ChannelOrder.bgra,
    );
  }

  image_lib.Image _decodeNv21() {
    final decoded = image_lib.Image(
      width: width,
      height: height,
      numChannels: 3,
    );
    final luminanceLength = width * height;

    for (var y = 0; y < height; y++) {
      final chromaRow = luminanceLength + (y >> 1) * width;
      for (var x = 0; x < width; x++) {
        final luminance = (bytes[y * width + x] - 16).clamp(0, 255).toInt();
        final chromaOffset = chromaRow + (x & ~1);
        final v = bytes[chromaOffset] - 128;
        final u = bytes[chromaOffset + 1] - 128;

        final r = _clampToByte((298 * luminance + 409 * v + 128) >> 8);
        final g = _clampToByte(
          (298 * luminance - 100 * u - 208 * v + 128) >> 8,
        );
        final b = _clampToByte((298 * luminance + 516 * u + 128) >> 8);
        decoded.setPixelRgb(x, y, r, g, b);
      }
    }
    return decoded;
  }

  static void _validateDimensions(int width, int height) {
    if (width <= 0 || height <= 0 || width.isOdd || height.isOdd) {
      throw const FormatException('Invalid camera preview dimensions.');
    }
  }

  static int _normalizeRotation(int rotationDegrees) {
    final normalized = rotationDegrees % 360;
    if (normalized % 90 != 0) {
      throw const FormatException('Camera rotation must be a multiple of 90.');
    }
    return normalized < 0 ? normalized + 360 : normalized;
  }

  static int _clampToByte(int value) => value.clamp(0, 255).toInt();
}
