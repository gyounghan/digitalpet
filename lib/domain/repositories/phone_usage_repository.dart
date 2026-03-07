import '../entities/phone_usage.dart';

/// 폰 사용 상태 저장소 인터페이스
/// Domain 레이어에서 정의하며, Data 레이어에서 구현
abstract class PhoneUsageRepository {
  /// 현재 폰 사용 상태 조회
  /// 
  /// 반환: PhoneUsage 엔티티
  Future<PhoneUsage> getPhoneUsage();
  
  /// 폰 사용 상태 저장
  /// 
  /// [phoneUsage] 저장할 PhoneUsage 엔티티
  Future<void> savePhoneUsage(PhoneUsage phoneUsage);
  
  /// 앱이 포그라운드로 전환되었을 때 호출
  /// 
  /// 마지막 포그라운드 시간을 업데이트하고, 백그라운드 시간을 누적
  Future<void> onForeground();
  
  /// 앱이 백그라운드로 전환되었을 때 호출
  /// 
  /// 마지막 백그라운드 시간을 기록
  Future<void> onBackground();
}
