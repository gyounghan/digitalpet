import 'package:flutter_test/flutter_test.dart';
import 'package:pocketfriend/domain/entities/pet.dart';
import 'package:pocketfriend/domain/entities/evolution_type.dart';
import 'package:pocketfriend/domain/repositories/pet_repository.dart';
import 'package:pocketfriend/domain/usecases/evolve_pet_usecase.dart';

/// 간단한 Mock PetRepository
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

  Future<void> deletePet(String id) async => _pet = null;

  Future<List<Pet>> getAllPets() async => _pet != null ? [_pet!] : [];
}

Pet _createPet({
  int level = 1,
  int evolutionStage = 1,
  EvolutionType? evolutionType,
  String evolutionGrade = '',
  int totalSteps = 0,
  int totalExerciseMinutes = 0,
  int totalIdleHours = 0,
  int goalStreakCount = 0,
  int consecutiveLoginDays = 0,
  int battleVictoryCount = 0,
  int hunger = 80,
  int happiness = 80,
  int stamina = 80,
  int resurrectCount = 0,
  bool isDead = false,
  int sleepAchievedCount = 0,
  int feedAchievedCount = 0,
  int todayAlternativeFeedCount = 0,
}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return Pet(
    id: 'test-pet',
    hunger: hunger,
    happiness: happiness,
    stamina: stamina,
    level: level,
    exp: 0,
    evolutionStage: evolutionStage,
    lastUpdated: now,
    lastStatusDecayUpdated: now,
    evolutionType: evolutionType,
    evolutionGrade: evolutionGrade,
    totalSteps: totalSteps,
    totalExerciseMinutes: totalExerciseMinutes,
    totalIdleHours: totalIdleHours,
    goalStreakCount: goalStreakCount,
    consecutiveLoginDays: consecutiveLoginDays,
    battleVictoryCount: battleVictoryCount,
    resurrectCount: resurrectCount,
    isDead: isDead,
    sleepAchievedCount: sleepAchievedCount,
    feedAchievedCount: feedAchievedCount,
    todayAlternativeFeedCount: todayAlternativeFeedCount,
  );
}

void main() {
  late EvolvePetUseCase useCase;
  late MockPetRepository repository;

  setUp(() {
    repository = MockPetRepository();
    useCase = EvolvePetUseCase(repository);
  });

  group('EvolvePetUseCase - Stage 2 종 결정', () {
    test('Lv5 미만이면 진화하지 않음', () async {
      final pet = _createPet(level: 4, evolutionStage: 1);
      repository.setPet(pet);

      final result = await useCase('test-pet');
      expect(result.evolutionStage, 1);
      expect(result.evolutionType, isNull);
    });

    // 새 공식: 활발↔차분 = 움직임(걸음·운동) vs 휴식(수면·idle)
    //          규칙↔자유 = 규칙생활(수면·연속접속) vs 자유식사(포만감·간편급식)

    test('Lv5 + 활발(많이 걸음) + 규칙(연속접속) → tiger', () async {
      final pet = _createPet(
        level: 5,
        evolutionStage: 1,
        totalSteps: 50000, // move = 25
        consecutiveLoginDays: 10, // regular = 5 > free 0
        feedAchievedCount: 0,
      );
      repository.setPet(pet);

      final result = await useCase('test-pet');
      expect(result.evolutionStage, 2);
      expect(result.evolutionType, EvolutionType.tiger);
    });

    test('Lv5 + 활발(많이 걸음) + 자유(자주 먹음) → bird', () async {
      final pet = _createPet(
        level: 5,
        evolutionStage: 1,
        totalSteps: 50000, // move = 25, rest 0 → active
        consecutiveLoginDays: 0,
        feedAchievedCount: 10, // free 10 > regular 0
      );
      repository.setPet(pet);

      final result = await useCase('test-pet');
      expect(result.evolutionStage, 2);
      expect(result.evolutionType, EvolutionType.bird);
    });

    test('Lv5 + 차분(잘 쉼) + 규칙(연속접속) → turtle', () async {
      final pet = _createPet(
        level: 5,
        evolutionStage: 1,
        totalSteps: 0, // move 0
        totalIdleHours: 30, // rest = 5 + sleep 2 = 7 → calm
        sleepAchievedCount: 2,
        consecutiveLoginDays: 10, // regular = 2 + 5 = 7 > free 0
        feedAchievedCount: 0,
      );
      repository.setPet(pet);

      final result = await useCase('test-pet');
      expect(result.evolutionStage, 2);
      expect(result.evolutionType, EvolutionType.turtle);
    });

    test('Lv5 + 차분(잘 쉼) + 자유(자주 먹음) → snake', () async {
      final pet = _createPet(
        level: 5,
        evolutionStage: 1,
        totalSteps: 0, // move 0
        totalIdleHours: 30, // rest = 5 → calm
        sleepAchievedCount: 0,
        consecutiveLoginDays: 0, // regular 0
        feedAchievedCount: 10, // free 10 → 자유
      );
      repository.setPet(pet);

      final result = await useCase('test-pet');
      expect(result.evolutionStage, 2);
      expect(result.evolutionType, EvolutionType.snake);
    });

    test('운동시간만으로도 활발 판정 → bird', () async {
      final pet = _createPet(
        level: 5,
        evolutionStage: 1,
        totalSteps: 0,
        totalExerciseMinutes: 100, // move = 10, rest 0 → active
        consecutiveLoginDays: 0,
        feedAchievedCount: 5, // free > regular → 자유
      );
      repository.setPet(pet);

      final result = await useCase('test-pet');
      expect(result.evolutionStage, 2);
      expect(result.evolutionType, EvolutionType.bird);
    });

    test('4종 모두 도달 가능 (쏠림 없음)', () async {
      final types = <EvolutionType>{};
      final profiles = [
        // tiger: 활발+규칙
        _createPet(
            level: 5,
            totalSteps: 40000,
            consecutiveLoginDays: 8,
            feedAchievedCount: 0),
        // bird: 활발+자유
        _createPet(level: 5, totalSteps: 40000, feedAchievedCount: 12),
        // turtle: 차분+규칙
        _createPet(
            level: 5,
            totalIdleHours: 36,
            sleepAchievedCount: 3,
            consecutiveLoginDays: 12,
            feedAchievedCount: 0),
        // snake: 차분+자유
        _createPet(
            level: 5, totalIdleHours: 36, feedAchievedCount: 12),
      ];
      for (final p in profiles) {
        repository.setPet(p);
        final r = await useCase('test-pet');
        types.add(r.evolutionType!);
      }
      expect(types, {
        EvolutionType.tiger,
        EvolutionType.bird,
        EvolutionType.turtle,
        EvolutionType.snake,
      });
    });
  });

  group('EvolvePetUseCase - Stage 3 등급 결정', () {
    test('Lv10 미만이면 3단계 진화 안됨', () async {
      final pet = _createPet(
        level: 9,
        evolutionStage: 2,
        evolutionType: EvolutionType.bird,
      );
      repository.setPet(pet);

      final result = await useCase('test-pet');
      expect(result.evolutionStage, 2);
    });

    test('bird + battleVictoryCount>=15 + happiness>=70 → superior', () async {
      final pet = _createPet(
        level: 10,
        evolutionStage: 2,
        evolutionType: EvolutionType.bird,
        battleVictoryCount: 15,
        happiness: 70,
      );
      repository.setPet(pet);

      final result = await useCase('test-pet');
      expect(result.evolutionStage, 3);
      expect(result.evolutionGrade, 'superior');
    });

    test('bird + battleVictoryCount<15 → normal', () async {
      final pet = _createPet(
        level: 10,
        evolutionStage: 2,
        evolutionType: EvolutionType.bird,
        battleVictoryCount: 10,
        happiness: 90,
      );
      repository.setPet(pet);

      final result = await useCase('test-pet');
      expect(result.evolutionStage, 3);
      expect(result.evolutionGrade, 'normal');
    });

    test('snake + feedAchieved>=20 + loginDays>=30 → superior', () async {
      final pet = _createPet(
        level: 10,
        evolutionStage: 2,
        evolutionType: EvolutionType.snake,
        feedAchievedCount: 20,
        consecutiveLoginDays: 30,
      );
      repository.setPet(pet);

      final result = await useCase('test-pet');
      expect(result.evolutionStage, 3);
      expect(result.evolutionGrade, 'superior');
    });

    test('snake + 조건 미충족 → normal', () async {
      final pet = _createPet(
        level: 10,
        evolutionStage: 2,
        evolutionType: EvolutionType.snake,
        feedAchievedCount: 10,
        consecutiveLoginDays: 10,
      );
      repository.setPet(pet);

      final result = await useCase('test-pet');
      expect(result.evolutionStage, 3);
      expect(result.evolutionGrade, 'normal');
    });

    test('tiger + battleVictoryCount>=15 + totalStats>=180 → superior', () async {
      final pet = _createPet(
        level: 10,
        evolutionStage: 2,
        evolutionType: EvolutionType.tiger,
        battleVictoryCount: 15,
        hunger: 60,
        happiness: 60,
        stamina: 60, // 60+60+60=180
      );
      repository.setPet(pet);

      final result = await useCase('test-pet');
      expect(result.evolutionStage, 3);
      expect(result.evolutionGrade, 'superior');
    });

    test('tiger + totalStats<180 → normal', () async {
      final pet = _createPet(
        level: 10,
        evolutionStage: 2,
        evolutionType: EvolutionType.tiger,
        battleVictoryCount: 20,
        hunger: 50,
        happiness: 50,
        stamina: 50, // 150 < 180
      );
      repository.setPet(pet);

      final result = await useCase('test-pet');
      expect(result.evolutionStage, 3);
      expect(result.evolutionGrade, 'normal');
    });

    test('turtle + loginDays>=14 + sleepAchieved>=20 → superior', () async {
      final pet = _createPet(
        level: 10,
        evolutionStage: 2,
        evolutionType: EvolutionType.turtle,
        consecutiveLoginDays: 14,
        sleepAchievedCount: 20,
      );
      repository.setPet(pet);

      final result = await useCase('test-pet');
      expect(result.evolutionStage, 3);
      expect(result.evolutionGrade, 'superior');
    });

    test('turtle + sleepAchieved<20 → normal', () async {
      final pet = _createPet(
        level: 10,
        evolutionStage: 2,
        evolutionType: EvolutionType.turtle,
        consecutiveLoginDays: 20,
        sleepAchievedCount: 10,
      );
      repository.setPet(pet);

      final result = await useCase('test-pet');
      expect(result.evolutionStage, 3);
      expect(result.evolutionGrade, 'normal');
    });
  });

  group('EvolvePetUseCase - Stage 4 mythical 승격', () {
    test('normal 등급은 4단계 승격 불가', () async {
      final pet = _createPet(
        level: 15,
        evolutionStage: 3,
        evolutionType: EvolutionType.bird,
        evolutionGrade: 'normal',
        totalSteps: 500000,
        battleVictoryCount: 50,
      );
      repository.setPet(pet);

      final result = await useCase('test-pet');
      expect(result.evolutionStage, 3);
      expect(result.evolutionGrade, 'normal');
    });

    test('bird superior + steps>=300000 + victories>=30 → mythical', () async {
      final pet = _createPet(
        level: 15,
        evolutionStage: 3,
        evolutionType: EvolutionType.bird,
        evolutionGrade: 'superior',
        totalSteps: 300000,
        battleVictoryCount: 30,
      );
      repository.setPet(pet);

      final result = await useCase('test-pet');
      expect(result.evolutionStage, 4);
      expect(result.evolutionGrade, 'mythical');
    });

    test('bird superior + 조건 미충족 → 그대로 유지', () async {
      final pet = _createPet(
        level: 15,
        evolutionStage: 3,
        evolutionType: EvolutionType.bird,
        evolutionGrade: 'superior',
        totalSteps: 200000, // < 300000
        battleVictoryCount: 30,
      );
      repository.setPet(pet);

      final result = await useCase('test-pet');
      expect(result.evolutionStage, 3);
      expect(result.evolutionGrade, 'superior');
    });

    test('snake superior + loginDays>=60 + feedAchieved>=50 + resurrect==0 → mythical', () async {
      final pet = _createPet(
        level: 15,
        evolutionStage: 3,
        evolutionType: EvolutionType.snake,
        evolutionGrade: 'superior',
        consecutiveLoginDays: 60,
        feedAchievedCount: 50,
        resurrectCount: 0,
      );
      repository.setPet(pet);

      final result = await useCase('test-pet');
      expect(result.evolutionStage, 4);
      expect(result.evolutionGrade, 'mythical');
    });

    test('snake superior + resurrectCount>0 → 승격 불가', () async {
      final pet = _createPet(
        level: 15,
        evolutionStage: 3,
        evolutionType: EvolutionType.snake,
        evolutionGrade: 'superior',
        consecutiveLoginDays: 60,
        feedAchievedCount: 50,
        resurrectCount: 1, // 부활 이력 있음
      );
      repository.setPet(pet);

      final result = await useCase('test-pet');
      expect(result.evolutionStage, 3);
    });

    test('tiger superior + victories>=50 + totalStats>=210 → mythical', () async {
      final pet = _createPet(
        level: 15,
        evolutionStage: 3,
        evolutionType: EvolutionType.tiger,
        evolutionGrade: 'superior',
        battleVictoryCount: 50,
        hunger: 70,
        happiness: 70,
        stamina: 70, // 210
      );
      repository.setPet(pet);

      final result = await useCase('test-pet');
      expect(result.evolutionStage, 4);
      expect(result.evolutionGrade, 'mythical');
    });

    test('turtle superior + loginDays>=30 + sleepAchieved>=50 + resurrect==0 → mythical', () async {
      final pet = _createPet(
        level: 15,
        evolutionStage: 3,
        evolutionType: EvolutionType.turtle,
        evolutionGrade: 'superior',
        consecutiveLoginDays: 30,
        sleepAchievedCount: 50,
        resurrectCount: 0,
      );
      repository.setPet(pet);

      final result = await useCase('test-pet');
      expect(result.evolutionStage, 4);
      expect(result.evolutionGrade, 'mythical');
    });
  });

  group('EvolvePetUseCase - canEvolve', () {
    test('사망한 펫은 진화 불가', () {
      final pet = _createPet(level: 5, evolutionStage: 1, isDead: true);
      expect(useCase.canEvolve(pet), false);
    });

    test('Lv5 + stage1 → 진화 가능', () {
      final pet = _createPet(level: 5, evolutionStage: 1);
      expect(useCase.canEvolve(pet), true);
    });

    test('Lv10 + stage2 → 진화 가능 (3단계는 항상 가능)', () {
      final pet = _createPet(
        level: 10,
        evolutionStage: 2,
        evolutionType: EvolutionType.bird,
      );
      expect(useCase.canEvolve(pet), true);
    });

    test('Lv15 + stage3 + normal → 4단계 진화 불가', () {
      final pet = _createPet(
        level: 15,
        evolutionStage: 3,
        evolutionType: EvolutionType.bird,
        evolutionGrade: 'normal',
      );
      expect(useCase.canEvolve(pet), false);
    });

    test('Lv15 + stage3 + superior + 조건 충족 → 4단계 진화 가능', () {
      final pet = _createPet(
        level: 15,
        evolutionStage: 3,
        evolutionType: EvolutionType.bird,
        evolutionGrade: 'superior',
        totalSteps: 300000,
        battleVictoryCount: 30,
      );
      expect(useCase.canEvolve(pet), true);
    });

    test('이미 4단계면 진화 불가', () {
      final pet = _createPet(
        level: 20,
        evolutionStage: 4,
        evolutionType: EvolutionType.bird,
        evolutionGrade: 'mythical',
      );
      expect(useCase.canEvolve(pet), false);
    });
  });

  group('EvolvePetUseCase - 엣지 케이스', () {
    test('사망한 펫은 진화하지 않음', () async {
      final pet = _createPet(level: 10, evolutionStage: 1, isDead: true);
      repository.setPet(pet);

      final result = await useCase('test-pet');
      expect(result.evolutionStage, 1);
      expect(result.isDead, true);
    });

    test('이미 최종 단계(4)면 변경 없음', () async {
      final pet = _createPet(
        level: 20,
        evolutionStage: 4,
        evolutionType: EvolutionType.tiger,
        evolutionGrade: 'mythical',
      );
      repository.setPet(pet);

      final result = await useCase('test-pet');
      expect(result.evolutionStage, 4);
      expect(result.evolutionGrade, 'mythical');
    });

    test('걸음+운동 조합으로 활발 판정 (자유 식사 → bird)', () async {
      // moveScore = 20000/2000 + 50/10 = 15 > restScore 0 → 활발
      // freeScore = feedAchieved 3 > regularScore 0 → 자유
      final pet = _createPet(
        level: 5,
        evolutionStage: 1,
        totalSteps: 20000,
        totalExerciseMinutes: 50,
        feedAchievedCount: 3,
        consecutiveLoginDays: 0,
      );
      repository.setPet(pet);

      final result = await useCase('test-pet');
      expect(result.evolutionStage, 2);
      expect(result.evolutionType, EvolutionType.bird); // 활발 + 자유
    });

    test('수면+idle 조합으로 차분 판정 (연속접속 → turtle)', () async {
      // restScore = sleepAchieved 2 + 12/6 = 4 > moveScore 0 → 차분
      // regularScore = 2 + 3/2 = 3.5 > freeScore 0 → 규칙
      final pet = _createPet(
        level: 5,
        evolutionStage: 1,
        totalSteps: 0,
        totalExerciseMinutes: 0,
        sleepAchievedCount: 2,
        totalIdleHours: 12,
        consecutiveLoginDays: 3,
      );
      repository.setPet(pet);

      final result = await useCase('test-pet');
      expect(result.evolutionStage, 2);
      expect(result.evolutionType, EvolutionType.turtle); // 차분 + 규칙
    });
  });
}
