import '../repositories/phone_usage_repository.dart';

/// 폰 미사용 감지 유스케이스
/// 앱이 백그라운드에 있는 시간을 추적하여 미사용 상태를 감지
/// 
/// 미사용 기준:
/// - 앱이 백그라운드에 있고
/// - 30분 이상 경과했을 때
class DetectPhoneIdleUseCase {
  final PhoneUsageRepository phoneUsageRepository;
  
  /// 미사용으로 간주할 최소 시간 (분)
  static const int idleThresholdMinutes = 30;
  
  DetectPhoneIdleUseCase(this.phoneUsageRepository);
  
  /// 폰 미사용 상태 감지
  /// 
  /// [isInBackground] 앱이 현재 백그라운드에 있는지 여부
  /// 
  /// 반환: 미사용 상태이면 true, 아니면 false
  Future<bool> call({required bool isInBackground}) async {
    final phoneUsage = await phoneUsageRepository.getPhoneUsage();
    return phoneUsage.isIdle(
      isInBackground: isInBackground,
      idleThresholdMinutes: idleThresholdMinutes,
    );
  }
  
  /// 현재 미사용 시간 조회 (분 단위)
  /// 
  /// [isInBackground] 앱이 현재 백그라운드에 있는지 여부
  /// 
  /// 반환: 미사용 시간 (분)
  Future<int> getIdleMinutes({required bool isInBackground}) async {
    final phoneUsage = await phoneUsageRepository.getPhoneUsage();
    return phoneUsage.getIdleMinutes(isInBackground: isInBackground);
  }
}
