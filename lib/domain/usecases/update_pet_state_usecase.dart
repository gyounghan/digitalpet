import '../entities/pet.dart';
import '../repositories/pet_repository.dart';
import '../constants/daily_events.dart';
import '../constants/species_growth_config.dart';

/// 간격 그리드 경계 통과 횟수 (낮/밤 분리)
class IntervalBoundaryCount {
  final int day;
  final int night;
  const IntervalBoundaryCount({required this.day, required this.night});
}

/// 반려동물 상태 업데이트 유스케이스
/// 시간 경과에 따라 펫의 상태(hunger, happiness, stamina)를 차등 감소
///
/// 감소 규칙 (수치별 차등):
/// - 포만감(hunger): 60분마다 -2 (밤: -1)
/// - 행복도(happiness): 60분마다 -1 (밤: 감소 중단)
/// - 체력(stamina): 40분마다 -1 (밤: 감소 중단)
/// - 밤시간: 22시~06시
/// - 값은 0 이하로 내려가지 않음
///
/// 감소 판정은 **절대 시각 그리드 경계** 기준이다:
/// 각 수치는 고정 간격(60분/40분)의 절대 그리드를 가지며, 마지막 계산
/// 시각(lastStatusDecayUpdated) 이후 "경계를 넘은 횟수"만큼 감소한다.
/// 경계가 절대 시각에 고정돼 있으므로 갱신 주기가 어떻든(5분 폴링,
/// 15분 백그라운드 틱 등) 잔여 시간이 유실되지 않는다.
/// (과거: 단일 anchor를 감소 시마다 now로 리셋해, 40분 주기 stamina 감소가
///  60분 간격인 hunger/happiness의 진행 시간을 계속 절삭 → 낮 시간
///  hunger/happiness가 사실상 감소하지 않던 버그)
///
/// 위기 가속:
/// - 수치 2개 이상 ≤20: decay 1.5배
/// - 수치 2개 이상 ≤10: decay 2배
///
/// 일일 이벤트:
/// - happy_day(오늘 부여된 경우만): 감소량 절반
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

  /// (from, to] 구간에서 [intervalMinutes] 절대 그리드 경계를 넘은 횟수를
  /// 낮/밤으로 분리해 계산한다.
  ///
  /// 경계는 epoch 분 기준 `intervalMinutes`의 배수 시각. 각 경계는 그 경계가
  /// "닫는 구간"(직전 1분)의 낮/밤으로 분류한다 — 22:00 경계는 21시대(낮),
  /// 06:00 경계는 05시대(밤)의 감소로 계산된다.
  IntervalBoundaryCount countIntervalBoundaries(
    DateTime from,
    DateTime to,
    int intervalMinutes,
  ) {
    if (!to.isAfter(from)) {
      return const IntervalBoundaryCount(day: 0, night: 0);
    }

    final fromMin = from.millisecondsSinceEpoch ~/ 60000;
    final toMin = to.millisecondsSinceEpoch ~/ 60000;

    int day = 0;
    int night = 0;
    // from 직후 첫 경계부터 to까지 순회
    var boundary = (fromMin ~/ intervalMinutes + 1) * intervalMinutes;
    while (boundary <= toMin) {
      final closingMinute =
          DateTime.fromMillisecondsSinceEpoch((boundary - 1) * 60000);
      if (_isNightTime(closingMinute)) {
        night++;
      } else {
        day++;
      }
      boundary += intervalMinutes;
    }

    return IntervalBoundaryCount(day: day, night: night);
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

    final crisisMultiplier = _getCrisisMultiplier(pet);
    final dm = SpeciesGrowthConfig.getDecayMultipliers(pet.evolutionType);

    // happy_day 이벤트(오늘 부여된 경우만): 감소량 절반
    // lastEventDate 검사로 어제 이벤트가 자정 이월 적용되는 것을 방지
    final isEventToday = pet.lastEventDate == pet.todayDateString;
    final eventMultiplier =
        (isEventToday && pet.todayEvent == DailyEvents.happyDay)
            ? DailyEvents.happyDayDecayMultiplier
            : 1.0;

    // 절대 그리드 경계 통과 횟수 계산 (낮/밤 분리)
    final hungerBounds =
        countIntervalBoundaries(lastDecayTime, now, hungerIntervalMinutes);
    final happinessBounds =
        countIntervalBoundaries(lastDecayTime, now, happinessIntervalMinutes);
    final staminaBounds =
        countIntervalBoundaries(lastDecayTime, now, staminaIntervalMinutes);

    // Hunger: 60분마다 -2 (낮), -1 (밤)
    final hungerNightBase =
        (hungerDecreasePerInterval ~/ 2).clamp(1, hungerDecreasePerInterval);
    final hungerDecrease = ((hungerBounds.day * hungerDecreasePerInterval +
                hungerBounds.night * hungerNightBase) *
            crisisMultiplier *
            dm.hunger *
            eventMultiplier)
        .round();

    // Happiness: 60분마다 -1 (낮), 밤에는 감소 중단
    final happinessDecrease = (happinessBounds.day *
            happinessDecreasePerInterval *
            crisisMultiplier *
            dm.happiness *
            eventMultiplier)
        .round();

    // Stamina: 40분마다 -1 (낮), 밤에는 감소 중단
    final staminaDecrease = (staminaBounds.day *
            staminaDecreasePerInterval *
            crisisMultiplier *
            dm.stamina *
            eventMultiplier)
        .round();

    // 변화 없으면 스킵 (경계가 절대 시각이므로 anchor를 유지해도 유실 없음)
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
