enum TransactionType { deposit, withdraw, transfer }

enum TransactionOutcome { pending, successful, failed, unknown }

class TransactionFlowData {
  final TransactionType type;
  final String fromName;
  final String? fromSub;
  final String toName;
  final String? toSub;
  final int amount;
  final String? bankId;
  final String? recipientPhone;
  final String? idempotencyKey;
  final String? transactionId;
  final String? referenceCode;
  final String? createdAt;
  final TransactionOutcome outcome;

  const TransactionFlowData({
    required this.type,
    required this.fromName,
    required this.toName,
    required this.amount,
    this.fromSub,
    this.toSub,
    this.bankId,
    this.recipientPhone,
    this.idempotencyKey,
    this.transactionId,
    this.referenceCode,
    this.createdAt,
    this.outcome = TransactionOutcome.pending,
  });

  TransactionFlowData copyWith({
    String? idempotencyKey,
    String? transactionId,
    String? referenceCode,
    String? createdAt,
    TransactionOutcome? outcome,
  }) {
    return TransactionFlowData(
      type: type,
      fromName: fromName,
      fromSub: fromSub,
      toName: toName,
      toSub: toSub,
      amount: amount,
      bankId: bankId,
      recipientPhone: recipientPhone,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      transactionId: transactionId ?? this.transactionId,
      referenceCode: referenceCode ?? this.referenceCode,
      createdAt: createdAt ?? this.createdAt,
      outcome: outcome ?? this.outcome,
    );
  }

  static TransactionOutcome outcomeFromBackend(String? status) {
    switch (status?.toUpperCase()) {
      case 'SUCCESS':
      case 'SUCCESSFUL':
      case 'SUCCEEDED':
      case 'COMPLETED':
        return TransactionOutcome.successful;
      case 'FAILED':
      case 'FAILURE':
      case 'REJECTED':
      case 'CANCELLED':
        return TransactionOutcome.failed;
      case 'PENDING':
      case 'PROCESSING':
        return TransactionOutcome.pending;
      default:
        return TransactionOutcome.unknown;
    }
  }
}

class TransactionSubmissionResult {
  final String id;
  final String referenceCode;
  final String? createdAt;
  final TransactionOutcome outcome;

  const TransactionSubmissionResult({
    required this.id,
    required this.referenceCode,
    required this.outcome,
    this.createdAt,
  });

  factory TransactionSubmissionResult.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString();
    if (id == null || id.isEmpty) {
      throw const FormatException('Transaction response is missing its id.');
    }
    return TransactionSubmissionResult(
      id: id,
      referenceCode: json['referenceCode']?.toString() ?? id,
      createdAt: json['createdAt']?.toString(),
      outcome: TransactionFlowData.outcomeFromBackend(
        json['status']?.toString(),
      ),
    );
  }
}
