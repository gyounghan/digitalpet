import '../entities/daily_goals.dart';
import '../repositories/pet_repository.dart';
import '../repositories/activity_repository.dart';

/// 일일 목표 점수 계산 유스케이스
/// 포만감, 수면, 운동 각각의 목표 달성 여부를 확인하고 점수를 계산
/// 
/// 목표 (레벨에 따라 다름):
/// - 포만감: 레벨 1~5는 1회, 레벨 6~10은 2회, 레벨 11+는 3회
/// - 수면: 레벨 1~5는 4시간, 레벨 6~10은 5시간, 레벨 11+는 6시간
/// - 운동: 레벨 1~5는 5,000보/15분, 레벨 6~10은 7,500보/22분, 레벨 11+는 10,000보/30분
/// 
/// 점수:
/// - 각 목표 달성 시 1점씩 부여 (최대 3점)
/// - 점수에 따라 경험치 획득 (점수당 20 경험치)
class CalculateDailyGoalsScoreUseCase {
  final PetRepository petRepository;
  final ActivityRepository activityRepository;
  
  /// 점수당 경험치
  static const int expPerScore = 20;
  
  /// 레벨에 따른 포만감 목표 횟수 반환
  /// 
  /// [level] 펫의 현재 레벨
  /// 
  /// 반환: 목표 식사 횟수 (1~3)
  static int getFeedGoalCount(int level) {
    if (level <= 5) {
      return 1;
    } else if (level <= 10) {
      return 2;
    } else {
      return 3;
    }
  }
  
  /// 레벨에 따른 수면 목표 시간 반환
  /// 
  /// [level] 펫의 현재 레벨
  /// 
  /// 반환: 목표 수면 시간 (시간)
  static int getSleepGoalHours(int level) {
    if (level <= 5) {
      return 4;
    } else if (level <= 10) {
      return 5;
    } else {
      return 6;
    }
  }
  
  /// 레벨에 따른 운동 목표 걸음 수 반환
  /// 
  /// [level] 펫의 현재 레벨
  /// 
  /// 반환: 목표 걸음 수
  static int getExerciseGoalSteps(int level) {
    if (level <= 5) {
      return 5000;
    } else if (level <= 10) {
      return 7500;
    } else {
      return 10000;
    }
  }
  
  /// 레벨에 따른 운동 목표 시간 반환
  /// 
  /// [level] 펫의 현재 레벨
  /// 
  /// 반환: 목표 운동 시간 (분)
  static int getExerciseGoalMinutes(int level) {
    if (level <= 5) {
      return 15;
    } else if (level <= 10) {
      return 22;
    } else {
      return 30;
    }
  }
  
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
    
    // 4. 레벨에 따른 목표 값 계산
    final feedGoalCount = getFeedGoalCount(pet.level);
    final sleepGoalHours = getSleepGoalHours(pet.level);
    final exerciseGoalSteps = getExerciseGoalSteps(pet.level);
    final exerciseGoalMinutes = getExerciseGoalMinutes(pet.level);
    
    // 5. 포만감 목표 확인 (레벨에 따라 1~3회)
    final feedGoalAchieved = pet.todayFeedCount >= feedGoalCount;
    
    // 6. 수면 목표 확인 (레벨에 따라 4~6시간)
    final sleepGoalAchieved = pet.todaySleepHours >= sleepGoalHours;
    
    // 7. 운동 목표 확인 (레벨에 따라 다름)
    final todayActivity = await activityRepository.getTodayActivityData();
    final exerciseGoalAchieved = todayActivity.steps >= exerciseGoalSteps ||
        todayActivity.exerciseMinutes >= exerciseGoalMinutes;
    
    // 8. 일일 목표 엔티티 생성
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
    
    // 9. 점수 계산
    final score = dailyGoals.totalScore;
    final expGain = score * expPerScore;
    
    return DailyGoalsScore(
      dailyGoals: dailyGoals,
      score: score,
      expGain: expGain,
      feedGoalCount: feedGoalCount,
      sleepGoalHours: sleepGoalHours,
      exerciseGoalSteps: exerciseGoalSteps,
      exerciseGoalMinutes: exerciseGoalMinutes,
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
  
  /// 레벨에 따른 포만감 목표 횟수
  final int feedGoalCount;
  
  /// 레벨에 따른 수면 목표 시간
  final int sleepGoalHours;
  
  /// 레벨에 따른 운동 목표 걸음 수
  final int exerciseGoalSteps;
  
  /// 레벨에 따른 운동 목표 시간 (분)
  final int exerciseGoalMinutes;
  
  DailyGoalsScore({
    required this.dailyGoals,
    required this.score,
    required this.expGain,
    required this.feedGoalCount,
    required this.sleepGoalHours,
    required this.exerciseGoalSteps,
    required this.exerciseGoalMinutes,
  });
}
