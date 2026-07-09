import 'pet.dart';

/// 미션이 기여하는 성향 축 — 진화 종 결정의 2축 4극.
///
/// (활발/차분) × (규칙/자유) 조합이 종을 만든다:
/// 활발+규칙 tiger, 활발+자유 bird, 차분+규칙 turtle, 차분+자유 snake.
enum MissionAxis { active, calm, regular, free }

extension MissionAxisLabel on MissionAxis {
  String get label => switch (this) {
        MissionAxis.active => '활발',
        MissionAxis.calm => '차분',
        MissionAxis.regular => '규칙',
        MissionAxis.free => '자유',
      };
}

/// 미션이 진행도를 읽어오는 펫 누적 지표.
enum MissionMetric {
  totalSteps,
  totalExerciseMinutes,
  sleepAchievedCount,
  totalIdleHours,
  consecutiveLoginDays,
  feedAchievedCount,
  battleVictoryCount,
}

/// 중장기 도전과제.
///
/// 일일 목표(DailyGoals)와 달리 **한 번 달성하면 영구**이며, 완료 시 성향
/// 축([axis])에 [weight]만큼 기여해 유아기(stage 2) 진화 종 결정에 영향을 준다.
/// 완료 판정은 펫의 **기존 누적 지표에서 파생**하므로 별도 저장 필드가 없다.
class Mission {
  final String id;
  final String title;
  final String description;
  final MissionAxis axis;
  final MissionMetric metric;
  final int target;
  final double weight;

  const Mission({
    required this.id,
    required this.title,
    required this.description,
    required this.axis,
    required this.metric,
    required this.target,
    this.weight = 4.0,
  });

  /// 원천 지표의 현재 누적값 (진행도 계산·완료 판정 공용).
  int rawValue(Pet pet) => switch (metric) {
        MissionMetric.totalSteps => pet.totalSteps,
        MissionMetric.totalExerciseMinutes => pet.totalExerciseMinutes,
        MissionMetric.sleepAchievedCount => pet.sleepAchievedCount,
        MissionMetric.totalIdleHours => pet.totalIdleHours,
        MissionMetric.consecutiveLoginDays => pet.consecutiveLoginDays,
        MissionMetric.feedAchievedCount => pet.feedAchievedCount,
        MissionMetric.battleVictoryCount => pet.battleVictoryCount,
      };

  /// 표시용 진행도 (target 초과분은 잘라 0~target).
  int progress(Pet pet) {
    final v = rawValue(pet);
    return v > target ? target : v;
  }

  /// 진행률 0.0~1.0.
  double ratio(Pet pet) => target <= 0 ? 1.0 : progress(pet) / target;

  bool isComplete(Pet pet) => rawValue(pet) >= target;
}
