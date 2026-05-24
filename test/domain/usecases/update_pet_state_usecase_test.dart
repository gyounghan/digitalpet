import 'package:flutter_test/flutter_test.dart';
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
  );
}

void main() {
  late FakePetRepository repo;
  late UpdatePetStateUseCase useCase;

  setUp(() {
    repo = FakePetRepository();
    useCase = UpdatePetStateUseCase(repo);
  });

  group('calculateDaytimeMinutes', () {
    test('완전한 낮 시간 (10:00~14:00) → 240분', () {
      final from = DateTime(2026, 4, 13, 10, 0);
      final to = DateTime(2026, 4, 13, 14, 0);
      expect(useCase.calculateDaytimeMinutes(from, to), 240);
    });

    test('완전한 밤 시간 (23:00~05:00) → 0분', () {
      final from = DateTime(2026, 4, 13, 23, 0);
      final to = DateTime(2026, 4, 14, 5, 0);
      expect(useCase.calculateDaytimeMinutes(from, to), 0);
    });

    test('밤→낮 전환 (22:00~09:00) → 낮 시간 3시간=180분', () {
      final from = DateTime(2026, 4, 13, 22, 0); // 22시 (밤)
      final to = DateTime(2026, 4, 14, 9, 0); // 다음날 09시 (낮)
      // 밤: 22:00~06:00 = 8시간 (무시)
      // 낮: 06:00~09:00 = 3시간 = 180분
      expect(useCase.calculateDaytimeMinutes(from, to), 180);
    });

    test('낮→밤 전환 (20:00~23:00) → 낮 시간 2시간=120분', () {
      final from = DateTime(2026, 4, 13, 20, 0); // 20시 (낮)
      final to = DateTime(2026, 4, 13, 23, 0); // 23시 (밤)
      // 낮: 20:00~22:00 = 2시간 = 120분
      // 밤: 22:00~23:00 = 1시간 (무시)
      expect(useCase.calculateDaytimeMinutes(from, to), 120);
    });

    test('하루 전체 (06:00~다음날 06:00) → 낮 16시간=960분', () {
      final from = DateTime(2026, 4, 13, 6, 0);
      final to = DateTime(2026, 4, 14, 6, 0);
      // 낮: 06:00~22:00 = 16시간 = 960분
      // 밤: 22:00~06:00 = 8시간 (무시)
      expect(useCase.calculateDaytimeMinutes(from, to), 960);
    });

    test('여러 날 (2일 전체) → 낮 32시간=1920분', () {
      final from = DateTime(2026, 4, 13, 6, 0);
      final to = DateTime(2026, 4, 15, 6, 0);
      // 하루 낮 시간 = 16시간 × 2일 = 32시간 = 1920분
      expect(useCase.calculateDaytimeMinutes(from, to), 1920);
    });

    test('0시~6시 (새벽 밤) → 0분', () {
      final from = DateTime(2026, 4, 13, 0, 0);
      final to = DateTime(2026, 4, 13, 6, 0);
      expect(useCase.calculateDaytimeMinutes(from, to), 0);
    });

    test('from == to → 0분', () {
      final from = DateTime(2026, 4, 13, 12, 0);
      expect(useCase.calculateDaytimeMinutes(from, from), 0);
    });

    test('from > to → 0분', () {
      final from = DateTime(2026, 4, 13, 14, 0);
      final to = DateTime(2026, 4, 13, 12, 0);
      expect(useCase.calculateDaytimeMinutes(from, to), 0);
    });

    test('밤 시작 직전~직후 (21:59~22:01) → 1분', () {
      final from = DateTime(2026, 4, 13, 21, 59);
      final to = DateTime(2026, 4, 13, 22, 1);
      // 낮: 21:59~22:00 = 1분
      // 밤: 22:00~22:01 = 무시
      expect(useCase.calculateDaytimeMinutes(from, to), 1);
    });

    test('새벽~오전 (03:00~10:00) → 4시간=240분', () {
      final from = DateTime(2026, 4, 13, 3, 0); // 03시 (밤)
      final to = DateTime(2026, 4, 13, 10, 0); // 10시 (낮)
      // 밤: 03:00~06:00 = 3시간 (무시)
      // 낮: 06:00~10:00 = 4시간 = 240분
      expect(useCase.calculateDaytimeMinutes(from, to), 240);
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
        // hunger: 120분 / 60분 = 2 intervals × 2 = -4
        expect(result.hunger, 96);
        // happiness: 120분 / 60분 = 2 intervals × 1 = -2
        expect(result.happiness, 98);
        // stamina: 120분 / 40분 = 3 intervals × 1 = -3
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
        // hunger: 2 intervals × 2 × 2.0 = -8 → max(10-8, 0) = 2
        expect(result.hunger, 2);
        // happiness: 2 intervals × 1 × 2.0 = -4 → max(10-4, 0) = 6
        expect(result.happiness, 6);
        // stamina: 3 intervals × 1 × 2.0 = -6 → max(50-6, 0) = 44
        expect(result.stamina, 44);
      }
    });
  });
}
