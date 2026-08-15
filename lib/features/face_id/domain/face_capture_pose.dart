enum FaceCaptureMode { enrollment, enrollmentRetake, transaction }

enum FaceCapturePose { turnLeft, turnRight, lookDown, lookUp, straight }

extension FaceCapturePoseCopy on FaceCapturePose {
  String get title {
    switch (this) {
      case FaceCapturePose.turnLeft:
        return 'Quay mặt sang trái';
      case FaceCapturePose.turnRight:
        return 'Quay mặt sang phải';
      case FaceCapturePose.lookDown:
        return 'Cúi mặt xuống';
      case FaceCapturePose.lookUp:
        return 'Ngẩng mặt lên';
      case FaceCapturePose.straight:
        return 'Nhìn thẳng';
    }
  }

  String get instruction {
    switch (this) {
      case FaceCapturePose.turnLeft:
        return 'Quay nhẹ 30–45°, vẫn giữ toàn bộ khuôn mặt trong khung.';
      case FaceCapturePose.turnRight:
        return 'Quay nhẹ 30–45° và giữ điện thoại cố định.';
      case FaceCapturePose.lookDown:
        return 'Cúi khoảng 20–30°, không cúi quá thấp.';
      case FaceCapturePose.lookUp:
        return 'Ngẩng khoảng 20–30° và giữ mắt trong khung.';
      case FaceCapturePose.straight:
        return 'Giữ đầu thẳng, nhìn trực tiếp vào camera.';
    }
  }
}

class FaceCaptureRequest {
  final FaceCaptureMode mode;
  final FaceCapturePose? retakePose;

  const FaceCaptureRequest._(this.mode, {this.retakePose});

  const FaceCaptureRequest.enrollment() : this._(FaceCaptureMode.enrollment);

  const FaceCaptureRequest.transaction() : this._(FaceCaptureMode.transaction);

  const FaceCaptureRequest.retake(FaceCapturePose pose)
    : this._(FaceCaptureMode.enrollmentRetake, retakePose: pose);
}
