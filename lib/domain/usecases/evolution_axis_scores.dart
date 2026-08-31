import '../constants/mission_catalog.dart';
import '../entities/evolution_type.dart';
import '../entities/mission.dart';
import '../entities/pet.dart';

/// 종 결정(2단계 진화)의 두 축 점수 — 진화 판정과 연출 서사의 단일 소스
///
/// [EvolvePetUseCase]의 종 판정과 종 결정 연출(SpeciesRevealNarrator)이
/// 같은 점수를 봐야 "판정 근거" 문구가 실제 판정과 어긋나지 않는다.
/// 점수 공식을 바꿀 때는 반드시 이 클래스만 수정한다.
///
/// 활발 ↔ 차분: 실제 움직임(걸음·운동) vs 정적 휴식(수면·idle)
///   moveScore = totalSteps/2000 + totalExerciseMinutes/10 (+활발 미션 보너스)
///   restScore = sleepAchievedCount + totalIdleHours/6 (+차분 미션 보너스)
/// 규칙 ↔ 자유: 꾸준한 접속(연속 로그인) vs 자유로운 식사(급식 달성)
///   regularScore = consecutiveLoginDays (+규칙 미션 보너스)
///   freeScore    = feedAchievedCount (+자유 미션 보너스)
///
/// 동점은 활발·규칙이 이긴다(>=) — 초기 데이터가 적을 때 기본 성향을
/// "부지런한 쪽"으로 준다.
class EvolutionAxisScores {
  final double moveScore;
  final double restScore;
  final double regularScore;
  final double freeScore;

  const EvolutionAxisScores({
    required this.moveScore,
    required this.restScore,
    required this.regularScore,
    required this.freeScore,
  });

  factory EvolutionAxisScores.fromPet(Pet pet) {
    return EvolutionAxisScores(
      moveScore: pet.totalSteps / 2000.0 +
          pet.totalExerciseMinutes / 10.0 +
          MissionCatalog.axisBonus(pet, MissionAxis.active),
      restScore: pet.sleepAchievedCount.toDouble() +
          pet.totalIdleHours / 6.0 +
          MissionCatalog.axisBonus(pet, MissionAxis.calm),
      regularScore: pet.consecutiveLoginDays.toDouble() +
          MissionCatalog.axisBonus(pet, MissionAxis.regular),
      freeScore: pet.feedAchievedCount.toDouble() +
          MissionCatalog.axisBonus(pet, MissionAxis.free),
    );
  }

  /// 활발 축 우세 여부 (동점이면 활발)
  bool get isActive => moveScore >= restScore;

  /// 규칙 축 우세 여부 (동점이면 규칙)
  bool get isRegular => regularScore >= freeScore;

  /// 두 축 조합으로 결정되는 종
  ///
  /// 활발 && 규칙 → tiger (백호) / 활발 && 자유 → bird (주작)
  /// 차분 && 규칙 → turtle (현무) / 차분 && 자유 → snake (청룡)
  EvolutionType get resultType {
    if (isActive && isRegular) return EvolutionType.tiger;
    if (isActive) return EvolutionType.bird;
    if (isRegular) return EvolutionType.turtle;
    return EvolutionType.snake;
  }

  // ── 설화 영물(히든 종) 각성 임계 — 원천 지표 직접 판정 ──
  // Lv5(종 결정) 시점에 한 지표가 극단이면 사신수 대신 각성한다.
  // 세트 클리어 유저는 3~4일에 Lv5 도달 — 그 기간에 "일부러" 몰아야
  // 닿는 수치로 잡아 히든의 희소성을 유지한다.
  // (해태만 예외적으로 "가볍게 오래" — 레벨업이 느린 개근 유저 보상)

  /// 삼족오: 누적 4만 보 (하루 1만+ 보씩 걸은 걸음왕)
  static const int samjokoStepsThreshold = 40000;

  /// 구미호: 급식 목표 9회 달성 (매일 모든 슬롯을 챙긴 미식가)
  static const int gumihoFeedsThreshold = 9;

  /// 달토끼: 수면 목표 8회 달성 (매일 두 번씩 재우는 꿀잠 육성)
  static const int moonrabbitSleepsThreshold = 8;

  /// 해태: 연속 접속 7일 (매일 빠짐없이 찾아온 개근왕)
  static const int haetaeLoginDaysThreshold = 7;

  /// 도깨비: 배틀 12승 (하루 전승 페이스로 2~3일 — 싸움꾼)
  static const int dokkaebiWinsThreshold = 12;

  /// 황룡: 급식·수면·운동 달성 + 연속 접속 네 지표 모두 5 이상
  /// (오방의 중앙 — 어느 하나 몰지 않고 고루 완벽하게 키운 육성 보상)
  static const int hwangryongBalancedThreshold = 5;

  /// 히든 종 각성 판정 — 해당 없으면 null (사신수 4분면으로)
  ///
  /// 여러 조건 동시 충족 시 달성 난도가 높은 순서로 우선한다:
  /// 황룡(4축 동시) → 삼족오 → 구미호 → 달토끼 → 도깨비 → 해태
  static EvolutionType? hiddenTypeFor(Pet pet) {
    if (pet.feedAchievedCount >= hwangryongBalancedThreshold &&
        pet.sleepAchievedCount >= hwangryongBalancedThreshold &&
        pet.exerciseAchievedCount >= hwangryongBalancedThreshold &&
        pet.consecutiveLoginDays >= hwangryongBalancedThreshold) {
      return EvolutionType.hwangryong;
    }
    if (pet.totalSteps >= samjokoStepsThreshold) {
      return EvolutionType.samjoko;
    }
    if (pet.feedAchievedCount >= gumihoFeedsThreshold) {
      return EvolutionType.gumiho;
    }
    if (pet.sleepAchievedCount >= moonrabbitSleepsThreshold) {
      return EvolutionType.moonrabbit;
    }
    if (pet.battleVictoryCount >= dokkaebiWinsThreshold) {
      return EvolutionType.dokkaebi;
    }
    if (pet.consecutiveLoginDays >= haetaeLoginDaysThreshold) {
      return EvolutionType.haetae;
    }
    return null;
  }
}
