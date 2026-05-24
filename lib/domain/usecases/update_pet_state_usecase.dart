import '../entities/pet.dart';
import '../repositories/pet_repository.dart';
import '../constants/species_growth_config.dart';

/// 반려동물 상태 업데이트 유스케이스
/// 시간 경과에 따라 펫�� 상태(hunger, happiness, stamina)를 차등 감소
///
/// 감소 규칙 (수치별 차등):
/// - 포만감(hunger): 60분마다 -2 (밤: -1)
/// - 행복도(happiness): 60분마다 -1 (밤: 감소 중단)
/// - 체력(stamina): 40분마다 -1 (밤: 감소 ���단)
/// - 밤시간: 22시~06시
/// - 값은 0 이하로 내려가지 않음
///
/// 위기 가속:
/// - 수치 2개 이상 ≤20: decay 1.5배
/// - 수치 2�� 이상 ≤10: decay 2배
class UpdatePetStateUseCase {
  final PetRepository petRepository;

  /// 수치별 감소 간격 (분)
  static const int hungerIntervalMinutes = 60;
  static const int happinessIntervalMinutes = 60;
  static const int staminaIntervalMinutes = 40;

  /// 수치별 감소량
  static const int hungerDecreasePerInterval = 2;
  static const int happinessDecreasePerInterval = 1;
  static const int staminaDecreasePerInterval = 1;

  /// 밤시간 기준 (22시~06시)
  static const int nightStartHour = 22;
  static const int nightEndHour = 6;

  UpdatePetStateUseCase(this.petRepository);

  /// 주어진 시각이 밤시간(22시~06시)인지 확인
  bool _isNightTime(DateTime time) {
    return time.hour >= nightStartHour || time.hour < nightEndHour;
  }

  /// 주어진 기간 내 낮 시간(06:00~22:00) 분 수 계산
  ///
  /// 경과 기간이 밤과 낮에 걸치는 경우를 정확히 분리하여
  /// happiness/stamina가 밤에 감소하지 않도록 보장한다.
  int calculateDaytimeMinutes(DateTime from, DateTime to) {
    if (!to.isAfter(from)) return 0;

    int daytimeMinutes = 0;
    var cursor = from;

    while (cursor.isBefore(to)) {
      if (_isNightTime(cursor)) {
        // 밤 → 다음 낮 시작(06:00)으로 점프
        final DateTime nextDayStart;
        if (cursor.hour >= nightStartHour) {
          // 22시~23시59분 → 다음날 06시
          nextDayStart = DateTime(
            cursor.year, cursor.month, cursor.day + 1, nightEndHour,
          );
        } else {
          // 00시~05시59분 → 오늘 06시
          nextDayStart = DateTime(
            cursor.year, cursor.month, cursor.day, nightEndHour,
          );
        }
        cursor = to.isBefore(nextDayStart) ? to : nextDayStart;
      } else {
        // 낮 → 오늘 밤 시작(22:00)까지
        final todayNightStart = DateTime(
          cursor.year, cursor.month, cursor.day, nightStartHour,
        );
        final segmentEnd = to.isBefore(todayNightStart) ? to : todayNightStart;
        daytimeMinutes += segmentEnd.difference(cursor).inMinutes;
        cursor = segmentEnd;
      }
    }

    return daytimeMinutes;
  }

  /// 위기 가속 배율 계산
  double _getCrisisMultiplier(Pet pet) {
    int criticalCount = 0;
    if (pet.hunger <= 10) criticalCount++;
    if (pet.happiness <= 10) criticalCount++;
    if (pet.stamina <= 10) criticalCount++;

    if (criticalCount >= 2) return 2.0;

    int warningCount = 0;
    if (pet.hunger <= 20) warningCount++;
    if (pet.happiness <= 20) warningCount++;
    if (pet.stamina <= 20) warningCount++;

    if (warningCount >= 2) return 1.5;

    return 1.0;
  }

  /// 반려동물 상태를 시간 경과에 따라 업데이트
  Future<Pet> call(String petId) async {
    final pet = await petRepository.getPet(petId);

    if (pet.isDead) return pet;

    final now = DateTime.now();
    final currentTime = now.millisecondsSinceEpoch;
    final lastDecayTime = DateTime.fromMillisecondsSinceEpoch(
      pet.lastStatusDecayUpdated,
    );
    final elapsedMinutes = now.difference(lastDecayTime).inMinutes;

    // 최소 갱신 간격: 10분
    if (elapsedMinutes < 10) return pet;

    // 경과 기간을 낮/밤으로 분리하여 정확한 감소량 계산
    final daytimeMinutes = calculateDaytimeMinutes(lastDecayTime, now);
    final nightMinutes = elapsedMinutes - daytimeMinutes;
    final crisisMultiplier = _getCrisisMultiplier(pet);
    final dm = SpeciesGrowthConfig.getDecayMultipliers(pet.evolutionType);

    // Hunger: 60분마다 -2 (낮), 60분마다 -1 (밤)
    final hungerDayIntervals = daytimeMinutes ~/ hungerIntervalMinutes;
    final hungerNightIntervals = nightMinutes ~/ hungerIntervalMinutes;
    final hungerNightBase =
        (hungerDecreasePerInterval ~/ 2).clamp(1, hungerDecreasePerInterval);
    final hungerDecrease = ((hungerDayIntervals * hungerDecreasePerInterval +
                hungerNightIntervals * hungerNightBase) *
            crisisMultiplier *
            dm.hunger)
        .round();

    // Happiness: 60분마다 -1 (낮), 밤에는 감소 중단
    final happinessIntervals = daytimeMinutes ~/ happinessIntervalMinutes;
    final happinessDecrease =
        (happinessIntervals * happinessDecreasePerInterval * crisisMultiplier * dm.happiness)
            .round();

    // Stamina: 40분마다 -1 (낮), 밤에는 감소 중단
    final staminaIntervals = daytimeMinutes ~/ staminaIntervalMinutes;
    final staminaDecrease =
        (staminaIntervals * staminaDecreasePerInterval * crisisMultiplier * dm.stamina)
            .round();

    // 변화 없으면 스킵
    if (hungerDecrease == 0 && happinessDecrease == 0 && staminaDecrease == 0) {
      return pet;
    }

    final newHunger = (pet.hunger - hungerDecrease).clamp(0, 100);
    final newHappiness = (pet.happiness - happinessDecrease).clamp(0, 100);
    final newStamina = (pet.stamina - staminaDecrease).clamp(0, 100);

    final updatedPet = pet.copyWith(
      hunger: newHunger,
      happiness: newHappiness,
      stamina: newStamina,
      lastStatusDecayUpdated: currentTime,
      lastUpdated: currentTime,
    );

    await petRepository.updatePet(updatedPet);
    return updatedPet;
  }
}
