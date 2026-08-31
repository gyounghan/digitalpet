import 'dart:math';

import '../entities/evolution_type.dart';
import '../entities/pet.dart';
import '../entities/wild_encounter.dart';

/// 야생 조우 스폰 판정 — 순수 로직 (저장/알림은 WildEncounterService 담당)
///
/// 규칙:
/// - 오늘 걸음이 [spawnStepThreshold] 이상이어야 후보 (산책하다 만난다)
/// - 하루 1회만 굴린다 (호출부가 굴린 날짜를 기록) — [spawnChance] 확률로 등장,
///   실패하면 그날은 조우 없음 (매일 나오지 않아야 "우연히 만난" 맛이 산다)
/// - 상대 종: 사신수 위주, [hiddenSpeciesChance] 확률로 설화 영물 (희귀 조우)
/// - 내 펫이 종 미결정(털뭉치)이면 상대도 털뭉치
/// - 레벨: 내 레벨 ±1
class WildEncounterSpawner {
  WildEncounterSpawner._();

  /// 조우 후보가 되는 오늘 걸음 수
  static const int spawnStepThreshold = 2000;

  /// 굴렸을 때 실제로 등장할 확률
  static const double spawnChance = 0.7;

  /// 등장 시 설화 영물일 확률 (나머지는 사신수)
  static const double hiddenSpeciesChance = 0.3;

  static const List<EvolutionType> _guardians = [
    EvolutionType.bird,
    EvolutionType.snake,
    EvolutionType.tiger,
    EvolutionType.turtle,
  ];

  static const List<EvolutionType> _hidden = [
    EvolutionType.samjoko,
    EvolutionType.gumiho,
    EvolutionType.moonrabbit,
    EvolutionType.haetae,
    EvolutionType.dokkaebi,
    EvolutionType.hwangryong,
  ];

  /// 오늘 굴림 후보인지 (걸음 임계 + 살아있는 펫)
  static bool isEligible(Pet pet) {
    if (pet.isDead) return false;
    return pet.todaySyncedSteps >= spawnStepThreshold;
  }

  /// 조우 굴림 — 등장하면 WildEncounter, 아니면 null
  ///
  /// 호출부는 결과와 무관하게 "오늘 굴렸음"을 기록해야 한다 (하루 1회).
  static WildEncounter? roll(Pet pet, {Random? random, DateTime? now}) {
    random ??= Random();
    final clock = now ?? DateTime.now();

    if (random.nextDouble() >= spawnChance) return null;

    final String? speciesName;
    if (pet.evolutionStage < 2 || pet.evolutionType == null) {
      speciesName = null; // 털뭉치는 털뭉치끼리
    } else if (random.nextDouble() < hiddenSpeciesChance) {
      speciesName = _hidden[random.nextInt(_hidden.length)].name;
    } else {
      speciesName = _guardians[random.nextInt(_guardians.length)].name;
    }

    final dateString =
        '${clock.year}-${clock.month.toString().padLeft(2, '0')}-'
        '${clock.day.toString().padLeft(2, '0')}';

    return WildEncounter(
      speciesName: speciesName,
      level: max(1, pet.level - 1 + random.nextInt(3)),
      spawnedAtMs: clock.millisecondsSinceEpoch,
      dateString: dateString,
    );
  }
}
