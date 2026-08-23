import '../../../core/models/transaction_flow_data.dart';

class FaceIdPolicy {
  FaceIdPolicy._();

  static const int highValueThresholdVnd = 10000000;
  static const int enrollmentFrameCount = 5;
  static const int transactionFrameCount = 2;
  static const Duration transactionFrameInterval = Duration(milliseconds: 150);

  static bool isRequiredFor(TransactionFlowData transaction) =>
      transaction.amount >= highValueThresholdVnd;
}
