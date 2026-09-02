import 'package:flutter_test/flutter_test.dart';
import 'package:pocketfriend/domain/entities/evolution_type.dart';
import 'package:pocketfriend/domain/entities/pet.dart';
import 'package:pocketfriend/domain/repositories/pet_repository.dart';
import 'package:pocketfriend/domain/usecases/evolution_axis_scores.dart';
import 'package:pocketfriend/domain/usecases/evolve_pet_usecase.dart';

/// 간단한 Mock PetRepository (진화 파리티 테스트용)
class MockPetRepository implements PetRepository {
  Pet? _pet;

  void setPet(Pet pet) => _pet = pet;

  @override
  Future<Pet> getPet(String id) async => _pet!;

  @override
  Future<void> updatePet(Pet pet) async => _pet = pet;

  @override
  Future<void> savePet(Pet pet) async => _pet = pet;

  @override
  Future<bool> hasPet(String id) async => _pet != null;

  @override
  Future<List<Pet>> getAllPets() async => _pet != null ? [_pet!] : [];
}

Pet _pet({
  int totalSteps = 0,
  int totalExerciseMinutes = 0,
  int sleepAchievedCount = 0,
  int exerciseAchievedCount = 0,
  int totalIdleHours = 0,
  int consecutiveLoginDays = 0,
  int feedAchievedCount = 0,
  int waterAchievedCount = 0,
  int focusAchievedCount = 0,
  int battleVictoryCount = 0,
  int level = 5,
  int evolutionStage = 1,
}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return Pet(
    id: 'test-pet',
    hunger: 80,
    happiness: 80,
    stamina: 80,
    level: level,
    exp: 0,
    evolutionStage: evolutionStage,
    lastUpdated: now,
    lastStatusDecayUpdated: now,
    totalSteps: totalSteps,
    totalExerciseMinutes: totalExerciseMinutes,
    sleepAchievedCount: sleepAchievedCount,
    exerciseAchievedCount: exerciseAchievedCount,
    totalIdleHours: totalIdleHours,
    consecutiveLoginDays: consecutiveLoginDays,
    feedAchievedCount: feedAchievedCount,
    waterAchievedCount: waterAchievedCount,
    focusAchievedCount: focusAchievedCount,
    battleVictoryCount: battleVictoryCount,
  );
}

void main() {
  group('EvolutionAxisScores 점수 공식', () {
    test('moveScore = 걸음/2000 + 운동분/10', () {
      final scores =
          EvolutionAxisScores.fromPet(_pet(totalSteps: 4000, totalExerciseMinutes: 50));
      expect(scores.moveScore, 7.0); // 2.0 + 5.0 (미션 보너스 0)
    });

    test('restScore = 수면 달성 횟수 + 휴식시간/6', () {
      final scores =
          EvolutionAxisScores.fromPet(_pet(sleepAchievedCount: 3, totalIdleHours: 12));
      expect(scores.restScore, 5.0); // 3.0 + 2.0
    });

    test('regularScore/freeScore = 연속 접속일 / 급식 달성 횟수', () {
      final scores = EvolutionAxisScores.fromPet(
          _pet(consecutiveLoginDays: 6, feedAchievedCount: 4));
      expect(scores.regularScore, 6.0);
      expect(scores.freeScore, 4.0);
    });

    test('완료한 미션의 축 가중치가 점수에 더해진다', () {
      // 누적 5만 보 → '산책 매니아' 미션 완료 → 활발 축 보너스
      final scores = EvolutionAxisScores.fromPet(_pet(totalSteps: 50000));
      expect(scores.moveScore, greaterThan(25.0)); // 원점수 25 + 보너스
    });
  });

  group('EvolutionAxisScores 사분면 판정', () {
    test('활발 + 규칙 → 백호(tiger)', () {
      final scores = EvolutionAxisScores.fromPet(_pet(
        totalSteps: 8000, // move 4.0
        sleepAchievedCount: 1, // rest 1.0
        consecutiveLoginDays: 5,
        feedAchievedCount: 2,
      ));
      expect(scores.isActive, true);
      expect(scores.isRegular, true);
      expect(scores.resultType, EvolutionType.tiger);
    });

    test('활발 + 자유 → 주작(bird)', () {
      final scores = EvolutionAxisScores.fromPet(_pet(
        totalSteps: 8000,
        sleepAchievedCount: 1,
        consecutiveLoginDays: 2,
        feedAchievedCount: 8,
      ));
      expect(scores.resultType, EvolutionType.bird);
    });

    test('차분 + 규칙 → 현무(turtle)', () {
      final scores = EvolutionAxisScores.fromPet(_pet(
        totalSteps: 1000, // move 0.5
        sleepAchievedCount: 6, // rest 6.0
        consecutiveLoginDays: 6,
        feedAchievedCount: 1,
      ));
      expect(scores.resultType, EvolutionType.turtle);
    });

    test('차분 + 자유 → 청룡(snake)', () {
      final scores = EvolutionAxisScores.fromPet(_pet(
        totalSteps: 2000, // move 1.0
        sleepAchievedCount: 6,
        totalIdleHours: 12, // rest 8.0
        consecutiveLoginDays: 3,
        feedAchievedCount: 9,
      ));
      expect(scores.resultType, EvolutionType.snake);
    });

    test('동점이면 활발·규칙이 이긴다 (데이터 전무 → 백호)', () {
      final scores = EvolutionAxisScores.fromPet(_pet());
      expect(scores.isActive, true);
      expect(scores.isRegular, true);
      expect(scores.resultType, EvolutionType.tiger);
    });
  });

  group('EvolvePetUseCase 종 판정 파리티', () {
    test('실제 2단계 진화 결과가 EvolutionAxisScores.resultType과 일치한다', () async {
      final pet = _pet(
        totalSteps: 8000,
        consecutiveLoginDays: 2,
        feedAchievedCount: 8,
      );
      final repository = MockPetRepository()..setPet(pet);
      final useCase = EvolvePetUseCase(repository);

      final evolved = await useCase('test-pet');

      expect(evolved.evolutionStage, 2);
      expect(evolved.evolutionType, EvolutionAxisScores.fromPet(pet).resultType);
      expect(evolved.evolutionType, EvolutionType.bird);
    });
  });

  group('hiddenTypeFor 동물 영물(2차 추가) 각성', () {
    test('물마시기 7회 몰빵 → 수달', () {
      expect(
        EvolutionAxisScores.hiddenTypeFor(_pet(waterAchievedCount: 7)),
        EvolutionType.otter,
      );
    });

    test('집중 7회 몰빵 → 부엉이', () {
      expect(
        EvolutionAxisScores.hiddenTypeFor(_pet(focusAchievedCount: 7)),
        EvolutionType.owl,
      );
    });

    test('물·집중 각 5회 균형 → 두루미 (단일 몰빵보다 우선)', () {
      expect(
        EvolutionAxisScores.hiddenTypeFor(
            _pet(waterAchievedCount: 8, focusAchievedCount: 6)),
        EvolutionType.crane,
      );
    });

    test('idle 100시간 + 다른 특화 없음 → 곰', () {
      expect(
        EvolutionAxisScores.hiddenTypeFor(_pet(totalIdleHours: 100)),
        EvolutionType.bear,
      );
    });

    test('곰(idle)은 최저 우선순위 — 걸음 몰빵이 있으면 삼족오', () {
      expect(
        EvolutionAxisScores.hiddenTypeFor(
            _pet(exerciseAchievedCount: 9, totalIdleHours: 200)),
        EvolutionType.samjoko,
      );
    });

    test('물·집중·idle 모두 미달이면 각성 없음(null → 사신수)', () {
      expect(
        EvolutionAxisScores.hiddenTypeFor(
            _pet(waterAchievedCount: 4, focusAchievedCount: 4, totalIdleHours: 50)),
        isNull,
      );
    });
  });
}
