import '../entities/daily_goals.dart';
import '../repositories/pet_repository.dart';
import '../repositories/activity_repository.dart';

/// 일일 목표 점수 계산 유스케이스
/// 포만감, 수면, 운동 각각의 목표 달성 여부를 확인하고 점수를 계산
/// 
/// 목표:
/// - 포만감: 하루 3회 식사 (아침/점심/저녁 시간대에 먹이 주기)
/// - 수면: 하루 6시간 이상 수면
/// - 운동: 하루 10,000보 또는 30분 운동
/// 
/// 점수:
/// - 각 목표 달성 시 1점씩 부여 (최대 3점)
/// - 점수에 따라 경험치 획득 (점수당 20 경험치)
class CalculateDailyGoalsScoreUseCase {
  final PetRepository petRepository;
  final ActivityRepository activityRepository;
  
  /// 포만감 목표: 하루 3회 식사
  static const int feedGoalCount = 3;
  
  /// 수면 목표: 하루 6시간 이상
  static const int sleepGoalHours = 6;
  
  /// 운동 목표: 10,000보 또는 30분 운동
  static const int exerciseGoalSteps = 10000;
  static const int exerciseGoalMinutes = 30;
  
  /// 점수당 경험치
  static const int expPerScore = 20;
  
  CalculateDailyGoalsScoreUseCase({
    required this.petRepository,
    required this.activityRepository,
  });
  
  /// 일일 목표 점수 계산
  /// 
  /// [petId] 확인할 반려동물 ID
  /// 
  /// 반환: 일일 목표 달성 점수와 경험치
  Future<DailyGoalsScore> call(String petId) async {
    // 1. 현재 Pet 조회
    var pet = await petRepository.getPet(petId);
    
    // 2. 일일 목표 리셋 확인
    if (pet.needsGoalReset) {
      pet = pet.resetDailyGoals();
      await petRepository.updatePet(pet);
    }
    
    // 3. 오늘 날짜
    final todayDate = pet.todayDateString;
    
    // 4. 포만감 목표 확인 (하루 3회 식사)
    final feedGoalAchieved = pet.todayFeedCount >= feedGoalCount;
    
    // 5. 수면 목표 확인 (하루 6시간 이상)
    final sleepGoalAchieved = pet.todaySleepHours >= sleepGoalHours;
    
    // 6. 운동 목표 확인
    final todayActivity = await activityRepository.getTodayActivityData();
    final exerciseGoalAchieved = todayActivity.steps >= exerciseGoalSteps ||
        todayActivity.exerciseMinutes >= exerciseGoalMinutes;
    
    // 7. 일일 목표 엔티티 생성
    final dailyGoals = DailyGoals(
      date: todayDate,
      feedGoalAchieved: feedGoalAchieved,
      sleepGoalAchieved: sleepGoalAchieved,
      exerciseGoalAchieved: exerciseGoalAchieved,
      feedProgress: pet.todayFeedCount,
      sleepHours: pet.todaySleepHours,
      exerciseSteps: todayActivity.steps,
      exerciseMinutes: todayActivity.exerciseMinutes,
    );
    
    // 8. 점수 계산
    final score = dailyGoals.totalScore;
    final expGain = score * expPerScore;
    
    return DailyGoalsScore(
      dailyGoals: dailyGoals,
      score: score,
      expGain: expGain,
    );
  }
}

/// 일일 목표 점수 결과
class DailyGoalsScore {
  /// 일일 목표 달성 상태
  final DailyGoals dailyGoals;
  
  /// 총 점수 (0~3)
  final int score;
  
  /// 획득 경험치
  final int expGain;
  
  DailyGoalsScore({
    required this.dailyGoals,
    required this.score,
    required this.expGain,
  });
}
