class FaceIdPolicy {
  FaceIdPolicy._();

  static const int highValueThresholdVnd = 10000000;

  static bool isRequiredFor(int amount) => amount >= highValueThresholdVnd;
}
