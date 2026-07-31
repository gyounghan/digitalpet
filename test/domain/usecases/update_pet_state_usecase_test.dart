import 'package:flutter_test/flutter_test.dart';
import 'package:pocketfriend/domain/constants/daily_events.dart';
import 'package:pocketfriend/domain/entities/pet.dart';
import 'package:pocketfriend/domain/repositories/pet_repository.dart';
import 'package:pocketfriend/domain/usecases/update_pet_state_usecase.dart';

/// Pet Repository fake
class FakePetRepository implements PetRepository {
  Pet? _pet;

  void setPet(Pet pet) => _pet = pet;
  Pet? get currentPet => _pet;

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

/// 테스트용 기본 펫 생성
Pet _createPet({
  int hunger = 100,
  int happiness = 100,
  int stamina = 100,
  required int lastStatusDecayUpdated,
  String todayEvent = '',
  String lastEventDate = '',
}) {
  return Pet(
    id: 'test',
    name: '테스트펫',
    hunger: hunger,
    happiness: happiness,
    stamina: stamina,
    level: 1,
    exp: 0,
    evolutionStage: 1,
    lastUpdated: lastStatusDecayUpdated,
    lastStatusDecayUpdated: lastStatusDecayUpdated,
    todayEvent: todayEvent,
    lastEventDate: lastEventDate,
  );
}

String _dateString(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

void main() {
  late FakePetRepository repo;
  late UpdatePetStateUseCase useCase;

  setUp(() {
    repo = FakePetRepository();
    useCase = UpdatePetStateUseCase(repo);
  });

  group('countIntervalBoundaries — 절대 그리드 경계', () {
    test('낮 2시간 (10:00~12:00), 60분 그리드 → 낮 경계 2회', () {
      final from = DateTime(2026, 4, 13, 10, 0);
      final to = DateTime(2026, 4, 13, 12, 0);
      final result = useCase.countIntervalBoundaries(from, to, 60);
      expect(result.day, 2); // 11:00, 12:00
      expect(result.night, 0);
    });

    test('밤 구간 (23:00~05:00), 60분 그리드 → 밤 경계 6회', () {
      final from = DateTime(2026, 4, 13, 23, 0);
      final to = DateTime(2026, 4, 14, 5, 0);
      final result = useCase.countIntervalBoundaries(from, to, 60);
      expect(result.day, 0);
      expect(result.night, 6); // 00:00 ~ 05:00
    });

    test('22:00 경계는 직전 시간대(낮)로 분류', () {
      final from = DateTime(2026, 4, 13, 21, 0);
      final to = DateTime(2026, 4, 13, 22, 0);
      final result = useCase.countIntervalBoundaries(from, to, 60);
      expect(result.day, 1); // 22:00 경계 = 21시대 마감 → 낮
      expect(result.night, 0);
    });

    test('06:00 경계는 직전 시간대(밤)로 분류', () {
      final from = DateTime(2026, 4, 13, 5, 0);
      final to = DateTime(2026, 4, 13, 6, 0);
      final result = useCase.countIntervalBoundaries(from, to, 60);
      expect(result.day, 0);
      expect(result.night, 1); // 06:00 경계 = 05시대 마감 → 밤
    });

    test('낮 2시간, 40분 그리드 → 경계 총 3회 (위상 무관)', () {
      final from = DateTime(2026, 4, 13, 10, 0);
      final to = DateTime(2026, 4, 13, 12, 0);
      final result = useCase.countIntervalBoundaries(from, to, 40);
      expect(result.day + result.night, 3);
      expect(result.night, 0);
    });

    test('회귀: 분할 갱신해도 경계 수가 유실되지 않는다', () {
      // 과거 버그: 40분 주기 갱신마다 anchor가 리셋돼 60분 그리드 진행이 절삭.
      // 절대 그리드에서는 (10:00→10:45] + (10:45→11:30] = (10:00→11:30]이 보장된다.
      final t0 = DateTime(2026, 4, 13, 10, 0);
      final t1 = DateTime(2026, 4, 13, 10, 45);
      final t2 = DateTime(2026, 4, 13, 11, 30);

      final first = useCase.countIntervalBoundaries(t0, t1, 60);
      final second = useCase.countIntervalBoundaries(t1, t2, 60);
      final whole = useCase.countIntervalBoundaries(t0, t2, 60);

      expect(first.day + second.day, whole.day);
      expect(first.night + second.night, whole.night);
      expect(whole.day, 1); // 11:00 경계
    });

    test('하루 전체 (06:00~다음날 06:00), 60분 그리드 → 낮 16 / 밤 8', () {
      final from = DateTime(2026, 4, 13, 6, 0);
      final to = DateTime(2026, 4, 14, 6, 0);
      final result = useCase.countIntervalBoundaries(from, to, 60);
      expect(result.day, 16);
      expect(result.night, 8);
    });

    test('from == to → 0회', () {
      final from = DateTime(2026, 4, 13, 12, 0);
      final result = useCase.countIntervalBoundaries(from, from, 60);
      expect(result.day, 0);
      expect(result.night, 0);
    });

    test('from > to → 0회', () {
      final from = DateTime(2026, 4, 13, 14, 0);
      final to = DateTime(2026, 4, 13, 12, 0);
      final result = useCase.countIntervalBoundaries(from, to, 60);
      expect(result.day, 0);
      expect(result.night, 0);
    });
  });

  group('UpdatePetStateUseCase - call()', () {
    test('10분 미만 경과 시 상태 변화 없음', () async {
      final now = DateTime.now();
      final fiveMinAgo = now.subtract(const Duration(minutes: 5));
      repo.setPet(_createPet(
        lastStatusDecayUpdated: fiveMinAgo.millisecondsSinceEpoch,
      ));

      final result = await useCase('test');
      expect(result.hunger, 100);
      expect(result.happiness, 100);
      expect(result.stamina, 100);
    });

    test('낮 시간 2시간 경과 시 hunger/happiness/stamina 모두 감소', () async {
      // 낮 시간(정오)에서 2시간 전에 업데이트된 펫
      final now = DateTime.now();
      final hour = now.hour;

      // 현재 시각이 낮(8~20시)인 경우만 테스트
      // 밤 시간이면 테스트 결과가 달라질 수 있으므로 건너뜀
      if (hour >= 8 && hour <= 20) {
        final twoHoursAgo = now.subtract(const Duration(hours: 2));
        repo.setPet(_createPet(
          lastStatusDecayUpdated: twoHoursAgo.millisecondsSinceEpoch,
        ));

        final result = await useCase('test');
        // hunger: 60분 경계 2회 × 2 = -4
        expect(result.hunger, 96);
        // happiness: 60분 경계 2회 × 1 = -2
        expect(result.happiness, 98);
        // stamina: 40분 경계 3회 × 1 = -3
        expect(result.stamina, 97);
      }
    });

    test('사망 상태 펫은 업데이트하지 않음', () async {
      final twoHoursAgo =
          DateTime.now().subtract(const Duration(hours: 2));
      repo.setPet(Pet(
        id: 'test',
        name: '테스트펫',
        hunger: 0,
        happiness: 0,
        stamina: 0,
        level: 1,
        exp: 0,
        evolutionStage: 1,
        lastUpdated: twoHoursAgo.millisecondsSinceEpoch,
        lastStatusDecayUpdated: twoHoursAgo.millisecondsSinceEpoch,
        isDead: true,
      ));

      final result = await useCase('test');
      expect(result.hunger, 0);
      expect(result.happiness, 0);
      expect(result.stamina, 0);
      expect(result.isDead, true);
    });

    test('위기 배율: 수치 2개 이상 ≤10 → 2배 감소', () async {
      final now = DateTime.now();
      final hour = now.hour;

      if (hour >= 8 && hour <= 20) {
        final twoHoursAgo = now.subtract(const Duration(hours: 2));
        repo.setPet(_createPet(
          hunger: 10,
          happiness: 10,
          stamina: 50,
          lastStatusDecayUpdated: twoHoursAgo.millisecondsSinceEpoch,
        ));

        final result = await useCase('test');
        // crisisMultiplier = 2.0
        // hunger: 2회 × 2 × 2.0 = -8 → max(10-8, 0) = 2
        expect(result.hunger, 2);
        // happiness: 2회 × 1 × 2.0 = -4 → max(10-4, 0) = 6
        expect(result.happiness, 6);
        // stamina: 3회 × 1 × 2.0 = -6 → max(50-6, 0) = 44
        expect(result.stamina, 44);
      }
    });

    test('happy_day 이벤트(오늘)면 감소량 절반', () async {
      final now = DateTime.now();
      final hour = now.hour;

      if (hour >= 8 && hour <= 20) {
        final twoHoursAgo = now.subtract(const Duration(hours: 2));
        repo.setPet(_createPet(
          lastStatusDecayUpdated: twoHoursAgo.millisecondsSinceEpoch,
          todayEvent: DailyEvents.happyDay,
          lastEventDate: _dateString(now),
        ));

        final result = await useCase('test');
        // hunger: 2회 × 2 × 0.5 = -2
        expect(result.hunger, 98);
        // happiness: 2회 × 1 × 0.5 = -1
        expect(result.happiness, 99);
        // stamina: 3회 × 1 × 0.5 = 1.5 → round = -2
        expect(result.stamina, 98);
      }
    });

    test('happy_day여도 lastEventDate가 오늘이 아니면 감소 절반 미적용', () async {
      final now = DateTime.now();
      final hour = now.hour;

      if (hour >= 8 && hour <= 20) {
        final twoHoursAgo = now.subtract(const Duration(hours: 2));
        final yesterday = now.subtract(const Duration(days: 1));
        repo.setPet(_createPet(
          lastStatusDecayUpdated: twoHoursAgo.millisecondsSinceEpoch,
          todayEvent: DailyEvents.happyDay,
          lastEventDate: _dateString(yesterday),
        ));

        final result = await useCase('test');
        expect(result.hunger, 96);
        expect(result.happiness, 98);
        expect(result.stamina, 97);
      }
    });
  });
}
