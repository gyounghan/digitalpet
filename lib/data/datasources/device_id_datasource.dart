import 'package:hive_flutter/hive_flutter.dart';

/// 디바이스 고유 ID 관리
///
/// UUID v4를 Hive에 저장하여 서버 동기화 시 디바이스 식별에 사용.
/// 앱 재설치 시 새 ID가 생성되므로 이전 코드를 통한 복원이 필요.
class DeviceIdDatasource {
  static const String _boxName = 'device_config';
  static const String _deviceIdKey = 'device_id';

  Box? _box;

  /// 초기화 (Hive Box 열기)
  Future<void> init() async {
    _box ??= await Hive.openBox(_boxName);
  }

  /// 디바이스 ID 조회 (없으면 생성)
  Future<String> getOrCreateDeviceId() async {
    await init();
    final existing = _box!.get(_deviceIdKey) as String?;
    if (existing != null && existing.isNotEmpty) return existing;

    final newId = _generateUuid();
    await _box!.put(_deviceIdKey, newId);
    return newId;
  }

  /// 디바이스 이전 시 새 ID로 교체
  Future<void> setDeviceId(String newDeviceId) async {
    await init();
    await _box!.put(_deviceIdKey, newDeviceId);
  }

  /// 간단한 UUID v4 생성 (외부 패키지 불필요)
  String _generateUuid() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final random = now.hashCode;
    return '${_hex(random, 8)}-${_hex(now, 4)}-4${_hex(now >> 16, 3)}'
        '-${_hex(random >> 8, 4)}-${_hex(now + random, 12)}';
  }

  String _hex(int value, int length) {
    return (value.abs() % (1 << (length * 4)))
        .toRadixString(16)
        .padLeft(length, '0');
  }
}
