import 'dart:math';
import '../entities/pet.dart';
import '../repositories/pet_repository.dart';

/// 접속 보너스 및 일일 이벤트 유스케이스
/// 앱 접속 시 보너스 지급, 연속 접속 추적, 일일 이벤트 생성
///
/// 접속 보너스 (하루 3회, 4시간 간격):
/// - 1회차: happiness +5, EXP +3
/// - 2회차: happiness +3, EXP +3
/// - 3회차: happiness +2, EXP +3
///
/// 연속 접속 보상:
/// - 3일: EXP +10, 수치 각 +3
/// - 7일: EXP +25, 수치 각 +5
/// - 14일: EXP +50, 수치 각 +8
/// - 30일: EXP +100, 수치 각 +15
///
/// 일일 이벤트 (첫 접속 시 랜덤):
/// sunny(20%), cozy(20%), tasty(20%), happy_day(10%), adventure(15%), normal(15%)
class LoginBonusUseCase {
  final PetRepository petRepository;

  /// 접속 보너스 최소 간격 (4시간 = 240분)
  static const int loginIntervalMinutes = 240;

  /// 최대 일일 보너스 횟수
  static const int maxDailyLoginBonuses = 3;

  /// 접속 보너스 happiness 증가량 (횟수별)
  static const List<int> happinessPerLogin = [5, 3, 2];

  /// 접속 보너스 EXP
  static const int expPerLogin = 3;

  /// 일일 이벤트 목록과 확률 (누적)
  static const List<Map<String, dynamic>> _eventTable = [
    {'id': 'sunny', 'cumWeight': 20},
    {'id': 'cozy', 'cumWeight': 40},
    {'id': 'tasty', 'cumWeight': 60},
    {'id': 'happy_day', 'cumWeight': 70},
    {'id': 'adventure', 'cumWeight': 85},
    {'id': 'normal', 'cumWeight': 100},
  ];

  LoginBonusUseCase(this.petRepository);

  /// 접속 시 보너스 + 이벤트 처리
  ///
  /// 반환: (업데이트된 Pet, 이벤트 ID or null, 연속접속 보상 지급 여부)
  Future<LoginBonusResult> call(String petId) async {
    var pet = await petRepository.getPet(petId);
    if (pet.isDead) return LoginBonusResult(pet: pet);

    final now = DateTime.now();
    final currentTime = now.millisecondsSinceEpoch;
    final todayStr = pet.todayDateString;

    bool isNewDay = pet.lastLoginDate != todayStr;
    int newLoginCount = pet.todayLoginCount;
    int newConsecutiveDays = pet.consecutiveLoginDays;
    String newEvent = pet.todayEvent;
    String newEventDate = pet.lastEventDate;
    int happinessBonus = 0;
    int expBonus = 0;
    int statBonus = 0;
    int consecutiveExpBonus = 0;

    // 새로운 날인 경우
    if (isNewDay) {
      newLoginCount = 0;

      // 연속 접속 계산
      if (_isConsecutiveDay(pet.lastLoginDate, todayStr)) {
        newConsecutiveDays = pet.consecutiveLoginDays + 1;
      } else {
        newConsecutiveDays = 1;
      }

      // 연속 접속 보상
      final consecutiveReward = _getConsecutiveReward(newConsecutiveDays);
      consecutiveExpBonus = consecutiveReward['exp'] ?? 0;
      statBonus = consecutiveReward['stat'] ?? 0;

      // 일일 이벤트 생성
      newEvent = _generateDailyEvent();
      newEventDate = todayStr;
    }

    // 접속 보너스 (4시간 간격, 최대 3회)
    bool loginBonusApplied = false;
    if (newLoginCount < maxDailyLoginBonuses) {
      final elapsedSinceLastLogin = currentTime - pet.lastLoginTime;
      final elapsedMinutes = elapsedSinceLastLogin ~/ (1000 * 60);

      if (pet.lastLoginTime == 0 || isNewDay || elapsedMinutes >= loginIntervalMinutes) {
        final bonusIndex = newLoginCount.clamp(0, happinessPerLogin.length - 1);
        happinessBonus = happinessPerLogin[bonusIndex];
        expBonus = expPerLogin;
        newLoginCount++;
        loginBonusApplied = true;
      }
    }

    // 변경사항 없으면 스킵
    if (!loginBonusApplied && !isNewDay) {
      return LoginBonusResult(pet: pet);
    }

    final updatedPet = pet.copyWith(
      happiness: (pet.happiness + happinessBonus + statBonus).clamp(0, 100),
      hunger: (pet.hunger + statBonus).clamp(0, 100),
      stamina: (pet.stamina + statBonus).clamp(0, 100),
      exp: pet.exp + expBonus + consecutiveExpBonus,
      consecutiveLoginDays: newConsecutiveDays,
      lastLoginDate: todayStr,
      todayLoginCount: newLoginCount,
      lastLoginTime: currentTime,
      todayEvent: newEvent,
      lastEventDate: newEventDate,
      // 새로운 날이면 배틀 카운트도 리셋
      todayBattleCount: isNewDay ? 0 : pet.todayBattleCount,
      lastUpdated: currentTime,
    );

    await petRepository.updatePet(updatedPet);

    return LoginBonusResult(
      pet: updatedPet,
      eventId: isNewDay ? newEvent : null,
      loginBonusApplied: loginBonusApplied,
      consecutiveRewardApplied: isNewDay && statBonus > 0,
      consecutiveDays: newConsecutiveDays,
    );
  }

  /// 어제 날짜인지 확인
  bool _isConsecutiveDay(String lastDate, String today) {
    if (lastDate.isEmpty) return false;
    try {
      final last = DateTime.parse(lastDate);
      final now = DateTime.parse(today);
      return now.difference(last).inDays == 1;
    } catch (e) {
      return false;
    }
  }

  /// 연속 접속 보상
  Map<String, int> _getConsecutiveReward(int days) {
    if (days >= 30) return {'exp': 100, 'stat': 15};
    if (days >= 14) return {'exp': 50, 'stat': 8};
    if (days >= 7) return {'exp': 25, 'stat': 5};
    if (days >= 3) return {'exp': 10, 'stat': 3};
    return {'exp': 0, 'stat': 0};
  }

  /// 일일 이벤트 랜덤 생성
  String _generateDailyEvent() {
    final roll = Random().nextInt(100);
    for (final event in _eventTable) {
      if (roll < (event['cumWeight'] as int)) {
        return event['id'] as String;
      }
    }
    return 'normal';
  }
}

/// 접속 보너스 결과
class LoginBonusResult {
  final Pet pet;
  final String? eventId;
  final bool loginBonusApplied;
  final bool consecutiveRewardApplied;
  final int consecutiveDays;

  LoginBonusResult({
    required this.pet,
    this.eventId,
    this.loginBonusApplied = false,
    this.consecutiveRewardApplied = false,
    this.consecutiveDays = 0,
  });
}
