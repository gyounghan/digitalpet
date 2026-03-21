import 'evolution_type.dart';

/// 펫의 기분 상태
/// hunger, happiness, stamina 값에 따라 결정되는 펫의 현재 상태
enum PetMood {
  /// 기쁨 - 모든 수치가 높을 때
  happy,

  /// 졸림 - 체력이 낮을 때
  sleepy,

  /// 배고픔 - 배고픔 수치가 낮을 때
  hungry,

  /// 지루함 - 행복도가 낮을 때
  bored,

  /// 보통 - 평범한 상태
  normal,

  /// 활기참 - 모든 수치가 매우 높을 때
  energetic,

  /// 피곤함 - 체력이 매우 낮을 때
  tired,

  /// 배부름 - 포만감이 매우 높을 때
  full,

  /// 불안함 - 수치가 불균형할 때
  anxious,

  /// 만족함 - 대부분의 수치가 좋을 때
  satisfied,
}

/// 반려동물 엔티티
/// Domain 레이어의 순수 Dart 클래스로, 비즈니스 로직의 핵심 모델
/// Flutter나 외부 패키지에 의존하지 않는 순수 Dart 클래스
class Pet {
  /// 반려동물 고유 ID
  final String id;

  /// 반려동물 이름
  /// 사용자가 지정한 펫의 이름 (기본값: '펫')
  final String name;

  /// 배고픔 수치 (0~100)
  /// 0: 매우 배고픔, 100: 배부름
  final int hunger;

  /// 행복도 (0~100)
  /// 0: 매우 불행, 100: 매우 행복
  final int happiness;

  /// 체력 (0~100)
  /// 0: 매우 피곤함, 100: 최상의 컨디션
  final int stamina;

  /// 현재 레벨
  final int level;

  /// 경험치
  final int exp;

  /// 진화 단계
  /// 0: 알, 1: 유년기, 2: 성장기, 3: 성체 등
  final int evolutionStage;

  /// 마지막 업데이트 시간 (타임스탬프)
  /// 밀리초 단위 Unix timestamp
  final int lastUpdated;

  /// 마지막 수치 감소 계산 시간 (타임스탬프)
  /// 포만감/운동/수면 감소 로직 전용 기준 시간
  final int lastStatusDecayUpdated;

  /// 누적 걸음 수
  /// 펫이 생성된 이후부터의 총 걸음 수
  final int totalSteps;

  /// 누적 운동 시간 (분)
  /// 펫이 생성된 이후부터의 총 운동 시간
  final int totalExerciseMinutes;

  /// 오늘 동기화된 걸음 수 기준값
  /// 활동 데이터 delta 계산용 내부 상태 (오늘 0시 기준)
  final int todaySyncedSteps;

  /// 오늘 동기화된 운동 시간 기준값(분)
  /// 활동 데이터 delta 계산용 내부 상태 (오늘 0시 기준)
  final int todaySyncedExerciseMinutes;

  /// 누적 미사용 시간 (시간)
  /// 펫이 생성된 이후부터의 총 미사용 시간
  final int totalIdleHours;

  /// 진화 방향 타입
  /// 누적 활동 패턴에 따라 결정되는 진화 방향 (null이면 아직 결정되지 않음)
  final EvolutionType? evolutionType;

  /// 오늘의 Feed 횟수 (일일 목표 추적)
  /// 식사 시간대에 Feed 액션을 수행한 횟수 (최대 3회)
  final int todayFeedCount;

  /// 오늘 식사 시간대 Feed 수행 비트마스크 (아침/점심/저녁)
  /// bit0: 아침, bit1: 점심, bit2: 저녁
  final int todayFedMealSlots;

  /// 오늘의 수면 시간 (시간, 일일 목표 추적)
  /// 오늘 0시부터 현재까지의 총 수면 시간
  final int todaySleepHours;

  /// 오늘 대체 급식 사용 횟수
  /// 접근성 대체 액션(간편 급식) 일일 제한 추적
  final int todayAlternativeFeedCount;

  /// 오늘 대체 수면 사용 횟수
  /// 접근성 대체 액션(짧은 휴식) 일일 제한 추적
  final int todayAlternativeSleepCount;

  /// 오늘 대체 운동 사용 횟수
  /// 접근성 대체 액션(실내 운동 1분) 일일 제한 추적
  final int todayAlternativeExerciseCount;

  /// 마지막 목표 리셋 날짜 (YYYY-MM-DD 형식)
  /// 날짜가 변경되면 todayFeedCount와 todaySleepHours를 리셋
  final String lastGoalResetDate;

  /// 펫의 현재 기분 상태
  /// hunger, happiness, stamina + 현재 시간대에 따라 자동 계산
  ///
  /// 판단 우선순위:
  /// 1단계 위기(≤10) → 2단계 경고(≤25) → 3단계 수면신호(시간대 반영)
  /// → 4단계 감정위기 → 5단계 최상긍정 → 6단계 부분긍정
  /// → 7단계 불균형 → 8단계 기본값
  PetMood get mood {
    final hour = DateTime.now().hour;
    // 밤 22시~새벽 6시: 수면 시간대 (stamina 기준 완화)
    final isNightTime = hour >= 22 || hour < 6;

    // 1단계: 위기 상태 (10 이하 — 즉각 개입 필요)
    if (hunger <= 10) return PetMood.hungry;
    if (stamina <= 10) return PetMood.tired;

    // 2단계: 경고 상태 (25 이하)
    if (hunger <= 25) return PetMood.hungry;
    if (stamina <= 25) return PetMood.tired;

    // 3단계: 수면 신호 (시간대 반영)
    // 밤 시간대에는 stamina 60 이하면 졸림 — 실생활 패턴 반영
    if (isNightTime && stamina <= 60) return PetMood.sleepy;
    if (stamina <= 35) return PetMood.sleepy;

    // 4단계: 감정 위기
    if (happiness <= 20) return PetMood.anxious;
    if (happiness <= 35) return PetMood.bored;

    // 5단계: 최상 긍정 상태
    if (hunger >= 90 && happiness >= 90 && stamina >= 90) return PetMood.energetic;
    if (hunger >= 80 && happiness >= 85 && stamina >= 80) return PetMood.happy;

    // 6단계: 부분 긍정 상태
    // 배부른 상태: 포만감 매우 높고 나머지 양호
    if (hunger >= 85 && happiness >= 60 && stamina >= 55) return PetMood.full;
    // 활동/운동 후 만족: stamina가 다소 소모됐어도 happiness가 높으면 만족
    if (happiness >= 75 && stamina >= 45 && hunger >= 55) return PetMood.satisfied;
    if ((hunger >= 70 && happiness >= 70) ||
        (hunger >= 70 && stamina >= 65) ||
        (happiness >= 70 && stamina >= 65)) {
      return PetMood.satisfied;
    }

    // 7단계: 불균형 감지 (기존 40 → 35로 낮춰 더 민감하게 반응)
    final avg = (hunger + happiness + stamina) / 3;
    final maxDiff = [
      (hunger - avg).abs(),
      (happiness - avg).abs(),
      (stamina - avg).abs(),
    ].reduce((a, b) => a > b ? a : b);
    if (maxDiff > 35) return PetMood.anxious;

    // 8단계: 기본값
    return PetMood.normal;
  }

  Pet({
    required this.id,
    this.name = '펫',
    required this.hunger,
    required this.happiness,
    required this.stamina,
    required this.level,
    required this.exp,
    required this.evolutionStage,
    required this.lastUpdated,
    required this.lastStatusDecayUpdated,
    this.totalSteps = 0,
    this.totalExerciseMinutes = 0,
    this.todaySyncedSteps = 0,
    this.todaySyncedExerciseMinutes = 0,
    this.totalIdleHours = 0,
    this.evolutionType,
    this.todayFeedCount = 0,
    this.todayFedMealSlots = 0,
    this.todaySleepHours = 0,
    this.todayAlternativeFeedCount = 0,
    this.todayAlternativeSleepCount = 0,
    this.todayAlternativeExerciseCount = 0,
    this.lastGoalResetDate = '',
  });

  /// Pet 객체 복사본 생성
  /// 특정 필드만 변경하여 새로운 Pet 인스턴스 반환
  Pet copyWith({
    String? id,
    String? name,
    int? hunger,
    int? happiness,
    int? stamina,
    int? level,
    int? exp,
    int? evolutionStage,
    int? lastUpdated,
    int? lastStatusDecayUpdated,
    int? totalSteps,
    int? totalExerciseMinutes,
    int? todaySyncedSteps,
    int? todaySyncedExerciseMinutes,
    int? totalIdleHours,
    EvolutionType? evolutionType,
    int? todayFeedCount,
    int? todayFedMealSlots,
    int? todaySleepHours,
    int? todayAlternativeFeedCount,
    int? todayAlternativeSleepCount,
    int? todayAlternativeExerciseCount,
    String? lastGoalResetDate,
  }) {
    return Pet(
      id: id ?? this.id,
      name: name ?? this.name,
      hunger: hunger ?? this.hunger,
      happiness: happiness ?? this.happiness,
      stamina: stamina ?? this.stamina,
      level: level ?? this.level,
      exp: exp ?? this.exp,
      evolutionStage: evolutionStage ?? this.evolutionStage,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      lastStatusDecayUpdated: lastStatusDecayUpdated ?? this.lastStatusDecayUpdated,
      totalSteps: totalSteps ?? this.totalSteps,
      totalExerciseMinutes: totalExerciseMinutes ?? this.totalExerciseMinutes,
      todaySyncedSteps: todaySyncedSteps ?? this.todaySyncedSteps,
      todaySyncedExerciseMinutes: todaySyncedExerciseMinutes ?? this.todaySyncedExerciseMinutes,
      totalIdleHours: totalIdleHours ?? this.totalIdleHours,
      evolutionType: evolutionType ?? this.evolutionType,
      todayFeedCount: todayFeedCount ?? this.todayFeedCount,
      todayFedMealSlots: todayFedMealSlots ?? this.todayFedMealSlots,
      todaySleepHours: todaySleepHours ?? this.todaySleepHours,
      todayAlternativeFeedCount: todayAlternativeFeedCount ?? this.todayAlternativeFeedCount,
      todayAlternativeSleepCount: todayAlternativeSleepCount ?? this.todayAlternativeSleepCount,
      todayAlternativeExerciseCount: todayAlternativeExerciseCount ?? this.todayAlternativeExerciseCount,
      lastGoalResetDate: lastGoalResetDate ?? this.lastGoalResetDate,
    );
  }

  /// 오늘 날짜 문자열 반환 (YYYY-MM-DD)
  String get todayDateString {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// 일일 목표 리셋 필요 여부 확인
  bool get needsGoalReset {
    return lastGoalResetDate != todayDateString;
  }

  /// 일일 목표 리셋된 Pet 반환
  Pet resetDailyGoals() {
    return copyWith(
      todayFeedCount: 0,
      todayFedMealSlots: 0,
      todaySleepHours: 0,
      todayAlternativeFeedCount: 0,
      todayAlternativeSleepCount: 0,
      todayAlternativeExerciseCount: 0,
      todaySyncedSteps: 0,
      todaySyncedExerciseMinutes: 0,
      lastGoalResetDate: todayDateString,
    );
  }
}
