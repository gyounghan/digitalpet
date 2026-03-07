import 'package:hive/hive.dart';
import '../../domain/entities/phone_usage.dart';
import '../../core/constants/hive_constants.dart';

/// 폰 사용 상태 로컬 데이터소스
/// Hive를 사용한 로컬 저장소 접근
/// 
/// PhoneUsage 데이터의 실제 저장/조회를 담당
class PhoneUsageDataSource {
  Box<Map>? _box;
  
  /// Hive Box 초기화
  /// 
  /// 앱 시작 시 한 번 호출하여 Hive Box를 준비
  Future<void> init() async {
    if (_box == null || !_box!.isOpen) {
      _box = await Hive.openBox<Map>(HiveConstants.phoneUsageBoxName);
    }
  }
  
  /// Hive Box 초기화 확인 및 실행
  /// 
  /// Box가 초기화되지 않았으면 자동으로 초기화
  Future<void> _ensureInitialized() async {
    if (_box == null || !_box!.isOpen) {
      await init();
    }
  }
  
  /// 폰 사용 상태 조회
  /// 
  /// 반환: PhoneUsage 엔티티 (없으면 기본값 생성)
  Future<PhoneUsage> getPhoneUsage() async {
    await _ensureInitialized();
    
    final data = _box!.get('phone_usage');
    if (data == null) {
      // 기본값 생성 (현재 시간을 마지막 포그라운드 시간으로 설정)
      final currentTime = DateTime.now().millisecondsSinceEpoch;
      return PhoneUsage(
        lastForegroundTime: currentTime,
        lastBackgroundTime: null,
        totalIdleHours: 0,
      );
    }
    
    return PhoneUsage(
      lastForegroundTime: data['lastForegroundTime'] as int,
      lastBackgroundTime: data['lastBackgroundTime'] as int?,
      totalIdleHours: data['totalIdleHours'] as int? ?? 0,
    );
  }
  
  /// 폰 사용 상태 저장
  /// 
  /// [phoneUsage] 저장할 PhoneUsage 엔티티
  Future<void> savePhoneUsage(PhoneUsage phoneUsage) async {
    await _ensureInitialized();
    
    await _box!.put('phone_usage', {
      'lastForegroundTime': phoneUsage.lastForegroundTime,
      'lastBackgroundTime': phoneUsage.lastBackgroundTime,
      'totalIdleHours': phoneUsage.totalIdleHours,
    });
  }
}
