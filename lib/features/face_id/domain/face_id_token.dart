class FaceIdToken {
  final String value;
  final DateTime expiresAt;

  const FaceIdToken({required this.value, required this.expiresAt});

  factory FaceIdToken.fromJson(
    Map<String, dynamic> json, {
    DateTime? issuedAt,
  }) {
    final value = json['faceIdToken']?.toString().trim();
    if (value == null || value.isEmpty || value.length > 4096) {
      throw const FormatException('Face ID response is missing its token.');
    }
    final ttlValue = json['expiresInSeconds'];
    if (ttlValue is! num) {
      throw const FormatException('Face ID response is missing its TTL.');
    }
    final ttl = ttlValue.toInt();
    if (ttl <= 0 || ttl > 600) {
      throw const FormatException('Face ID response contains an invalid TTL.');
    }
    // Allow for network/clock skew so the UI never presents a token right at
    // the server-side expiry boundary.
    final safeTtl = ttl > 10 ? ttl - 10 : ttl;
    return FaceIdToken(
      value: value,
      expiresAt: (issuedAt ?? DateTime.now()).add(Duration(seconds: safeTtl)),
    );
  }

  bool isExpired({DateTime? at}) => !(at ?? DateTime.now()).isBefore(expiresAt);

  Duration remaining({DateTime? at}) {
    final duration = expiresAt.difference(at ?? DateTime.now());
    return duration.isNegative ? Duration.zero : duration;
  }
}
