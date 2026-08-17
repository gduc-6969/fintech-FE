import 'dart:math' as math;
import 'dart:typed_data';

/// Lightweight quality signals calculated from a downscaled RGBA camera frame.
///
/// These checks intentionally reject only clearly unusable captures. The
/// server remains responsible for face detection, liveness, and identity
/// matching.
class FaceImageQuality {
  static const double _minimumBrightness = 20;
  static const double _maximumBrightness = 245;
  static const double _minimumContrast = 4;
  static const double _minimumSharpness = 1;

  final double brightness;
  final double contrast;
  final double sharpness;

  const FaceImageQuality({
    required this.brightness,
    required this.contrast,
    required this.sharpness,
  });

  factory FaceImageQuality.fromRgba(
    Uint8List rgba, {
    required int width,
    required int height,
  }) {
    if (width < 2 || height < 2 || rgba.length < width * height * 4) {
      throw const FormatException('Invalid decoded camera frame.');
    }

    // The face guide occupies the center of the preview, so assess the center
    // 70% instead of letting a bright or detailed background dominate.
    final left = (width * 0.15).floor();
    final right = math.max(left + 2, (width * 0.85).ceil());
    final top = (height * 0.15).floor();
    final bottom = math.max(top + 2, (height * 0.85).ceil());

    var count = 0;
    var luminanceSum = 0.0;
    var luminanceSquaredSum = 0.0;
    var gradientSum = 0.0;
    var gradientCount = 0;

    int luminanceAt(int x, int y) {
      final offset = (y * width + x) * 4;
      return (77 * rgba[offset] +
              150 * rgba[offset + 1] +
              29 * rgba[offset + 2]) >>
          8;
    }

    for (var y = top; y < bottom; y++) {
      for (var x = left; x < right; x++) {
        final luminance = luminanceAt(x, y);
        count++;
        luminanceSum += luminance;
        luminanceSquaredSum += luminance * luminance;

        if (x + 1 < right) {
          gradientSum += (luminance - luminanceAt(x + 1, y)).abs();
          gradientCount++;
        }
        if (y + 1 < bottom) {
          gradientSum += (luminance - luminanceAt(x, y + 1)).abs();
          gradientCount++;
        }
      }
    }

    final brightness = luminanceSum / count;
    final variance = math.max(
      0,
      luminanceSquaredSum / count - brightness * brightness,
    );
    return FaceImageQuality(
      brightness: brightness,
      contrast: math.sqrt(variance),
      sharpness: gradientCount == 0 ? 0 : gradientSum / gradientCount,
    );
  }

  bool get isAcceptable => rejectionMessage == null;

  String? get rejectionMessage {
    if (brightness < _minimumBrightness) {
      return 'Khung hình quá tối. Hãy di chuyển đến nơi đủ sáng.';
    }
    if (brightness > _maximumBrightness) {
      return 'Khung hình bị lóa sáng. Hãy tránh ánh sáng chiếu thẳng vào camera.';
    }
    if (contrast < _minimumContrast || sharpness < _minimumSharpness) {
      return 'Khung hình chưa đủ rõ. Hãy giữ điện thoại và khuôn mặt ổn định.';
    }
    return null;
  }
}

class CapturedFaceFrame {
  final String payload;
  final FaceImageQuality quality;

  const CapturedFaceFrame({required this.payload, required this.quality});
}

/// Owns one atomic capture attempt and prevents failed attempts from leaking
/// partial frames into a retry.
class FaceCaptureBatch {
  final int expectedFrameCount;
  final List<CapturedFaceFrame> _frames = <CapturedFaceFrame>[];

  FaceCaptureBatch({required this.expectedFrameCount}) {
    if (expectedFrameCount <= 0) {
      throw ArgumentError.value(
        expectedFrameCount,
        'expectedFrameCount',
        'Expected frame count must be positive.',
      );
    }
  }

  int get length => _frames.length;
  bool get isEmpty => _frames.isEmpty;

  int checkpoint() => _frames.length;

  void add(CapturedFaceFrame frame) => _frames.add(frame);

  void rollbackTo(int checkpoint) {
    if (checkpoint < 0 || checkpoint > _frames.length) {
      throw RangeError.range(checkpoint, 0, _frames.length, 'checkpoint');
    }
    _frames.removeRange(checkpoint, _frames.length);
  }

  void clear() => _frames.clear();

  List<String> complete() {
    if (_frames.length != expectedFrameCount) {
      throw StateError(
        'Expected $expectedFrameCount captured frames, got ${_frames.length}.',
      );
    }

    final result = _frames.map((frame) => frame.payload).toList(growable: true);
    _frames.clear();
    return result;
  }
}
