import 'package:dio/dio.dart';

import '../../../core/services/api_service.dart';
import '../../../core/models/transaction_flow_data.dart';
import '../domain/face_id_frame_payload.dart';
import '../domain/face_id_policy.dart';
import '../domain/face_id_token.dart';

class FaceIdService {
  FaceIdService._();

  static Future<void> registerEnrollment(
    List<String> images, {
    CancelToken? cancelToken,
  }) async {
    FaceIdFramePayload.validateBatch(
      images,
      expectedFrameCount: FaceIdPolicy.enrollmentFrameCount,
    );
    await ApiService.registerFaceIdEnrollment(
      images: images,
      cancelToken: cancelToken,
    );
  }

  static Future<FaceIdToken> verifyForTransaction(
    List<String> images, {
    required TransactionFlowData transaction,
    CancelToken? cancelToken,
  }) async {
    FaceIdFramePayload.validateBatch(
      images,
      expectedFrameCount: FaceIdPolicy.transactionFrameCount,
    );
    if (!FaceIdPolicy.isRequiredFor(transaction)) {
      throw ArgumentError.value(
        transaction.amount,
        'transaction',
        'Face ID verification is only valid for high-value transactions.',
      );
    }
    final response = await ApiService.verifyFaceId(
      images: images,
      transaction: transaction,
      cancelToken: cancelToken,
    );
    return FaceIdToken.fromJson(response);
  }
}
