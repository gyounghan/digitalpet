import '../entities/pet.dart';
import '../repositories/pet_repository.dart';

/// 폰 흔들기 → 걸음수 보너스 유스케이스
///
/// 사용자가 폰을 흔든 횟수를 받아서 (count * stepsPerShake) 만큼
/// 펫의 누적 걸음수에 추가한다. 실내 운동 1분 대체로,
/// 거동이 어려운 사용자가 활동 보상을 얻는 접근성 액션이다.
///
/// 규칙:
/// - 하루 최대 1회 사용 (todayAlternativeExerciseCount 슬롯 재사용)
/// - 세션 1회당 최대 100회 흔들기까지 보상 인정
/// - 흔들기 1회 = 5걸음 환산
class ShakeStepBonusUseCase {
  final PetRepository petRepository;

  /// 흔들기 1회당 환산 걸음 수
  static const int stepsPerShake = 5;

  /// 1세션 최대 흔들기 인정 횟수
  static const int maxShakesPerSession = 100;

  /// 하루 최대 사용 횟수 (1회)
  static const int maxSessionsPerDay = 1;

  ShakeStepBonusUseCase(this.petRepository);

  /// 사용 가능 여부 확인
  bool canUse(Pet pet) {
    return pet.todayAlternativeExerciseCount < maxSessionsPerDay;
  }

  /// 흔들기 보너스 적용
  ///
  /// [petId] 대상 펫 ID
  /// [shakeCount] 측정된 흔들기 횟수
  ///
  /// 반환: 업데이트된 Pet 엔티티 (사용 한도 초과면 원래 Pet)
  Future<Pet> call(String petId, int shakeCount) async {
    var pet = await petRepository.getPet(petId);

    if (pet.needsGoalReset) {
      pet = pet.resetDailyGoals();
    }

    if (pet.todayAlternativeExerciseCount >= maxSessionsPerDay) {
      return pet;
    }

    final clampedShakes = shakeCount.clamp(0, maxShakesPerSession);
    if (clampedShakes <= 0) {
      // 횟수 0이어도 사용 카운트는 증가시키지 않음 (실수 방지)
      return pet;
    }

    final bonusSteps = clampedShakes * stepsPerShake;
    final currentTime = DateTime.now().millisecondsSinceEpoch;

    final updatedPet = pet.copyWith(
      totalSteps: pet.totalSteps + bonusSteps,
      todayAlternativeExerciseCount: pet.todayAlternativeExerciseCount + 1,
      lastUpdated: currentTime,
    );

    await petRepository.updatePet(updatedPet);
    return updatedPet;
  }
}
