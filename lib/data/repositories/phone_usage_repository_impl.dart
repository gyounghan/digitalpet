import '../../domain/entities/phone_usage.dart';
import '../../domain/repositories/phone_usage_repository.dart';
import '../datasources/phone_usage_datasource.dart';

/// PhoneUsageRepository 인터페이스 구현
/// Domain의 추상화된 인터페이스를 실제 구현
/// 
/// PhoneUsageDataSource를 사용하여 Hive에 데이터 저장/조회
class PhoneUsageRepositoryImpl implements PhoneUsageRepository {
  final PhoneUsageDataSource dataSource;
  
  PhoneUsageRepositoryImpl(this.dataSource);
  
  @override
  Future<PhoneUsage> getPhoneUsage() async {
    return await dataSource.getPhoneUsage();
  }
  
  @override
  Future<void> savePhoneUsage(PhoneUsage phoneUsage) async {
    await dataSource.savePhoneUsage(phoneUsage);
  }
  
  @override
  Future<void> onForeground() async {
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    final phoneUsage = await getPhoneUsage();
    
    // 백그라운드에 있었던 시간을 누적
    int totalIdleHours = phoneUsage.totalIdleHours;
    if (phoneUsage.lastBackgroundTime != null) {
      // 백그라운드에 있던 시간 계산 (시간 단위)
      final backgroundDuration = currentTime - phoneUsage.lastBackgroundTime!;
      final backgroundHours = backgroundDuration ~/ (1000 * 60 * 60);
      totalIdleHours += backgroundHours;
    }
    
    // 포그라운드로 전환: 마지막 포그라운드 시간 업데이트, 백그라운드 시간 초기화
    final updatedPhoneUsage = phoneUsage.copyWith(
      lastForegroundTime: currentTime,
      lastBackgroundTime: null,
      totalIdleHours: totalIdleHours,
    );
    
    await savePhoneUsage(updatedPhoneUsage);
  }
  
  @override
  Future<void> onBackground() async {
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    final phoneUsage = await getPhoneUsage();
    
    // 백그라운드로 전환: 마지막 백그라운드 시간 기록
    final updatedPhoneUsage = phoneUsage.copyWith(
      lastBackgroundTime: currentTime,
    );
    
    await savePhoneUsage(updatedPhoneUsage);
  }
}
