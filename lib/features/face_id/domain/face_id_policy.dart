import '../../../core/models/transaction_flow_data.dart';

class FaceIdPolicy {
  FaceIdPolicy._();

  static const int highValueThresholdVnd = 10000000;
  static const int transactionFrameCount = 5;
  static const Duration transactionFrameInterval = Duration(milliseconds: 150);

  static bool isRequiredFor(TransactionFlowData transaction) =>
      transaction.type == TransactionType.transfer &&
      transaction.amount >= highValueThresholdVnd;
}
