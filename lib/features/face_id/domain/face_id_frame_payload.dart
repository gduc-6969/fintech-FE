import 'dart:convert';

class FaceIdFramePayload {
  FaceIdFramePayload._();

  static const String jpegDataUrlPrefix = 'data:image/jpeg;base64,';
  static const int minimumFrameBytes = 8 * 1024;
  static const int maximumFrameBytes = 5 * 1024 * 1024;
  static const int maximumBatchBytes = 20 * 1024 * 1024;

  static String encodeJpeg(List<int> bytes) {
    validateJpegBytes(bytes);
    return '$jpegDataUrlPrefix${base64Encode(bytes)}';
  }

  static void validateJpegBytes(List<int> bytes) {
    if (bytes.length < minimumFrameBytes) {
      throw const FormatException('Captured JPEG is unexpectedly small.');
    }
    if (bytes.length > maximumFrameBytes) {
      throw const FormatException('Captured JPEG exceeds the size limit.');
    }
    if (bytes.length < 3 ||
        bytes[0] != 0xFF ||
        bytes[1] != 0xD8 ||
        bytes[2] != 0xFF) {
      throw const FormatException('Captured image is not a valid JPEG.');
    }
  }

  static void validateBatch(
    List<String> frames, {
    required int expectedFrameCount,
  }) {
    if (frames.length != expectedFrameCount) {
      throw ArgumentError.value(
        frames.length,
        'frames',
        'Face ID requires exactly $expectedFrameCount JPEG frames.',
      );
    }

    var totalBytes = 0;
    for (final frame in frames) {
      final frameBytes = estimatedDecodedBytes(frame);
      if (frameBytes < minimumFrameBytes) {
        throw const FormatException('A Face ID frame is unexpectedly small.');
      }
      if (frameBytes > maximumFrameBytes) {
        throw const FormatException('A Face ID frame exceeds the size limit.');
      }
      totalBytes += frameBytes;
      if (totalBytes > maximumBatchBytes) {
        throw const FormatException(
          'The Face ID capture exceeds the size limit.',
        );
      }
    }
  }

  static int estimatedDecodedBytes(String frame) {
    if (!frame.startsWith(jpegDataUrlPrefix)) {
      throw const FormatException('Face ID frame must be a JPEG data URL.');
    }
    final encoded = frame.substring(jpegDataUrlPrefix.length);
    if (encoded.isEmpty || encoded.length % 4 != 0) {
      throw const FormatException('Face ID frame contains invalid Base64.');
    }
    // FF D8 FF, the JPEG start-of-image marker, always encodes to /9j/.
    if (!encoded.startsWith('/9j/')) {
      throw const FormatException('Face ID frame is not a JPEG image.');
    }

    var padding = 0;
    if (encoded.endsWith('==')) {
      padding = 2;
    } else if (encoded.endsWith('=')) {
      padding = 1;
    }
    return encoded.length * 3 ~/ 4 - padding;
  }
}
