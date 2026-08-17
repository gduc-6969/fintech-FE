class FaceIdToken {
  final String value;
  final DateTime expiresAt;
  final bool isDirectDemo;

  const FaceIdToken({
    required this.value,
    required this.expiresAt,
    this.isDirectDemo = false,
  });

  factory FaceIdToken.fromJson(
    Map<String, dynamic> json, {
    DateTime? issuedAt,
  }) {
    final value = json['faceIdToken']?.toString();
    if (value == null || value.isEmpty) {
      throw const FormatException('Face ID response is missing its token.');
    }
    final ttl = (json['expiresInSeconds'] as num?)?.toInt() ?? 300;
    return FaceIdToken(
      value: value,
      expiresAt: (issuedAt ?? DateTime.now()).add(Duration(seconds: ttl)),
      isDirectDemo: json['directDemo'] == true,
    );
  }

  bool isExpired({DateTime? at}) => !(at ?? DateTime.now()).isBefore(expiresAt);

  Duration remaining({DateTime? at}) {
    final duration = expiresAt.difference(at ?? DateTime.now());
    return duration.isNegative ? Duration.zero : duration;
  }
}
