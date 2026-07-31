import '../entities/mission.dart';
import '../entities/pet.dart';

/// 미션 카탈로그 — 성향 축별 중장기 도전과제 목록.
///
/// 각 미션은 완료 시 해당 축([Mission.axis])에 가중치를 더해 유아기 진화
/// 종 결정에 기여한다([axisBonus]). 완료는 펫 누적 지표에서 파생된다.
class MissionCatalog {
  MissionCatalog._();

  static const List<Mission> all = [
    // 활발 (→ tiger·bird): 많이 움직이고 싸운다
    Mission(
      id: 'walk_50k',
      title: '산책 매니아',
      description: '누적 5만 보 걷기',
      axis: MissionAxis.active,
      metric: MissionMetric.totalSteps,
      target: 50000,
    ),
    Mission(
      id: 'exercise_300',
      title: '운동 챌린지',
      description: '누적 운동 300분',
      axis: MissionAxis.active,
      metric: MissionMetric.totalExerciseMinutes,
      target: 300,
    ),
    Mission(
      id: 'battle_10',
      title: '백전노장',
      description: '전투 10승 달성',
      axis: MissionAxis.active,
      metric: MissionMetric.battleVictoryCount,
      target: 10,
    ),
    // 차분 (→ turtle·snake): 잘 쉬고 잠잔다
    Mission(
      id: 'sleep_10',
      title: '숙면 습관',
      description: '수면 목표 10회 달성',
      axis: MissionAxis.calm,
      metric: MissionMetric.sleepAchievedCount,
      target: 10,
    ),
    Mission(
      id: 'idle_40',
      title: '느긋한 휴식',
      description: '누적 휴식 40시간',
      axis: MissionAxis.calm,
      metric: MissionMetric.totalIdleHours,
      target: 40,
    ),
    // 규칙 (→ tiger·turtle): 꾸준히 접속한다
    Mission(
      id: 'login_14',
      title: '개근왕',
      description: '14일 연속 접속',
      axis: MissionAxis.regular,
      metric: MissionMetric.consecutiveLoginDays,
      target: 14,
    ),
    Mission(
      id: 'login_30',
      title: '꾸준함의 미학',
      description: '30일 연속 접속',
      axis: MissionAxis.regular,
      metric: MissionMetric.consecutiveLoginDays,
      target: 30,
    ),
    // 자유 (→ bird·snake): 자유롭게 자주 먹인다
    Mission(
      id: 'feed_20',
      title: '미식가',
      description: '급식 목표 20회 달성',
      axis: MissionAxis.free,
      metric: MissionMetric.feedAchievedCount,
      target: 20,
    ),
    Mission(
      id: 'feed_40',
      title: '대식가',
      description: '급식 목표 40회 달성',
      axis: MissionAxis.free,
      metric: MissionMetric.feedAchievedCount,
      target: 40,
    ),
  ];

  /// 특정 축에서 완료된 미션들의 가중치 합 (진화 점수에 더할 보너스).
  static double axisBonus(Pet pet, MissionAxis axis) {
    var sum = 0.0;
    for (final m in all) {
      if (m.axis == axis && m.isComplete(pet)) sum += m.weight;
    }
    return sum;
  }

  /// 완료한 미션 수 (UI 요약용).
  static int completedCount(Pet pet) =>
      all.where((m) => m.isComplete(pet)).length;
}
