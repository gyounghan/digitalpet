import 'dart:async';
import 'dart:math' as math;
import 'package:sensors_plus/sensors_plus.dart';

/// 폰 흔들기 감지기
///
/// 가속도계 센서를 구독하여 임계값을 넘는 가속도가 발생하면
/// 흔들기 1회로 카운트한다.
///
/// 사용법:
/// ```dart
/// final detector = ShakeDetector(onShake: () => print('shake!'));
/// detector.start();
/// // ...
/// detector.stop();
/// ```
class ShakeDetector {
  /// 흔들기 임계값 (m/s^2)
  /// 중력가속도(약 9.8) 위로 의미있는 변화량을 요구
  static const double _shakeThreshold = 18.0;

  /// 같은 흔들기로 중복 카운트되는 것을 막기 위한 최소 간격 (ms)
  static const int _minIntervalMs = 350;

  /// 흔들기 발생 시 호출되는 콜백
  final void Function() onShake;

  StreamSubscription<UserAccelerometerEvent>? _subscription;
  int _lastShakeMs = 0;

  ShakeDetector({required this.onShake});

  /// 감지 시작
  void start() {
    if (_subscription != null) return;
    _subscription = userAccelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 50),
    ).listen(_onAccelerometerEvent);
  }

  /// 감지 중지
  void stop() {
    _subscription?.cancel();
    _subscription = null;
  }

  /// 가속도 이벤트 처리
  void _onAccelerometerEvent(UserAccelerometerEvent event) {
    final magnitude = math.sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );

    if (magnitude < _shakeThreshold) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastShakeMs < _minIntervalMs) return;

    _lastShakeMs = now;
    onShake();
  }
}
