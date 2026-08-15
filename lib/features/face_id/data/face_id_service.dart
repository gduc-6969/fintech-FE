import '../../../core/services/api_service.dart';
import '../domain/face_id_token.dart';

class FaceIdService {
  FaceIdService._();

  static Future<void> registerEnrollment(List<String> images) async {
    if (images.length != 5) {
      throw ArgumentError.value(
        images.length,
        'images',
        'Face ID enrollment requires exactly five images.',
      );
    }
    await ApiService.registerFaceIdEnrollment(images: images);
  }

  static Future<FaceIdToken> verifyForTransaction(List<String> images) async {
    if (images.length < 2 || images.length > 10) {
      throw ArgumentError.value(
        images.length,
        'images',
        'Face ID verification requires between two and ten frames.',
      );
    }
    final response = await ApiService.verifyFaceId(images: images);
    return FaceIdToken.fromJson(response);
  }
}
