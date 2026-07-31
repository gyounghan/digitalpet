import 'package:flutter_test/flutter_test.dart';
import 'package:pocketfriend/domain/entities/evolution_type.dart';
import 'package:pocketfriend/domain/entities/pet.dart';
import 'package:pocketfriend/domain/usecases/species_reveal_narrator.dart';

Pet _pet({
  EvolutionType? evolutionType,
  int totalSteps = 0,
  int totalExerciseMinutes = 0,
  int sleepAchievedCount = 0,
  int totalIdleHours = 0,
  int consecutiveLoginDays = 0,
  int feedAchievedCount = 0,
}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return Pet(
    id: 'test-pet',
    hunger: 80,
    happiness: 80,
    stamina: 80,
    level: 5,
    exp: 0,
    evolutionStage: 2,
    evolutionType: evolutionType,
    lastUpdated: now,
    lastStatusDecayUpdated: now,
    totalSteps: totalSteps,
    totalExerciseMinutes: totalExerciseMinutes,
    sleepAchievedCount: sleepAchievedCount,
    totalIdleHours: totalIdleHours,
    consecutiveLoginDays: consecutiveLoginDays,
    feedAchievedCount: feedAchievedCount,
  );
}

void main() {
  group('SpeciesRevealNarrator 헤드라인', () {
    test('종별 이름 + 올바른 목적격 조사 (백호를/주작을/청룡을/현무를)', () {
      expect(
        SpeciesRevealNarrator.narrate(_pet(evolutionType: EvolutionType.tiger))
            .title,
        contains('백호를 깨웠어요'),
      );
      expect(
        SpeciesRevealNarrator.narrate(_pet(evolutionType: EvolutionType.bird))
            .title,
        contains('주작을 깨웠어요'),
      );
      expect(
        SpeciesRevealNarrator.narrate(_pet(evolutionType: EvolutionType.snake))
            .title,
        contains('청룡을 깨웠어요'),
      );
      expect(
        SpeciesRevealNarrator.narrate(_pet(evolutionType: EvolutionType.turtle))
            .title,
        contains('현무를 깨웠어요'),
      );
    });

    test('evolutionType이 이미 결정돼 있으면 축 점수와 무관하게 그 종을 쓴다', () {
      // 데이터는 활발 우세지만 종은 청룡으로 확정된 상태
      final story = SpeciesRevealNarrator.narrate(
        _pet(evolutionType: EvolutionType.snake, totalSteps: 20000),
      );
      expect(story.type, EvolutionType.snake);
      expect(story.speciesLabel, '청룡');
    });

    test('evolutionType 미결정이면 축 점수로 판정한다', () {
      final story = SpeciesRevealNarrator.narrate(
        _pet(totalSteps: 8000, feedAchievedCount: 8),
      );
      expect(story.type, EvolutionType.bird);
    });
  });

  group('SpeciesRevealNarrator 판정 근거 (활발/차분 축)', () {
    test('활발 종 + 걸음 1000보 이상 → 실제 걸음 수를 콤마 표기로 언급', () {
      final story = SpeciesRevealNarrator.narrate(
        _pet(evolutionType: EvolutionType.tiger, totalSteps: 12400),
      );
      expect(story.reasonLines[0], contains('12,400보'));
    });

    test('활발 종 + 걸음 부족 → 수치 없는 성향 서술로 폴백 (거짓 수치 금지)', () {
      final story = SpeciesRevealNarrator.narrate(
        _pet(evolutionType: EvolutionType.bird, totalSteps: 300),
      );
      expect(story.reasonLines[0], contains('부지런히'));
      expect(story.reasonLines[0], isNot(contains('보가')));
    });

    test('차분 종 + 수면 달성 있음 → 잠든 밤 횟수 언급', () {
      final story = SpeciesRevealNarrator.narrate(
        _pet(evolutionType: EvolutionType.turtle, sleepAchievedCount: 7),
      );
      expect(story.reasonLines[0], contains('7번의 밤'));
    });

    test('차분 종 + 수면 달성 없음 → 성향 서술로 폴백', () {
      final story = SpeciesRevealNarrator.narrate(
        _pet(evolutionType: EvolutionType.snake),
      );
      expect(story.reasonLines[0], contains('느긋하게'));
    });
  });

  group('SpeciesRevealNarrator 판정 근거 (규칙/자유 축)', () {
    test('규칙 종 + 연속 접속 2일 이상 → 연속 일수 언급', () {
      final story = SpeciesRevealNarrator.narrate(
        _pet(evolutionType: EvolutionType.tiger, consecutiveLoginDays: 9),
      );
      expect(story.reasonLines[1], contains('9일 연속'));
    });

    test('규칙 종 + 연속 접속 1일 이하 → 성향 서술로 폴백', () {
      final story = SpeciesRevealNarrator.narrate(
        _pet(evolutionType: EvolutionType.turtle, consecutiveLoginDays: 1),
      );
      expect(story.reasonLines[1], contains('하루하루'));
    });

    test('자유 종 + 급식 달성 있음 → 식사 횟수 언급', () {
      final story = SpeciesRevealNarrator.narrate(
        _pet(evolutionType: EvolutionType.bird, feedAchievedCount: 5),
      );
      expect(story.reasonLines[1], contains('5번의 식사'));
    });

    test('자유 종 + 급식 달성 없음 → 성향 서술로 폴백', () {
      final story = SpeciesRevealNarrator.narrate(
        _pet(evolutionType: EvolutionType.snake),
      );
      expect(story.reasonLines[1], contains('자기만의 리듬'));
    });
  });

  group('SpeciesRevealNarrator 공통 규칙', () {
    test('근거는 항상 2줄이다', () {
      for (final type in EvolutionType.values) {
        final story =
            SpeciesRevealNarrator.narrate(_pet(evolutionType: type));
        expect(story.reasonLines.length, 2, reason: '$type');
      }
    });

    test('종 성격 문구는 종마다 다르고 비어 있지 않다', () {
      final personalities = EvolutionType.values
          .map((type) =>
              SpeciesRevealNarrator.narrate(_pet(evolutionType: type))
                  .personality)
          .toSet();
      expect(personalities.length, EvolutionType.values.length);
      expect(personalities.every((p) => p.isNotEmpty), true);
    });
  });

  group('objectParticle (을/를)', () {
    test('받침 있으면 을, 없으면 를', () {
      expect(SpeciesRevealNarrator.objectParticle('주작'), '을');
      expect(SpeciesRevealNarrator.objectParticle('청룡'), '을');
      expect(SpeciesRevealNarrator.objectParticle('백호'), '를');
      expect(SpeciesRevealNarrator.objectParticle('현무'), '를');
    });

    test('빈 문자열·비한글은 를로 폴백', () {
      expect(SpeciesRevealNarrator.objectParticle(''), '를');
      expect(SpeciesRevealNarrator.objectParticle('abc'), '를');
    });
  });

  group('formatNumber (천 단위 콤마)', () {
    test('구간별 표기', () {
      expect(SpeciesRevealNarrator.formatNumber(0), '0');
      expect(SpeciesRevealNarrator.formatNumber(999), '999');
      expect(SpeciesRevealNarrator.formatNumber(1000), '1,000');
      expect(SpeciesRevealNarrator.formatNumber(12400), '12,400');
      expect(SpeciesRevealNarrator.formatNumber(1234567), '1,234,567');
    });

    test('음수도 콤마 유지', () {
      expect(SpeciesRevealNarrator.formatNumber(-1234), '-1,234');
    });
  });
}
