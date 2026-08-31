import '../entities/evolution_type.dart';

/// 종별 스탯 배율
class StatMultipliers {
  final double hunger;
  final double happiness;
  final double stamina;
  final double exp;

  const StatMultipliers({
    required this.hunger,
    required this.happiness,
    required this.stamina,
    required this.exp,
  });

  factory StatMultipliers.identity() => const StatMultipliers(
        hunger: 1.0,
        happiness: 1.0,
        stamina: 1.0,
        exp: 1.0,
      );
}

/// 종별 성장 배율 설정
///
/// 기본값 1.0 = 변경 없음, >1.0 = 증가/감소 강화, <1.0 = 약화
///
/// 성격 요약:
/// - bird: 행복도 잘 오르지만 체력 빨리 소모 (활발)
/// - snake: 포만감 유지 좋지만 행복도 올리기 어려움 (은둔)
/// - tiger: 경험치 +30% 보너스, 나머지 균형 (전투형)
/// - turtle: 체력 유지 우수, 행복도 천천히 감소 (안정형)
class SpeciesGrowthConfig {
  SpeciesGrowthConfig._();

  /// 증가 배율 (Feed/Play/Sleep/Activity 등 회복 계열 UseCase에 적용)
  static const Map<EvolutionType, StatMultipliers> gainMultipliers = {
    EvolutionType.bird: StatMultipliers(
      hunger: 1.0,
      happiness: 1.3,
      stamina: 0.85,
      exp: 1.0,
    ),
    EvolutionType.snake: StatMultipliers(
      hunger: 1.25,
      happiness: 0.8,
      stamina: 1.0,
      exp: 1.0,
    ),
    EvolutionType.tiger: StatMultipliers(
      hunger: 1.0,
      happiness: 1.0,
      stamina: 1.0,
      exp: 1.3,
    ),
    EvolutionType.turtle: StatMultipliers(
      hunger: 1.0,
      happiness: 1.0,
      stamina: 1.2,
      exp: 1.0,
    ),
    // 설화 영물 — 각성 축의 개성을 배율로 반영
    EvolutionType.samjoko: StatMultipliers(
      hunger: 1.0,
      happiness: 1.2,
      stamina: 0.9,
      exp: 1.1,
    ),
    EvolutionType.gumiho: StatMultipliers(
      hunger: 1.3,
      happiness: 1.0,
      stamina: 1.0,
      exp: 1.0,
    ),
    EvolutionType.moonrabbit: StatMultipliers(
      hunger: 1.0,
      happiness: 1.0,
      stamina: 1.3,
      exp: 1.0,
    ),
    EvolutionType.haetae: StatMultipliers(
      hunger: 1.0,
      happiness: 1.0,
      stamina: 1.0,
      exp: 1.15,
    ),
    EvolutionType.dokkaebi: StatMultipliers(
      hunger: 1.0,
      happiness: 1.1,
      stamina: 1.0,
      exp: 1.2,
    ),
    EvolutionType.hwangryong: StatMultipliers(
      hunger: 1.1,
      happiness: 1.1,
      stamina: 1.1,
      exp: 1.05,
    ),
  };

  /// 감소 배율 (UpdatePetStateUseCase 시간 감소 계열에 적용)
  /// >1.0 = 더 빨리 감소, <1.0 = 더 느리게 감소
  static const Map<EvolutionType, StatMultipliers> decayMultipliers = {
    EvolutionType.bird: StatMultipliers(
      hunger: 1.0,
      happiness: 1.0,
      stamina: 1.2,
      exp: 1.0,
    ),
    EvolutionType.snake: StatMultipliers(
      hunger: 0.8,
      happiness: 1.15,
      stamina: 1.0,
      exp: 1.0,
    ),
    EvolutionType.tiger: StatMultipliers(
      hunger: 1.0,
      happiness: 1.0,
      stamina: 1.0,
      exp: 1.0,
    ),
    EvolutionType.turtle: StatMultipliers(
      hunger: 1.0,
      happiness: 0.85,
      stamina: 0.8,
      exp: 1.0,
    ),
    EvolutionType.samjoko: StatMultipliers(
      hunger: 1.0,
      happiness: 1.0,
      stamina: 1.15,
      exp: 1.0,
    ),
    EvolutionType.gumiho: StatMultipliers(
      hunger: 1.1,
      happiness: 1.0,
      stamina: 1.0,
      exp: 1.0,
    ),
    EvolutionType.moonrabbit: StatMultipliers(
      hunger: 1.1,
      happiness: 1.0,
      stamina: 0.8,
      exp: 1.0,
    ),
    EvolutionType.haetae: StatMultipliers(
      hunger: 1.0,
      happiness: 0.9,
      stamina: 1.0,
      exp: 1.0,
    ),
    EvolutionType.dokkaebi: StatMultipliers(
      hunger: 1.15,
      happiness: 1.0,
      stamina: 1.0,
      exp: 1.0,
    ),
    EvolutionType.hwangryong: StatMultipliers(
      hunger: 0.95,
      happiness: 0.95,
      stamina: 0.95,
      exp: 1.0,
    ),
  };

  /// evolutionType이 null(1단계)이면 기본 배율 1.0 반환
  static StatMultipliers getGainMultipliers(EvolutionType? type) {
    if (type == null) return StatMultipliers.identity();
    return gainMultipliers[type] ?? StatMultipliers.identity();
  }

  static StatMultipliers getDecayMultipliers(EvolutionType? type) {
    if (type == null) return StatMultipliers.identity();
    return decayMultipliers[type] ?? StatMultipliers.identity();
  }
}
