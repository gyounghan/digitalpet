import 'package:flutter_test/flutter_test.dart';
import 'package:pocketfriend/domain/entities/pet.dart';
import 'package:pocketfriend/domain/entities/evolution_type.dart';
import 'package:pocketfriend/domain/repositories/pet_repository.dart';
import 'package:pocketfriend/domain/usecases/evolve_pet_usecase.dart';
import 'package:pocketfriend/domain/entities/mission.dart';
import 'package:pocketfriend/domain/constants/mission_catalog.dart';

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
  int exerciseAchievedCount = 0,
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
    exerciseAchievedCount: exerciseAchievedCount,
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
        totalSteps: 20000, // move = 10 (히든 임계 4만 미만)
        consecutiveLoginDays: 6, // regular 6 > free 0 (해태 임계 7 미만)
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
        totalSteps: 20000, // move = 10, rest 0 → active (히든 임계 미만)
        consecutiveLoginDays: 0,
        feedAchievedCount: 8, // free 8 > regular 0 (구미호 임계 9 미만)
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
        consecutiveLoginDays: 6, // regular = 2 + 5 > free 0 (해태 임계 미만)
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
        feedAchievedCount: 8, // free 8 → 자유 (구미호 임계 9 미만)
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
        // tiger: 활발+규칙 (수치는 전부 히든 각성 임계 미만)
        _createPet(
            level: 5,
            totalSteps: 24000,
            consecutiveLoginDays: 6,
            feedAchievedCount: 0),
        // bird: 활발+자유
        _createPet(level: 5, totalSteps: 24000, feedAchievedCount: 8),
        // turtle: 차분+규칙
        _createPet(
            level: 5,
            totalIdleHours: 36,
            sleepAchievedCount: 3,
            consecutiveLoginDays: 6,
            feedAchievedCount: 0),
        // snake: 차분+자유
        _createPet(
            level: 5, totalIdleHours: 36, feedAchievedCount: 8),
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

  group('EvolvePetUseCase - 설화 영물(히든 종) 각성', () {
    test('걸음 목표 9회 달성 + 걸음 축 지배 → 삼족오 각성', () async {
      repository.setPet(_createPet(level: 5, exerciseAchievedCount: 9));
      final r = await useCase('test-pet');
      expect(r.evolutionType, EvolutionType.samjoko);
    });

    test('세 축이 함께 오르면(세트 클리어) 지배 불성립 → 사신수로', () async {
      repository.setPet(_createPet(
        level: 5,
        exerciseAchievedCount: 10, // 임계는 넘지만
        feedAchievedCount: 8, // 다른 축의 2배가 아님 → 지배 실패
        sleepAchievedCount: 7,
        consecutiveLoginDays: 4,
      ));
      final r = await useCase('test-pet');
      expect(r.evolutionType!.isHiddenSpecies, isFalse);
    });

    test('급식 달성 9회 이상 → 구미호 각성', () async {
      repository.setPet(_createPet(level: 5, feedAchievedCount: 9));
      final r = await useCase('test-pet');
      expect(r.evolutionType, EvolutionType.gumiho);
    });

    test('수면 달성 8회 이상 → 달토끼 각성', () async {
      repository.setPet(_createPet(level: 5, sleepAchievedCount: 8));
      final r = await useCase('test-pet');
      expect(r.evolutionType, EvolutionType.moonrabbit);
    });

    test('연속 접속 7일 이상 → 해태 각성', () async {
      repository.setPet(_createPet(level: 5, consecutiveLoginDays: 7));
      final r = await useCase('test-pet');
      expect(r.evolutionType, EvolutionType.haetae);
    });

    test('배틀 12승 이상 → 도깨비 각성', () async {
      repository.setPet(_createPet(level: 5, battleVictoryCount: 12));
      final r = await useCase('test-pet');
      expect(r.evolutionType, EvolutionType.dokkaebi);
    });

    test('네 지표 모두 6 이상 → 황룡 각성', () async {
      repository.setPet(_createPet(
        level: 5,
        feedAchievedCount: 6,
        sleepAchievedCount: 6,
        exerciseAchievedCount: 6,
        consecutiveLoginDays: 6,
      ));
      final r = await useCase('test-pet');
      expect(r.evolutionType, EvolutionType.hwangryong);
    });

    test('황룡은 다른 히든 조건보다 우선한다 (4축 동시가 최고 난도)', () async {
      repository.setPet(_createPet(
        level: 5,
        feedAchievedCount: 20, // 구미호 지배 조건도 충족하지만
        sleepAchievedCount: 9,
        exerciseAchievedCount: 6,
        consecutiveLoginDays: 7, // 네 축 모두 6 이상 → 황룡 우선
      ));
      final r = await useCase('test-pet');
      expect(r.evolutionType, EvolutionType.hwangryong);
    });

    test('도깨비 성장 라인 — 배틀 승수로 superior/mythical', () async {
      repository.setPet(_createPet(
        level: 10,
        evolutionStage: 2,
        evolutionType: EvolutionType.dokkaebi,
        battleVictoryCount: 15,
      ));
      final s3 = await useCase('test-pet');
      expect(s3.evolutionGrade, 'superior');

      repository.setPet(_createPet(
        level: 15,
        evolutionStage: 3,
        evolutionGrade: 'superior',
        evolutionType: EvolutionType.dokkaebi,
        battleVictoryCount: 30,
      ));
      final s4 = await useCase('test-pet');
      expect(s4.evolutionStage, 4);
      expect(s4.evolutionGrade, 'mythical');
    });

    test('동시 충족 시 우선순위 — 삼족오 > 해태', () async {
      repository.setPet(_createPet(
          level: 5, exerciseAchievedCount: 9, consecutiveLoginDays: 10));
      final r = await useCase('test-pet');
      expect(r.evolutionType, EvolutionType.samjoko);
    });

    test('임계 미만이면 사신수 4분면으로', () async {
      repository.setPet(_createPet(
          level: 5,
          totalSteps: 20000,
          exerciseAchievedCount: 8, // 삼족오 임계 9 미만
          consecutiveLoginDays: 6)); // 해태 임계 7 미만
      final r = await useCase('test-pet');
      expect(r.evolutionType, EvolutionType.tiger);
    });

    test('히든 종 성장 라인 — 단일 축으로 superior/mythical 도달', () async {
      // Lv10 구미호 + 급식 8 → superior
      repository.setPet(_createPet(
        level: 10,
        evolutionStage: 2,
        evolutionType: EvolutionType.gumiho,
        feedAchievedCount: 8,
      ));
      final s3 = await useCase('test-pet');
      expect(s3.evolutionStage, 3);
      expect(s3.evolutionGrade, 'superior');

      // Lv15 + 급식 20 → mythical (구미호 완전체)
      repository.setPet(_createPet(
        level: 15,
        evolutionStage: 3,
        evolutionGrade: 'superior',
        evolutionType: EvolutionType.gumiho,
        feedAchievedCount: 20,
      ));
      final s4 = await useCase('test-pet');
      expect(s4.evolutionStage, 4);
      expect(s4.evolutionGrade, 'mythical');
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

    // 종 대칭: 각 종을 정의한 두 축(활발/차분 × 규칙/자유)을 동일 임계값으로 요구
    // superior 임계값: 활발/차분/자유 8, 규칙(연속접속) 7 (Lv10≈7일 페이싱 정렬)

    test('bird + 운동8 + 급식8 → superior', () async {
      final pet = _createPet(
        level: 10,
        evolutionStage: 2,
        evolutionType: EvolutionType.bird,
        exerciseAchievedCount: 8,
        feedAchievedCount: 8,
      );
      repository.setPet(pet);

      final result = await useCase('test-pet');
      expect(result.evolutionStage, 3);
      expect(result.evolutionGrade, 'superior');
    });

    test('bird + 급식만 충족(운동 부족) → normal', () async {
      final pet = _createPet(
        level: 10,
        evolutionStage: 2,
        evolutionType: EvolutionType.bird,
        exerciseAchievedCount: 5,
        feedAchievedCount: 30,
      );
      repository.setPet(pet);

      final result = await useCase('test-pet');
      expect(result.evolutionStage, 3);
      expect(result.evolutionGrade, 'normal');
    });

    test('snake + 수면8 + 급식8 → superior', () async {
      final pet = _createPet(
        level: 10,
        evolutionStage: 2,
        evolutionType: EvolutionType.snake,
        sleepAchievedCount: 8,
        feedAchievedCount: 8,
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
        sleepAchievedCount: 5,
        feedAchievedCount: 5,
      );
      repository.setPet(pet);

      final result = await useCase('test-pet');
      expect(result.evolutionStage, 3);
      expect(result.evolutionGrade, 'normal');
    });

    test('tiger + 운동8 + 연속접속7 → superior', () async {
      final pet = _createPet(
        level: 10,
        evolutionStage: 2,
        evolutionType: EvolutionType.tiger,
        exerciseAchievedCount: 8,
        consecutiveLoginDays: 7,
      );
      repository.setPet(pet);

      final result = await useCase('test-pet');
      expect(result.evolutionStage, 3);
      expect(result.evolutionGrade, 'superior');
    });

    test('tiger + 연속접속 부족 → normal', () async {
      final pet = _createPet(
        level: 10,
        evolutionStage: 2,
        evolutionType: EvolutionType.tiger,
        exerciseAchievedCount: 20,
        consecutiveLoginDays: 5,
      );
      repository.setPet(pet);

      final result = await useCase('test-pet');
      expect(result.evolutionStage, 3);
      expect(result.evolutionGrade, 'normal');
    });

    test('turtle + 수면8 + 연속접속7 → superior', () async {
      final pet = _createPet(
        level: 10,
        evolutionStage: 2,
        evolutionType: EvolutionType.turtle,
        consecutiveLoginDays: 7,
        sleepAchievedCount: 8,
      );
      repository.setPet(pet);

      final result = await useCase('test-pet');
      expect(result.evolutionStage, 3);
      expect(result.evolutionGrade, 'superior');
    });

    test('turtle + 수면 부족 → normal', () async {
      final pet = _createPet(
        level: 10,
        evolutionStage: 2,
        evolutionType: EvolutionType.turtle,
        consecutiveLoginDays: 20,
        sleepAchievedCount: 5,
      );
      repository.setPet(pet);

      final result = await useCase('test-pet');
      expect(result.evolutionStage, 3);
      expect(result.evolutionGrade, 'normal');
    });

    test('4종 모두 superior 도달 경로가 대칭적으로 존재한다', () async {
      final profiles = {
        EvolutionType.bird: _createPet(
            level: 10,
            evolutionStage: 2,
            evolutionType: EvolutionType.bird,
            exerciseAchievedCount: 8,
            feedAchievedCount: 8),
        EvolutionType.snake: _createPet(
            level: 10,
            evolutionStage: 2,
            evolutionType: EvolutionType.snake,
            sleepAchievedCount: 8,
            feedAchievedCount: 8),
        EvolutionType.tiger: _createPet(
            level: 10,
            evolutionStage: 2,
            evolutionType: EvolutionType.tiger,
            exerciseAchievedCount: 8,
            consecutiveLoginDays: 7),
        EvolutionType.turtle: _createPet(
            level: 10,
            evolutionStage: 2,
            evolutionType: EvolutionType.turtle,
            sleepAchievedCount: 8,
            consecutiveLoginDays: 7),
      };
      for (final entry in profiles.entries) {
        repository.setPet(entry.value);
        final r = await useCase('test-pet');
        expect(r.evolutionGrade, 'superior',
            reason: '${entry.key} superior 도달 실패');
      }
    });

    test('단조 상향: 이미 3단계 normal이 이후 superior 조건을 채우면 승격', () async {
      final pet = _createPet(
        level: 12,
        evolutionStage: 3,
        evolutionType: EvolutionType.snake,
        evolutionGrade: 'normal',
        sleepAchievedCount: 8,
        feedAchievedCount: 8,
      );
      repository.setPet(pet);

      final result = await useCase('test-pet');
      expect(result.evolutionStage, 3);
      expect(result.evolutionGrade, 'superior'); // normal → superior 승격
    });

    test('하향 없음: 3단계 superior는 조건이 떨어져도 normal로 내려가지 않는다', () async {
      final pet = _createPet(
        level: 12,
        evolutionStage: 3,
        evolutionType: EvolutionType.snake,
        evolutionGrade: 'superior',
        sleepAchievedCount: 0,
        feedAchievedCount: 0,
      );
      repository.setPet(pet);

      final result = await useCase('test-pet');
      expect(result.evolutionGrade, 'superior');
    });
  });

  group('EvolvePetUseCase - Stage 4 mythical 승격', () {
    test('normal 등급은 4단계에서 사신수가 아닌 일반종(normal)이 된다', () async {
      // superior 조건 미달(운동만 높고 급식 부족) → 상향 안 됨 → 일반종
      final pet = _createPet(
        level: 15,
        evolutionStage: 3,
        evolutionType: EvolutionType.bird,
        evolutionGrade: 'normal',
        exerciseAchievedCount: 50,
        feedAchievedCount: 0,
      );
      repository.setPet(pet);

      final result = await useCase('test-pet');
      expect(result.evolutionStage, 4); // 성숙기 도달
      expect(result.evolutionGrade, 'normal'); // 사신수 아님 = 일반종
    });

    // 종 대칭: mythical 임계값 = superior와 같은 두 축, 더 높은 누적(활발/차분/자유 20, 규칙 14)

    test('bird superior + 운동20 + 급식20 → mythical', () async {
      final pet = _createPet(
        level: 15,
        evolutionStage: 3,
        evolutionType: EvolutionType.bird,
        evolutionGrade: 'superior',
        exerciseAchievedCount: 20,
        feedAchievedCount: 20,
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
        exerciseAchievedCount: 12, // < 20
        feedAchievedCount: 20,
      );
      repository.setPet(pet);

      final result = await useCase('test-pet');
      expect(result.evolutionStage, 3);
      expect(result.evolutionGrade, 'superior');
    });

    test('snake superior + 수면20 + 급식20 → mythical (청룡도 신수 도달 가능)', () async {
      final pet = _createPet(
        level: 15,
        evolutionStage: 3,
        evolutionType: EvolutionType.snake,
        evolutionGrade: 'superior',
        sleepAchievedCount: 20,
        feedAchievedCount: 20,
      );
      repository.setPet(pet);

      final result = await useCase('test-pet');
      expect(result.evolutionStage, 4);
      expect(result.evolutionGrade, 'mythical');
    });

    test('tiger superior + 운동20 + 연속접속14 → mythical', () async {
      final pet = _createPet(
        level: 15,
        evolutionStage: 3,
        evolutionType: EvolutionType.tiger,
        evolutionGrade: 'superior',
        exerciseAchievedCount: 20,
        consecutiveLoginDays: 14,
      );
      repository.setPet(pet);

      final result = await useCase('test-pet');
      expect(result.evolutionStage, 4);
      expect(result.evolutionGrade, 'mythical');
    });

    test('turtle superior + 수면20 + 연속접속14 → mythical (현무도 신수 도달 가능)', () async {
      final pet = _createPet(
        level: 15,
        evolutionStage: 3,
        evolutionType: EvolutionType.turtle,
        evolutionGrade: 'superior',
        consecutiveLoginDays: 14,
        sleepAchievedCount: 20,
      );
      repository.setPet(pet);

      final result = await useCase('test-pet');
      expect(result.evolutionStage, 4);
      expect(result.evolutionGrade, 'mythical');
    });

    test('부활 이력이 있어도 신수 승격 가능 (resurrect 게이트 제거·종 대칭)', () async {
      final pet = _createPet(
        level: 15,
        evolutionStage: 3,
        evolutionType: EvolutionType.turtle,
        evolutionGrade: 'superior',
        consecutiveLoginDays: 14,
        sleepAchievedCount: 20,
        resurrectCount: 3,
      );
      repository.setPet(pet);

      final result = await useCase('test-pet');
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

    test('Lv15 + stage3 + normal → 일반종 성숙기로 진화 가능', () {
      final pet = _createPet(
        level: 15,
        evolutionStage: 3,
        evolutionType: EvolutionType.bird,
        evolutionGrade: 'normal',
      );
      expect(useCase.canEvolve(pet), true);
    });

    test('Lv15 + stage3 + superior + 조건 충족 → 4단계 진화 가능', () {
      final pet = _createPet(
        level: 15,
        evolutionStage: 3,
        evolutionType: EvolutionType.bird,
        evolutionGrade: 'superior',
        exerciseAchievedCount: 20,
        feedAchievedCount: 20,
      );
      expect(useCase.canEvolve(pet), true);
    });

    test('Lv12 + stage3 + normal + superior 조건 충족 → 상향 가능', () {
      final pet = _createPet(
        level: 12,
        evolutionStage: 3,
        evolutionType: EvolutionType.snake,
        evolutionGrade: 'normal',
        sleepAchievedCount: 8,
        feedAchievedCount: 8,
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

  group('미션 시스템', () {
    test('Mission 진행도·완료·비율 계산', () {
      const m = Mission(
        id: 'walk_50k',
        title: '산책 매니아',
        description: '누적 5만 보',
        axis: MissionAxis.active,
        metric: MissionMetric.totalSteps,
        target: 50000,
      );
      expect(m.isComplete(_createPet(totalSteps: 49999)), isFalse);
      expect(m.isComplete(_createPet(totalSteps: 50000)), isTrue);
      // 진행도는 target에서 잘린다
      expect(m.progress(_createPet(totalSteps: 80000)), 50000);
      expect(m.ratio(_createPet(totalSteps: 25000)), closeTo(0.5, 1e-9));
    });

    test('axisBonus는 완료 미션 가중치 합', () {
      // battleVictoryCount 10 → battle_10(active) 완료
      final bonus = MissionCatalog.axisBonus(
          _createPet(battleVictoryCount: 10), MissionAxis.active);
      expect(bonus, greaterThanOrEqualTo(4.0));
      // 미완료면 0
      expect(
          MissionCatalog.axisBonus(
              _createPet(battleVictoryCount: 0), MissionAxis.active),
          0.0);
    });

    test('전투 미션(battle_10) 완료가 활발 축을 밀어 종을 바꾼다', () async {
      // 원천 활동은 차분(수면 2)이지만 전투 10승 미션(+활발)으로 활발 판정 뒤집힘
      final withMission = _createPet(
        level: 5,
        evolutionStage: 1,
        sleepAchievedCount: 2, // restScore 2, moveScore raw 0
        battleVictoryCount: 10, // active +4 → moveScore 4 >= 2
      );
      repository.setPet(withMission);
      final a = await useCase('test-pet');
      expect(a.evolutionType, EvolutionType.tiger); // 활발+규칙

      // 미션 미완료(9승)면 원천대로 차분 → turtle
      final withoutMission = _createPet(
        level: 5,
        evolutionStage: 1,
        sleepAchievedCount: 2,
        battleVictoryCount: 9,
      );
      repository.setPet(withoutMission);
      final b = await useCase('test-pet');
      expect(b.evolutionType, EvolutionType.turtle); // 차분+규칙
    });
  });

  group('EvolvePetUseCase.callUntilStable — 다단계 점프', () {
    test('Lv10 + stage1 → 한 번에 stage3까지 진행 (중간 단계에서 안 멈춤)', () async {
      final pet = _createPet(
        level: 10,
        evolutionStage: 1,
        totalSteps: 50000,
        consecutiveLoginDays: 10,
      );
      repository.setPet(pet);

      final result = await useCase.callUntilStable('test-pet');
      expect(result.evolutionStage, 3);
      expect(result.evolutionType, isNotNull);
      expect(result.evolutionGrade, isNotEmpty);
    });

    test('Lv15 + stage1 + 신수 조건 충족 → stage4 mythical까지 진행', () async {
      // 활발(걸음)+자유(급식) → bird, superior/mythical 축도 동일 조건 충족
      final pet = _createPet(
        level: 15,
        evolutionStage: 1,
        totalSteps: 50000,
        exerciseAchievedCount: 20,
        feedAchievedCount: 20,
      );
      repository.setPet(pet);

      final result = await useCase.callUntilStable('test-pet');
      expect(result.evolutionStage, 4);
      expect(result.evolutionGrade, 'mythical');
    });

    test('진화 조건 미달이면 그대로 안정', () async {
      final pet = _createPet(level: 4, evolutionStage: 1);
      repository.setPet(pet);

      final result = await useCase.callUntilStable('test-pet');
      expect(result.evolutionStage, 1);
    });
  });

  group('일반종 개체 색 변이 (colorVariant)', () {
    test('육성 스타일 우세 축 → 변이 0~3', () {
      // 0 활동형 (걸음 우세)
      expect(_createPet(totalSteps: 100000).colorVariant, 0);
      // 1 휴식형 (수면 우세)
      expect(_createPet(sleepAchievedCount: 50).colorVariant, 1);
      // 2 미식형 (급식 우세)
      expect(_createPet(feedAchievedCount: 60).colorVariant, 2);
      // 3 전투형 (전투 우세)
      expect(_createPet(battleVictoryCount: 40).colorVariant, 3);
    });
  });
}
