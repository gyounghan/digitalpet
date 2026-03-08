import '../entities/pet.dart';
import '../entities/activity_data.dart';
import '../entities/battle_history.dart';
import '../repositories/pet_repository.dart';
import '../repositories/activity_repository.dart';
import '../repositories/battle_history_repository.dart';

/// 활동 기반 대결 유스케이스
/// 사용자의 실제 활동량을 기반으로 대결 결과를 결정하는 비즈니스 로직
/// 
/// 규칙:
/// - 일일 목표 달성 여부로 승부 결정
/// - 목표 달성 시: 승리 → 보너스 경험치 획득
/// - 목표 미달성 시: 패배 → 소량 경험치 획득
/// 
/// 일일 목표:
/// - 걸음 수: 10,000보
/// - 운동 시간: 30분
class BattleWithActivityUseCase {
  final PetRepository petRepository;
  final ActivityRepository activityRepository;
  final BattleHistoryRepository battleHistoryRepository;
  
  /// 일일 목표 걸음 수
  static const int dailyGoalSteps = 10000;
  
  /// 일일 목표 운동 시간 (분)
  static const int dailyGoalExerciseMinutes = 30;
  
  /// 승리 시 보너스 경험치
  static const int victoryBonusExp = 100;
  
  /// 패배 시 경험치
  static const int defeatExp = 20;
  
  BattleWithActivityUseCase({
    required this.petRepository,
    required this.activityRepository,
    required this.battleHistoryRepository,
  });
  
  /// 활동 기반 대결 실행
  /// 
  /// [petId] 대결에 참여할 반려동물 ID
  /// 
  /// 반환: 대결 결과 (승리/패배)와 업데이트된 Pet 엔티티
  /// 
  /// 동작:
  /// 1. 오늘의 활동 데이터 조회
  /// 2. 일일 목표 달성 여부 확인
  /// 3. 목표 달성 시 승리, 미달성 시 패배
  /// 4. 대결 결과에 따라 경험치 추가
  /// 5. 업데이트된 Pet 저장
  Future<BattleResult> call(String petId) async {
    // 1. 현재 Pet 조회
    final pet = await petRepository.getPet(petId);
    
    // 2. 오늘의 활동 데이터 조회
    final todayActivity = await activityRepository.getTodayActivityData();
    
    // 3. 일일 목표 달성 여부 확인
    final isGoalAchieved = todayActivity.steps >= dailyGoalSteps ||
        todayActivity.exerciseMinutes >= dailyGoalExerciseMinutes;
    
    // 4. 대결 결과에 따라 경험치 계산
    final expGain = isGoalAchieved ? victoryBonusExp : defeatExp;
    final newExp = pet.exp + expGain;
    
    // 5. 레벨 업 계산 (100 경험치당 1 레벨)
    final oldLevel = pet.exp ~/ 100;
    final newLevel = newExp ~/ 100;
    final levelIncrease = newLevel - oldLevel;
    
    // 6. 현재 시간으로 업데이트
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    
    // 7. 업데이트된 Pet 생성
    final updatedPet = pet.copyWith(
      exp: newExp,
      level: pet.level + levelIncrease,
      lastUpdated: currentTime,
    );
    
    // 8. 저장
    await petRepository.updatePet(updatedPet);
    
    // 9. 대결 전적 저장
    final battleHistory = BattleHistory(
      id: '${petId}_${currentTime}',
      date: currentTime,
      isVictory: isGoalAchieved,
      expGained: expGain,
      steps: todayActivity.steps,
      exerciseMinutes: todayActivity.exerciseMinutes,
    );
    await battleHistoryRepository.saveBattleHistory(battleHistory);
    
    // 10. 대결 결과 반환
    return BattleResult(
      isVictory: isGoalAchieved,
      expGained: expGain,
      updatedPet: updatedPet,
      todaySteps: todayActivity.steps,
      todayExerciseMinutes: todayActivity.exerciseMinutes,
    );
  }
}

/// 대결 결과
/// 활동 기반 대결의 결과를 나타내는 클래스
class BattleResult {
  /// 승리 여부
  final bool isVictory;
  
  /// 획득한 경험치
  final int expGained;
  
  /// 업데이트된 Pet 엔티티
  final Pet updatedPet;
  
  /// 오늘의 걸음 수
  final int todaySteps;
  
  /// 오늘의 운동 시간 (분)
  final int todayExerciseMinutes;
  
  BattleResult({
    required this.isVictory,
    required this.expGained,
    required this.updatedPet,
    required this.todaySteps,
    required this.todayExerciseMinutes,
  });
}
