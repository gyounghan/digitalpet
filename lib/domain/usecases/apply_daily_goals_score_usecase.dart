import '../entities/pet.dart';
import '../repositories/pet_repository.dart';
import 'calculate_daily_goals_score_usecase.dart';

/// 목표 점수 적용 유스케이스
/// 목표 달성 점수를 계산하고 경험치를 적용
/// 기간 만료 시 페널티, 목표 달성 시 기간 리셋
///
/// 동작:
/// 1. 목표 점수 계산
/// 2. 7일 초과 시 강제 리셋 + 페널티 (각 수치 -5)
/// 3. 모든 목표 달성 시 기간 리셋 + 연속 달성 보너스
/// 4. 점수에 따른 경험치 획득
/// 5. 레벨 업 계산
class ApplyDailyGoalsScoreUseCase {
  final PetRepository petRepository;
  final CalculateDailyGoalsScoreUseCase calculateScoreUseCase;

  /// 기간 만료 페널티 수치
  static const int expiredPenalty = 3;

  ApplyDailyGoalsScoreUseCase({
    required this.petRepository,
    required this.calculateScoreUseCase,
  });

  /// 목표 점수 적용
  ///
  /// [petId] 적용할 반려동물 ID
  ///
  /// 반환: 업데이트된 Pet 엔티티
  Future<Pet> call(String petId) async {
    // 1. 현재 Pet 조회
    var pet = await petRepository.getPet(petId);

    // 사망한 펫은 스킵
    if (pet.isDead) return pet;

    // 2. 일일 항목 리셋 확인
    if (pet.needsGoalReset) {
      pet = pet.resetDailyGoals();
      await petRepository.updatePet(pet);
    }

    // 3. 목표 점수 계산
    final scoreResult = await calculateScoreUseCase(petId);

    // 4. 7일 초과 강제 리셋 + 페널티
    if (scoreResult.isExpired) {
      pet = pet.resetGoalPeriod(completed: false);
      pet = pet.copyWith(
        hunger: (pet.hunger - expiredPenalty).clamp(0, 100),
        happiness: (pet.happiness - expiredPenalty).clamp(0, 100),
        stamina: (pet.stamina - expiredPenalty).clamp(0, 100),
      );
      await petRepository.updatePet(pet);
      return pet;
    }

    // 5. 모든 목표 달성 시 기간 리셋 + 보너스
    if (scoreResult.dailyGoals.allGoalsAchieved) {
      pet = pet.resetGoalPeriod(completed: true);
    }

    // 6. 경험치 적용
    final newExp = pet.exp + scoreResult.expGain;

    // 7. 레벨 업 계산 (100 경험치당 1 레벨)
    final oldLevel = pet.exp ~/ 100;
    final newLevel = newExp ~/ 100;
    final levelIncrease = newLevel - oldLevel;

    // 8. 현재 시간으로 업데이트
    final currentTime = DateTime.now().millisecondsSinceEpoch;

    // 9. 업데이트된 Pet 생성
    final updatedPet = pet.copyWith(
      exp: newExp,
      level: pet.level + levelIncrease,
      lastUpdated: currentTime,
    );

    // 10. 저장
    await petRepository.updatePet(updatedPet);

    return updatedPet;
  }
}
