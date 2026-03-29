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

  /// 사망 - isDead가 true일 때
  dead,
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
  /// 날짜가 변경되면 일일 항목(식사 슬롯, 대체 액션 등)만 리셋
  final String lastGoalResetDate;

  /// 사망 여부
  final bool isDead;

  /// 사망 시각 (밀리초 타임스탬프, null이면 살아있음)
  final int? deathDate;

  /// 모든 수치가 0이 된 시점 (YYYY-MM-DD 형식, null이면 0 상태 아님)
  final String? zeroStatStartDate;

  /// 부활 횟수
  final int resurrectCount;

  /// 현재 목표 기간 시작 날짜 (YYYY-MM-DD 형식)
  final String goalStartDate;

  /// 연속 목표 달성 횟수
  final int goalStreakCount;

  /// 목표 기간 시작 시 누적 걸음 수 (기간 운동량 계산용)
  final int goalStartTotalSteps;

  /// 목표 기간 시작 시 누적 운동 시간 (기간 운동량 계산용)
  final int goalStartTotalExerciseMinutes;

  /// 누적 배틀 승리 횟수 (진화 조건용)
  final int battleVictoryCount;

  /// 오늘의 일일 이벤트 ID (sunny/cozy/tasty/happy_day/adventure/normal)
  final String todayEvent;

  /// 마지막 이벤트 부여 날짜 (YYYY-MM-DD)
  final String lastEventDate;

  /// 연속 접속 일수
  final int consecutiveLoginDays;

  /// 마지막 접속 날짜 (YYYY-MM-DD)
  final String lastLoginDate;

  /// 오늘 배틀 횟수
  final int todayBattleCount;

  /// 오늘 접속 횟수 (접속 보너스 계산용)
  final int todayLoginCount;

  /// 마지막 접속 시각 (밀리초, 4시간 간격 체크용)
  final int lastLoginTime;

  /// 진화 등급 ('': 미결정, 'normal': 일반, 'superior': 상위, 'mythical': 신수)
  final String evolutionGrade;

  /// 펫의 현재 기분 상태
  /// hunger, happiness, stamina + 현재 시간대에 따라 자동 계산
  ///
  /// 판단 우선순위:
  /// 1단계 위기(≤10) → 2단계 경고(≤25) → 3단계 수면신호(시간대 반영)
  /// → 4단계 감정위기 → 5단계 최상긍정 → 6단계 부분긍정
  /// → 7단계 불균형 → 8단계 기본값
  PetMood get mood {
    // 0단계: 사망 상태
    if (isDead) return PetMood.dead;

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
    this.isDead = false,
    this.deathDate,
    this.zeroStatStartDate,
    this.resurrectCount = 0,
    this.goalStartDate = '',
    this.goalStreakCount = 0,
    this.goalStartTotalSteps = 0,
    this.goalStartTotalExerciseMinutes = 0,
    this.battleVictoryCount = 0,
    this.todayEvent = '',
    this.lastEventDate = '',
    this.consecutiveLoginDays = 0,
    this.lastLoginDate = '',
    this.todayBattleCount = 0,
    this.todayLoginCount = 0,
    this.lastLoginTime = 0,
    this.evolutionGrade = '',
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
    bool? isDead,
    int? deathDate,
    String? zeroStatStartDate,
    int? resurrectCount,
    String? goalStartDate,
    int? goalStreakCount,
    int? goalStartTotalSteps,
    int? goalStartTotalExerciseMinutes,
    int? battleVictoryCount,
    String? todayEvent,
    String? lastEventDate,
    int? consecutiveLoginDays,
    String? lastLoginDate,
    int? todayBattleCount,
    int? todayLoginCount,
    int? lastLoginTime,
    String? evolutionGrade,
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
      isDead: isDead ?? this.isDead,
      deathDate: deathDate ?? this.deathDate,
      zeroStatStartDate: zeroStatStartDate ?? this.zeroStatStartDate,
      resurrectCount: resurrectCount ?? this.resurrectCount,
      goalStartDate: goalStartDate ?? this.goalStartDate,
      goalStreakCount: goalStreakCount ?? this.goalStreakCount,
      goalStartTotalSteps: goalStartTotalSteps ?? this.goalStartTotalSteps,
      goalStartTotalExerciseMinutes: goalStartTotalExerciseMinutes ?? this.goalStartTotalExerciseMinutes,
      battleVictoryCount: battleVictoryCount ?? this.battleVictoryCount,
      todayEvent: todayEvent ?? this.todayEvent,
      lastEventDate: lastEventDate ?? this.lastEventDate,
      consecutiveLoginDays: consecutiveLoginDays ?? this.consecutiveLoginDays,
      lastLoginDate: lastLoginDate ?? this.lastLoginDate,
      todayBattleCount: todayBattleCount ?? this.todayBattleCount,
      todayLoginCount: todayLoginCount ?? this.todayLoginCount,
      lastLoginTime: lastLoginTime ?? this.lastLoginTime,
      evolutionGrade: evolutionGrade ?? this.evolutionGrade,
    );
  }

  /// 레벨��에 필요한 경험치 (점진적 증가)
  static int getRequiredExpForLevel(int level) {
    if (level <= 5) return 80;
    if (level <= 10) return 120;
    if (level <= 15) return 160;
    if (level <= 20) return 200;
    if (level <= 25) return 250;
    return 300;
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

  /// 일일 항목만 리셋 (기간 누적 카운터는 유지)
  /// todayFeedCount, todaySleepHours는 기간 내 누적이므로 리셋하지 않음
  Pet resetDailyGoals() {
    return copyWith(
      todayFedMealSlots: 0,
      todayAlternativeFeedCount: 0,
      todayAlternativeSleepCount: 0,
      todayAlternativeExerciseCount: 0,
      todaySyncedSteps: 0,
      todaySyncedExerciseMinutes: 0,
      lastGoalResetDate: todayDateString,
    );
  }

  /// 목표 기간 전체 리셋
  /// 모든 목표 달성 또는 7일 초과 시 호출
  Pet resetGoalPeriod({bool completed = false}) {
    return copyWith(
      todayFeedCount: 0,
      todaySleepHours: 0,
      goalStartDate: todayDateString,
      goalStartTotalSteps: totalSteps,
      goalStartTotalExerciseMinutes: totalExerciseMinutes,
      goalStreakCount: completed ? goalStreakCount + 1 : 0,
    );
  }

  /// 모든 수치가 0인지 확인
  bool get isAllStatsZero => hunger == 0 && happiness == 0 && stamina == 0;

  /// 사망 조건 충족 여부 (모든 수치 0이 3일 이상 지속)
  bool get shouldDie {
    if (isDead) return false;
    if (!isAllStatsZero) return false;
    if (zeroStatStartDate == null) return false;
    try {
      final startDate = DateTime.parse(zeroStatStartDate!);
      final now = DateTime.now();
      return now.difference(startDate).inDays >= 5;
    } catch (e) {
      return false;
    }
  }

  /// 목표 기간 경과 일수
  int get goalDaysElapsed {
    if (goalStartDate.isEmpty) return 0;
    try {
      final startDate = DateTime.parse(goalStartDate);
      final now = DateTime.now();
      return now.difference(startDate).inDays;
    } catch (e) {
      return 0;
    }
  }

  /// 목표 기간 강제 리셋 필요 여부 (7일 초과)
  bool get needsGoalPeriodReset {
    return goalDaysElapsed > 7;
  }

  /// 기간 내 운동 걸음 수
  int get periodExerciseSteps => totalSteps - goalStartTotalSteps;

  /// 기간 내 운동 시간 (분)
  int get periodExerciseMinutes => totalExerciseMinutes - goalStartTotalExerciseMinutes;

  /// 사망 처리
  Pet die() {
    return Pet(
      id: id,
      name: name,
      hunger: hunger,
      happiness: happiness,
      stamina: stamina,
      level: level,
      exp: exp,
      evolutionStage: evolutionStage,
      lastUpdated: DateTime.now().millisecondsSinceEpoch,
      lastStatusDecayUpdated: lastStatusDecayUpdated,
      totalSteps: totalSteps,
      totalExerciseMinutes: totalExerciseMinutes,
      todaySyncedSteps: todaySyncedSteps,
      todaySyncedExerciseMinutes: todaySyncedExerciseMinutes,
      totalIdleHours: totalIdleHours,
      evolutionType: evolutionType,
      todayFeedCount: todayFeedCount,
      todayFedMealSlots: todayFedMealSlots,
      todaySleepHours: todaySleepHours,
      todayAlternativeFeedCount: todayAlternativeFeedCount,
      todayAlternativeSleepCount: todayAlternativeSleepCount,
      todayAlternativeExerciseCount: todayAlternativeExerciseCount,
      lastGoalResetDate: lastGoalResetDate,
      isDead: true,
      deathDate: DateTime.now().millisecondsSinceEpoch,
      zeroStatStartDate: zeroStatStartDate,
      resurrectCount: resurrectCount,
      goalStartDate: goalStartDate,
      goalStreakCount: goalStreakCount,
      goalStartTotalSteps: goalStartTotalSteps,
      goalStartTotalExerciseMinutes: goalStartTotalExerciseMinutes,
      battleVictoryCount: battleVictoryCount,
      todayEvent: todayEvent,
      lastEventDate: lastEventDate,
      consecutiveLoginDays: consecutiveLoginDays,
      lastLoginDate: lastLoginDate,
      todayBattleCount: todayBattleCount,
      todayLoginCount: todayLoginCount,
      lastLoginTime: lastLoginTime,
      evolutionGrade: evolutionGrade,
    );
  }

  /// 부활 처리 (부활 횟수에 따라 차등 회복)
  /// 1회: 50/50/50, 2회: 40/40/40, 3회+: 30/30/30 + 레벨 -1
  Pet resurrect() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final int recoveryAmount;
    final int levelPenalty;
    if (resurrectCount == 0) {
      recoveryAmount = 50;
      levelPenalty = 0;
    } else if (resurrectCount == 1) {
      recoveryAmount = 40;
      levelPenalty = 0;
    } else {
      recoveryAmount = 30;
      levelPenalty = 1;
    }
    return Pet(
      id: id,
      name: name,
      hunger: recoveryAmount,
      happiness: recoveryAmount,
      stamina: recoveryAmount,
      level: (level - levelPenalty).clamp(1, level),
      exp: exp,
      evolutionStage: evolutionStage,
      lastUpdated: now,
      lastStatusDecayUpdated: now,
      totalSteps: totalSteps,
      totalExerciseMinutes: totalExerciseMinutes,
      todaySyncedSteps: todaySyncedSteps,
      todaySyncedExerciseMinutes: todaySyncedExerciseMinutes,
      totalIdleHours: totalIdleHours,
      evolutionType: evolutionType,
      todayFeedCount: todayFeedCount,
      todayFedMealSlots: todayFedMealSlots,
      todaySleepHours: todaySleepHours,
      todayAlternativeFeedCount: todayAlternativeFeedCount,
      todayAlternativeSleepCount: todayAlternativeSleepCount,
      todayAlternativeExerciseCount: todayAlternativeExerciseCount,
      lastGoalResetDate: lastGoalResetDate,
      isDead: false,
      resurrectCount: resurrectCount + 1,
      goalStartDate: goalStartDate,
      goalStreakCount: goalStreakCount,
      goalStartTotalSteps: goalStartTotalSteps,
      goalStartTotalExerciseMinutes: goalStartTotalExerciseMinutes,
      battleVictoryCount: battleVictoryCount,
      todayEvent: todayEvent,
      lastEventDate: lastEventDate,
      consecutiveLoginDays: consecutiveLoginDays,
      lastLoginDate: lastLoginDate,
      todayBattleCount: todayBattleCount,
      todayLoginCount: todayLoginCount,
      lastLoginTime: lastLoginTime,
      evolutionGrade: evolutionGrade,
    );
  }

  /// zeroStatStartDate를 null로 클리어
  Pet clearZeroStatStartDate() {
    return Pet(
      id: id,
      name: name,
      hunger: hunger,
      happiness: happiness,
      stamina: stamina,
      level: level,
      exp: exp,
      evolutionStage: evolutionStage,
      lastUpdated: lastUpdated,
      lastStatusDecayUpdated: lastStatusDecayUpdated,
      totalSteps: totalSteps,
      totalExerciseMinutes: totalExerciseMinutes,
      todaySyncedSteps: todaySyncedSteps,
      todaySyncedExerciseMinutes: todaySyncedExerciseMinutes,
      totalIdleHours: totalIdleHours,
      evolutionType: evolutionType,
      todayFeedCount: todayFeedCount,
      todayFedMealSlots: todayFedMealSlots,
      todaySleepHours: todaySleepHours,
      todayAlternativeFeedCount: todayAlternativeFeedCount,
      todayAlternativeSleepCount: todayAlternativeSleepCount,
      todayAlternativeExerciseCount: todayAlternativeExerciseCount,
      lastGoalResetDate: lastGoalResetDate,
      isDead: isDead,
      deathDate: deathDate,
      resurrectCount: resurrectCount,
      goalStartDate: goalStartDate,
      goalStreakCount: goalStreakCount,
      goalStartTotalSteps: goalStartTotalSteps,
      goalStartTotalExerciseMinutes: goalStartTotalExerciseMinutes,
      battleVictoryCount: battleVictoryCount,
      todayEvent: todayEvent,
      lastEventDate: lastEventDate,
      consecutiveLoginDays: consecutiveLoginDays,
      lastLoginDate: lastLoginDate,
      todayBattleCount: todayBattleCount,
      todayLoginCount: todayLoginCount,
      lastLoginTime: lastLoginTime,
      evolutionGrade: evolutionGrade,
    );
  }
}
