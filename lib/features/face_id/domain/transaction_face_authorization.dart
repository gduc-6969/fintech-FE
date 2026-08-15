import '../../../core/models/transaction_flow_data.dart';
import 'face_id_token.dart';

class TransactionAuthorizationData {
  final TransactionFlowData transaction;
  final FaceIdToken? faceIdToken;

  const TransactionAuthorizationData({
    required this.transaction,
    this.faceIdToken,
  });
}
