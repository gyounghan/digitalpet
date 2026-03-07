import '../repositories/pet_repository.dart';
import '../repositories/notification_repository.dart';
import '../../core/constants/notification_constants.dart';
import '../../core/constants/app_strings.dart';

/// 알림 체크 유스케이스
/// Pet의 상태를 확인하여 알림 발송이 필요한지 판단하는 비즈니스 로직
/// 
/// 알림 조건:
/// - hunger < 30 + 식사 시간대 → "밥 먹을 시간이에요! 🍽️"
/// - hunger < 30 (식사 시간대 아님) → "나 너무 배고파..."
/// - happiness < 30 → "나 심심해..."
/// - 6시간 미접속 → "오늘 나 안 볼거야?"
/// 
/// 제한:
/// - 하루 최대 3회 알림 발송
class CheckNotificationUseCase {
  final PetRepository petRepository;
  final NotificationRepository notificationRepository;
  
  CheckNotificationUseCase({
    required this.petRepository,
    required this.notificationRepository,
  });
  
  /// 알림 체크 및 발송
  /// 
  /// [petId] 체크할 반려동물 ID
  /// 
  /// 반환: 발송된 알림 메시지 (발송하지 않았으면 null)
  /// 
  /// 동작:
  /// 1. 오늘 알림 발송 횟수 확인 (최대 3회 제한)
  /// 2. Pet 상태 확인
  /// 3. 알림 조건 확인 및 우선순위 결정
  /// 4. 조건 만족 시 알림 발송 및 기록
  Future<String?> call(String petId) async {
    // 1. 오늘 알림 발송 횟수 확인
    final todayCount = await notificationRepository.getTodayNotificationCount();
    if (todayCount >= NotificationConstants.maxNotificationsPerDay) {
      return null; // 하루 최대 알림 횟수 초과
    }
    
    // 2. Pet 조회
    final pet = await petRepository.getPet(petId);
    
    // 3. 마지막 접속 시간 확인
    final lastAccessTime = await notificationRepository.getLastAccessTime();
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    
    // 4. 알림 조건 확인 (우선순위 순서)
    String? notificationMessage;
    
    // 우선순위 1: 미접속 알림 (6시간 이상)
    if (lastAccessTime != null) {
      final elapsedHours = (currentTime - lastAccessTime) ~/ (1000 * 60 * 60);
      if (elapsedHours >= NotificationConstants.inactiveHoursThreshold) {
        notificationMessage = AppStrings.notificationInactive;
      }
    }
    
    // 우선순위 2: 배고픔 알림 (식사 시간대 확인)
    if (notificationMessage == null && pet.hunger < NotificationConstants.hungerThreshold) {
      // 현재 시간이 식사 시간대인지 확인
      final now = DateTime.now();
      final currentHour = now.hour;
      bool isMealTime = false;
      
      // 식사 시간대: 아침 7-9시, 점심 12-14시, 저녁 18-20시
      final mealTimeRanges = [
        {'start': 7, 'end': 9},
        {'start': 12, 'end': 14},
        {'start': 18, 'end': 20},
      ];
      
      for (final range in mealTimeRanges) {
        if (currentHour >= range['start']! && currentHour < range['end']!) {
          isMealTime = true;
          break;
        }
      }
      
      // 식사 시간대이면 Feed 알림, 아니면 일반 배고픔 알림
      notificationMessage = isMealTime 
          ? AppStrings.notificationFeedTime 
          : AppStrings.notificationHungry;
    }
    
    // 우선순위 3: 행복도 알림
    if (notificationMessage == null && pet.happiness < NotificationConstants.happinessThreshold) {
      notificationMessage = AppStrings.notificationBored;
    }
    
    // 5. 알림 발송 및 기록
    if (notificationMessage != null) {
      await notificationRepository.recordNotification();
    }
    
    return notificationMessage;
  }
  
  /// 마지막 접속 시간 업데이트
  /// 
  /// 앱 실행 시 호출하여 접속 시간을 업데이트
  Future<void> updateLastAccessTime() async {
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    await notificationRepository.updateLastAccessTime(currentTime);
  }
}
