import '../entities/pet.dart';
import '../entities/evolution_type.dart';
import '../repositories/pet_repository.dart';

/// 반려동물 진화 유스케이스
/// 누적 활동 패턴에 따라 Pet의 진화 단계와 방향을 결정하는 비즈니스 로직
///
/// 진화 단계 (4단계):
/// - 1단계: 털뭉치 (evolutionStage = 1, 기본 상태)
/// - 2단계: 성장기 (evolutionStage = 2, Lv5 + 활동 패턴)
/// - 3단계: 성체 (evolutionStage = 3, Lv10 + 배틀/streak 조건)
/// - 4단계: 완전체 (evolutionStage = 4, Lv15 + 마스터 조건)
///
/// 진화 방향:
/// - active: 걸음/운동 중심
/// - restful: 미사용/수면 중심
/// - balanced: 균형 또는 기본
class EvolvePetUseCase {
  final PetRepository petRepository;

  /// 2단계 활동형 임계값 (기간 기반)
  static const int stage2ActiveSteps = 35000;
  static const int stage2ActiveMinutes = 100;

  /// 2단계 휴식형 임계값
  static const int stage2RestfulIdleIncrease = 35;

  /// 3단계 추가 조건
  static const int stage3ActiveBattleWins = 10;
  static const int stage3RestfulStreak = 3;
  static const int stage3BalancedBattleWins = 5;
  static const int stage3BalancedStreak = 2;

  /// 4단계 마스터 조건
  static const int stage4ActiveSteps = 200000;
  static const int stage4ActiveBattleWins = 30;
  static const int stage4RestfulIdleHours = 500;
  static const int stage4RestfulStreak = 10;
  static const int stage4BalancedSteps = 100000;
  static const int stage4BalancedIdleHours = 250;
  static const int stage4BalancedStreak = 5;

  EvolvePetUseCase(this.petRepository);

  /// 진화 체크 및 실행
  Future<Pet> call(String petId) async {
    final pet = await petRepository.getPet(petId);
    if (pet.isDead) return pet;

    int newStage = pet.evolutionStage;
    EvolutionType? newType = pet.evolutionType;

    // 4단계: Lv15 + 마스터 조건
    if (pet.level >= 15 && newStage < 4 && newStage >= 3) {
      if (_meetsStage4Condition(pet)) {
        newStage = 4;
      }
    }
    // 3단계: Lv10 + 배틀/streak 조건
    else if (pet.level >= 10 && newStage < 3 && newStage >= 2) {
      if (_meetsStage3Condition(pet)) {
        newStage = 3;
      }
    }
    // 2단계: Lv5 + 활동 패턴
    else if (pet.level >= 5 && newStage < 2) {
      newStage = 2;
      newType = _determineEvolutionType(pet);
    }

    if (newStage == pet.evolutionStage && newType == pet.evolutionType) {
      return pet;
    }

    final currentTime = DateTime.now().millisecondsSinceEpoch;
    final evolvedPet = pet.copyWith(
      evolutionStage: newStage,
      evolutionType: newType,
      lastUpdated: currentTime,
    );

    await petRepository.updatePet(evolvedPet);
    return evolvedPet;
  }

  /// 2단계 진화 방향 결정 (활동 패턴 기반)
  EvolutionType _determineEvolutionType(Pet pet) {
    final isActive = pet.totalSteps > stage2ActiveSteps ||
        pet.totalExerciseMinutes > stage2ActiveMinutes;
    final isRestful = pet.totalIdleHours > stage2RestfulIdleIncrease;

    if (isActive) return EvolutionType.active;
    if (isRestful) return EvolutionType.restful;
    return EvolutionType.balanced;
  }

  /// 3단계 조건 충족 여부
  bool _meetsStage3Condition(Pet pet) {
    switch (pet.evolutionType) {
      case EvolutionType.active:
        return pet.battleVictoryCount >= stage3ActiveBattleWins;
      case EvolutionType.restful:
        return pet.goalStreakCount >= stage3RestfulStreak;
      case EvolutionType.balanced:
        return pet.battleVictoryCount >= stage3BalancedBattleWins &&
            pet.goalStreakCount >= stage3BalancedStreak;
      default:
        return false;
    }
  }

  /// 4단계 마스터 조건 충족 여부
  bool _meetsStage4Condition(Pet pet) {
    switch (pet.evolutionType) {
      case EvolutionType.active:
        return pet.totalSteps >= stage4ActiveSteps &&
            pet.battleVictoryCount >= stage4ActiveBattleWins;
      case EvolutionType.restful:
        return pet.totalIdleHours >= stage4RestfulIdleHours &&
            pet.goalStreakCount >= stage4RestfulStreak;
      case EvolutionType.balanced:
        return pet.totalSteps >= stage4BalancedSteps &&
            pet.totalIdleHours >= stage4BalancedIdleHours &&
            pet.goalStreakCount >= stage4BalancedStreak;
      default:
        return false;
    }
  }

  /// 진화 가능 여부 확인
  bool canEvolve(Pet pet) {
    if (pet.level >= 15 && pet.evolutionStage < 4 && pet.evolutionStage >= 3) {
      return _meetsStage4Condition(pet);
    }
    if (pet.level >= 10 && pet.evolutionStage < 3 && pet.evolutionStage >= 2) {
      return _meetsStage3Condition(pet);
    }
    if (pet.level >= 5 && pet.evolutionStage < 2) return true;
    return false;
  }
}
