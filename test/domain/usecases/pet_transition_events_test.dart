import 'package:flutter_test/flutter_test.dart';
import 'package:pocketfriend/domain/entities/evolution_type.dart';
import 'package:pocketfriend/domain/entities/pet.dart';
import 'package:pocketfriend/domain/usecases/calculate_daily_goals_score_usecase.dart';
import 'package:pocketfriend/domain/usecases/pet_transition_events.dart';

void main() {
  Pet makePet({
    int todayFeedAchievedCount = 0,
    int todaySleepAchievedCount = 0,
    int todayExerciseAchievedCount = 0,
    int todaySetExpClaimed = 0,
    int evolutionStage = 1,
    EvolutionType? evolutionType,
    bool isDead = false,
  }) {
    return Pet(
      id: 'test-pet',
      name: '테스트',
      hunger: 80,
      happiness: 80,
      stamina: 80,
      exp: 0,
      level: 1,
      evolutionStage: evolutionStage,
      evolutionType: evolutionType,
      lastUpdated: 0,
      lastStatusDecayUpdated: 0,
      todayFeedAchievedCount: todayFeedAchievedCount,
      todaySleepAchievedCount: todaySleepAchievedCount,
      todayExerciseAchievedCount: todayExerciseAchievedCount,
      todaySetExpClaimed: todaySetExpClaimed,
      isDead: isDead,
    );
  }

  group('PetTransitionEvents.diff — 목표 달성 감지', () {
    test('식사 달성 카운트 증가 → feed 이벤트', () {
      final events = PetTransitionEvents.diff(
        makePet(todayFeedAchievedCount: 0),
        makePet(todayFeedAchievedCount: 1),
      );
      expect(events.achievedNow, {GoalCategory.feed});
      expect(events.setsCompleted, 0);
      expect(events.hasAny, isTrue);
    });

    test('세 카테고리 동시 증가 → 셋 다 이벤트', () {
      final events = PetTransitionEvents.diff(
        makePet(),
        makePet(
          todayFeedAchievedCount: 1,
          todaySleepAchievedCount: 1,
          todayExerciseAchievedCount: 2,
        ),
      );
      expect(events.achievedNow,
          {GoalCategory.feed, GoalCategory.sleep, GoalCategory.exercise});
    });

    test('변화 없으면 이벤트 없음', () {
      final events = PetTransitionEvents.diff(
        makePet(todayFeedAchievedCount: 2),
        makePet(todayFeedAchievedCount: 2),
      );
      expect(events.hasAny, isFalse);
    });

    test('자정 리셋(감소)은 이벤트가 아니다', () {
      final events = PetTransitionEvents.diff(
        makePet(
          todayFeedAchievedCount: 3,
          todaySleepAchievedCount: 1,
          todaySetExpClaimed: 2,
        ),
        makePet(),
      );
      expect(events.hasAny, isFalse);
    });
  });

  group('PetTransitionEvents.diff — 세트 완성', () {
    test('첫 세트 완성 → 기본 보상 EXP', () {
      final events = PetTransitionEvents.diff(
        makePet(todaySetExpClaimed: 0),
        makePet(todaySetExpClaimed: 1),
      );
      expect(events.setsCompleted, 1);
      expect(
          events.setRewardExp, CalculateDailyGoalsScoreUseCase.setExpBase);
    });

    test('두 번째 세트 완성 → 반감 보상 EXP', () {
      final events = PetTransitionEvents.diff(
        makePet(todaySetExpClaimed: 1),
        makePet(todaySetExpClaimed: 2),
      );
      expect(events.setsCompleted, 1);
      expect(events.setRewardExp,
          CalculateDailyGoalsScoreUseCase.setExpBase >> 1);
    });
  });

  group('PetTransitionEvents.shouldRevealEvolution', () {
    test('본 단계 2 → 현재 3단계면 연출', () {
      expect(
        PetTransitionEvents.shouldRevealEvolution(
            seenStage: 2, pet: makePet(evolutionStage: 3)),
        isTrue,
      );
    });

    test('본 단계 3 → 현재 4단계면 연출', () {
      expect(
        PetTransitionEvents.shouldRevealEvolution(
            seenStage: 3, pet: makePet(evolutionStage: 4)),
        isTrue,
      );
    });

    test('2단계 도달은 종 결정 연출 전담 — 연출 안 함', () {
      expect(
        PetTransitionEvents.shouldRevealEvolution(
            seenStage: 1, pet: makePet(evolutionStage: 2)),
        isFalse,
      );
    });

    test('기준(seenStage) 없으면 뒤늦은 연출 방지 — 연출 안 함', () {
      expect(
        PetTransitionEvents.shouldRevealEvolution(
            seenStage: null, pet: makePet(evolutionStage: 4)),
        isFalse,
      );
    });

    test('같거나 낮은 단계면 연출 안 함', () {
      expect(
        PetTransitionEvents.shouldRevealEvolution(
            seenStage: 3, pet: makePet(evolutionStage: 3)),
        isFalse,
      );
      expect(
        PetTransitionEvents.shouldRevealEvolution(
            seenStage: 4, pet: makePet(evolutionStage: 3)),
        isFalse,
      );
    });

    test('죽은 펫은 연출 안 함', () {
      expect(
        PetTransitionEvents.shouldRevealEvolution(
            seenStage: 2, pet: makePet(evolutionStage: 3, isDead: true)),
        isFalse,
      );
    });
  });

  group('PetTransitionEvents.shouldRevealAwakening', () {
    test('사신수 → 영물(도깨비) 종 변경이면 각성 연출', () {
      expect(
        PetTransitionEvents.shouldRevealAwakening(
          seenTypeName: 'snake',
          pet: makePet(evolutionStage: 2, evolutionType: EvolutionType.dokkaebi),
        ),
        isTrue,
      );
    });

    test('본 종과 현재 종이 같으면 연출 안 함 (중복 방지)', () {
      expect(
        PetTransitionEvents.shouldRevealAwakening(
          seenTypeName: 'dokkaebi',
          pet: makePet(evolutionStage: 3, evolutionType: EvolutionType.dokkaebi),
        ),
        isFalse,
      );
    });

    test('현재 종이 사신수면 각성 아님 — 연출 안 함', () {
      expect(
        PetTransitionEvents.shouldRevealAwakening(
          seenTypeName: 'bird',
          pet: makePet(evolutionStage: 3, evolutionType: EvolutionType.snake),
        ),
        isFalse,
      );
    });

    test('기준(seenType) 없으면 뒤늦은 연출 방지 — 연출 안 함', () {
      expect(
        PetTransitionEvents.shouldRevealAwakening(
          seenTypeName: null,
          pet: makePet(evolutionStage: 2, evolutionType: EvolutionType.gumiho),
        ),
        isFalse,
      );
    });

    test('종 미결정(null)이면 연출 안 함', () {
      expect(
        PetTransitionEvents.shouldRevealAwakening(
          seenTypeName: 'snake',
          pet: makePet(evolutionStage: 1),
        ),
        isFalse,
      );
    });

    test('죽은 펫은 연출 안 함', () {
      expect(
        PetTransitionEvents.shouldRevealAwakening(
          seenTypeName: 'snake',
          pet: makePet(
              evolutionStage: 2,
              evolutionType: EvolutionType.dokkaebi,
              isDead: true),
        ),
        isFalse,
      );
    });
  });
}
