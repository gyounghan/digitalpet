import 'evolution_type.dart';

/// 펫의 기분 상태 (6종 + 사망)
/// hunger, happiness, stamina 값에 따라 결정되는 펫의 현재 상태.
/// 사용자가 직관적으로 구분할 수 있도록 6종으로 압축.
enum PetMood {
  /// 행복 - 세 수치 모두 양호할 때
  happy,

  /// 보통 - 평범한 상태
  normal,

  /// 배고픔 - 포만감이 낮을 때
  hungry,

  /// 졸림 - 밤이거나 스태미나가 낮을 때
  sleepy,

  /// 지침 - 스태미나가 매우 낮을 때
  tired,

  /// 시무룩 - 행복도가 낮을 때
  sad,

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
  /// 내부적으로 todaySleepMinutes에서 파생되어 저장된다.
  final int todaySleepHours;

  /// 오늘의 수면 시간 (분, 정밀 추적용)
  /// 30분 단위 미사용 누적값. 60분 도달 시 todaySleepHours가 1 증가한다.
  /// hours로 환산할 때의 정밀도 손실을 막기 위해 별도 누적 저장.
  final int todaySleepMinutes;

  /// 오늘 수동 재우기(Sleep 버튼) 사용 횟수
  /// 일일 제한 추적 (자동 수면·대체 수면과 별개)
  final int todaySleepCount;

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

  /// 포만감 목표 누적 달성 횟수
  /// 일일 포만감 목표를 달성한 날 수 (감소 없음)
  final int feedAchievedCount;

  /// 수면 목표 누적 달성 횟수
  /// 일일 수면 목표를 달성한 날 수 (감소 없음)
  final int sleepAchievedCount;

  /// 운동 목표 누적 달성 횟수
  /// 일일 운동 목표를 달성한 날 수 (감소 없음)
  final int exerciseAchievedCount;

  /// 포만감 목표 마지막 달성 날짜 (YYYY-MM-DD)
  /// 홈 카드의 "오늘 달성" 표시용 (지급 게이트는 todayXxxAchievedCount가 담당)
  final String lastFeedAchievedDate;

  /// 수면 목표 마지막 달성 날짜 (YYYY-MM-DD)
  final String lastSleepAchievedDate;

  /// 운동 목표 마지막 달성 날짜 (YYYY-MM-DD)
  final String lastExerciseAchievedDate;

  /// 운동 목표 마지막 달성 시점의 누적 걸음 수
  /// 현재 운동 진행도 = totalSteps - lastExerciseGoalSteps
  final int lastExerciseGoalSteps;

  /// 운동 목표 마지막 달성 시점의 누적 운동 시간 (분)
  /// 현재 운동 진행도 = totalExerciseMinutes - lastExerciseGoalMinutes
  final int lastExerciseGoalMinutes;

  /// 마지막 활동 데이터(걸음/운동) 동기화 시각 (밀리초)
  /// retroactive 동기화 anchor — 이 시각 이후의 헬스 데이터를 추가로 fetch.
  /// 백그라운드 동기화가 실패해도 앱을 열 때 그 사이 활동량을 catch-up 한다.
  /// 0이면 최초 1회 동기화 (이후 currentTime으로 초기화).
  final int lastActivitySyncTime;

  /// 오늘 보상을 수령한 "세트" 개수 (포만감+수면+운동 모두 달성 = 1세트)
  /// 세트 반감 EXP 계산용 — 오늘 N번째 세트는 setExpBase >> N 부여.
  /// 자정에 resetDailyGoals로 0 리셋.
  final int todaySetExpClaimed;

  /// 누적 보상 지급이 완료된 세트 총 개수
  /// 세트 완성 총량(min(달성 카운트 3종))과 비교해 신규 세트를 판정.
  /// 자정에도 리셋하지 않는다(중복 지급 방지용 워터마크).
  final int totalSetsRewarded;

  /// 오늘 포만감 목표 달성 횟수 (하루 최대 3회 캡 판정용, 자정 리셋)
  final int todayFeedAchievedCount;

  /// 오늘 수면 목표 달성 횟수 (하루 최대 3회 캡 판정용, 자정 리셋)
  final int todaySleepAchievedCount;

  /// 오늘 운동 목표 달성 횟수 (하루 최대 3회 캡 판정용, 자정 리셋)
  final int todayExerciseAchievedCount;

  /// 펫의 현재 기분 상태 (6종)
  /// hunger(포만감), stamina(스태미나), happiness(행복) + 시간대로 자동 계산.
  ///
  /// ⚠️ 이 우선순위/임계값은 PetWidgetProvider.kt의 calculateMoodFromStats와
  /// 반드시 동일하게 유지해야 한다(홈↔위젯 상태 불일치 방지).
  ///
  /// 우선순위: 배고픔 → 지침 → 졸림 → 시무룩 → 행복 → 보통
  PetMood get mood {
    if (isDead) return PetMood.dead;

    final hour = DateTime.now().hour;
    final isNightTime = hour >= 22 || hour < 6;

    // 1) 포만감 부족 → 배고픔 (최우선 — 굶주림 경고)
    if (hunger <= 25) return PetMood.hungry;
    // 2) 스태미나 고갈 → 지침
    if (stamina <= 25) return PetMood.tired;
    // 3) 수면 신호 → 졸림 (밤에는 더 민감)
    if (isNightTime && stamina <= 60) return PetMood.sleepy;
    if (stamina <= 40) return PetMood.sleepy;
    // 4) 행복도 저하 → 시무룩
    if (happiness <= 35) return PetMood.sad;
    // 5) 세 수치 모두 양호 → 행복
    if (hunger >= 75 && happiness >= 70 && stamina >= 60) return PetMood.happy;
    // 6) 그 외 → 보통
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
    this.todaySleepMinutes = 0,
    this.todaySleepCount = 0,
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
    this.feedAchievedCount = 0,
    this.sleepAchievedCount = 0,
    this.exerciseAchievedCount = 0,
    this.lastFeedAchievedDate = '',
    this.lastSleepAchievedDate = '',
    this.lastExerciseAchievedDate = '',
    this.lastExerciseGoalSteps = 0,
    this.lastExerciseGoalMinutes = 0,
    this.lastActivitySyncTime = 0,
    this.todaySetExpClaimed = 0,
    this.totalSetsRewarded = 0,
    this.todayFeedAchievedCount = 0,
    this.todaySleepAchievedCount = 0,
    this.todayExerciseAchievedCount = 0,
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
    int? todaySleepMinutes,
    int? todaySleepCount,
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
    int? feedAchievedCount,
    int? sleepAchievedCount,
    int? exerciseAchievedCount,
    String? lastFeedAchievedDate,
    String? lastSleepAchievedDate,
    String? lastExerciseAchievedDate,
    int? lastExerciseGoalSteps,
    int? lastExerciseGoalMinutes,
    int? lastActivitySyncTime,
    int? todaySetExpClaimed,
    int? totalSetsRewarded,
    int? todayFeedAchievedCount,
    int? todaySleepAchievedCount,
    int? todayExerciseAchievedCount,
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
      todaySleepMinutes: todaySleepMinutes ?? this.todaySleepMinutes,
      todaySleepCount: todaySleepCount ?? this.todaySleepCount,
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
      feedAchievedCount: feedAchievedCount ?? this.feedAchievedCount,
      sleepAchievedCount: sleepAchievedCount ?? this.sleepAchievedCount,
      exerciseAchievedCount: exerciseAchievedCount ?? this.exerciseAchievedCount,
      lastFeedAchievedDate: lastFeedAchievedDate ?? this.lastFeedAchievedDate,
      lastSleepAchievedDate: lastSleepAchievedDate ?? this.lastSleepAchievedDate,
      lastExerciseAchievedDate:
          lastExerciseAchievedDate ?? this.lastExerciseAchievedDate,
      lastExerciseGoalSteps:
          lastExerciseGoalSteps ?? this.lastExerciseGoalSteps,
      lastExerciseGoalMinutes:
          lastExerciseGoalMinutes ?? this.lastExerciseGoalMinutes,
      lastActivitySyncTime:
          lastActivitySyncTime ?? this.lastActivitySyncTime,
      todaySetExpClaimed: todaySetExpClaimed ?? this.todaySetExpClaimed,
      totalSetsRewarded: totalSetsRewarded ?? this.totalSetsRewarded,
      todayFeedAchievedCount:
          todayFeedAchievedCount ?? this.todayFeedAchievedCount,
      todaySleepAchievedCount:
          todaySleepAchievedCount ?? this.todaySleepAchievedCount,
      todayExerciseAchievedCount:
          todayExerciseAchievedCount ?? this.todayExerciseAchievedCount,
    );
  }

  /// 현재 운동 목표 진행 중인 걸음 수 (마지막 달성 이후 증가분)
  int get exerciseProgressSteps =>
      (totalSteps - lastExerciseGoalSteps).clamp(0, 1 << 30);

  /// 현재 운동 목표 진행 중인 운동 시간 (분)
  int get exerciseProgressMinutes =>
      (totalExerciseMinutes - lastExerciseGoalMinutes).clamp(0, 1 << 30);

  // ── 전투 스탯 (영구 성장 골격 + 컨디션 보정) ─────────────────
  // "잘 키운 질"이 전투력이 되도록: 레벨·누적 세트·누적 걸음이 영구 골격을
  // 만들고(decay되지 않음), 현재 컨디션(happiness/stamina/hunger)은 그 위에
  // ±20% 보정만 한다. 전투 유스케이스와 도감 표시가 이 getter를 공유한다.

  /// 진화 단계 전투 보너스
  static const Map<int, int> battleStageBonus = {1: 0, 2: 2, 3: 4, 4: 7};

  /// 누적 세트 전투 보너스 (5세트당 +1, 최대 +15) — ATK·DEF 영구 성장
  static const int setBattleBonusPer = 5;
  static const int setBattleBonusCap = 15;

  /// 누적 걸음 전투 보너스 (5000보당 +1, 최대 +20) — HP 영구 성장
  static const int stepBattleBonusPer = 5000;
  static const int stepBattleBonusCap = 20;

  /// ATK·DEF 기본 상수 (상대 AI 베이스와 대등)
  static const int battleFlatBase = 5;

  /// 컨디션 보정 최대 폭 (±20%)
  static const double conditionModRange = 0.2;

  /// 종별 [ATK, DEF, HP] 보너스
  List<int> get _speciesBattleBonus {
    switch (evolutionType) {
      case EvolutionType.bird:
        return const [3, 0, 0];
      case EvolutionType.snake:
        return const [0, 2, 10];
      case EvolutionType.tiger:
        return const [2, 2, 0];
      case EvolutionType.turtle:
        return const [0, 3, 10];
      case null:
        return const [0, 0, 0];
    }
  }

  int get _setBattleBonus =>
      (totalSetsRewarded ~/ setBattleBonusPer).clamp(0, setBattleBonusCap);

  int get _stepBattleBonus =>
      (totalSteps ~/ stepBattleBonusPer).clamp(0, stepBattleBonusCap);

  /// 컨디션(0~100, 50 중립) → ±conditionModRange 보정 계수
  double _conditionMod(int stat) =>
      ((stat - 50) / 50).clamp(-1.0, 1.0) * conditionModRange;

  /// 공격력 = (5 + 레벨 + 누적세트 + 진화단계 + 종) × (1 ± 행복 보정)
  int get battleAtk {
    final stage = battleStageBonus[evolutionStage] ?? 0;
    final base =
        battleFlatBase + level + _setBattleBonus + stage + _speciesBattleBonus[0];
    return (base * (1 + _conditionMod(happiness))).round().clamp(1, 1 << 30);
  }

  /// 방어력 = (5 + 레벨 + 누적세트 + 진화단계 + 종) × (1 ± 스태미나 보정)
  int get battleDef {
    final stage = battleStageBonus[evolutionStage] ?? 0;
    final base =
        battleFlatBase + level + _setBattleBonus + stage + _speciesBattleBonus[1];
    return (base * (1 + _conditionMod(stamina))).round().clamp(1, 1 << 30);
  }

  /// 체력 = (50 + 레벨×2 + 누적걸음 + 종) × (1 ± 포만감 보정)
  int get battleHp {
    final base =
        50 + level * 2 + _stepBattleBonus + _speciesBattleBonus[2];
    return (base * (1 + _conditionMod(hunger))).round().clamp(1, 1 << 30);
  }

  /// 카테고리 목표 티어 (달성 10회마다 1단계)
  int get feedTier => feedAchievedCount ~/ 10;
  int get sleepTier => sleepAchievedCount ~/ 10;
  int get exerciseTier => exerciseAchievedCount ~/ 10;

  /// 일반종(normal 성장기·성숙기) 개체 색 변이(0~3) — 육성 스타일 우세 축에서
  /// 파생. 0 활동형 · 1 휴식형 · 2 미식형 · 3 전투형.
  int get colorVariant {
    final scores = <double>[
      totalSteps / 2000.0 + totalExerciseMinutes / 10.0,
      sleepAchievedCount + totalIdleHours / 6.0,
      feedAchievedCount.toDouble(),
      battleVictoryCount.toDouble(),
    ];
    var best = 0;
    for (var i = 1; i < scores.length; i++) {
      if (scores[i] > scores[best]) best = i;
    }
    return best;
  }

  /// 다음 티어까지 남은 달성 횟수
  int get feedRemainingToNextTier => 10 - (feedAchievedCount % 10);
  int get sleepRemainingToNextTier => 10 - (sleepAchievedCount % 10);
  int get exerciseRemainingToNextTier => 10 - (exerciseAchievedCount % 10);

  /// 레벨에 필요한 경험치 (RPG 후반 가파른 곡선)
  ///
  /// 일일 캡(카테고리당 하루 최대 3회 EXP)을 기준으로 한 페이스 가이드:
  ///   보통 사용자 기준 카테고리 3개 × 1회 × 20 EXP = 60 EXP/일
  ///   (열심히 하면 카테고리당 최대 3회 × 20 = 180 EXP/일 + 세트 보너스)
  /// - Lv  1 →  2 : 50 EXP   (1일)
  /// - Lv  5 → 도달 ~ 4일
  /// - Lv 10 → 도달 ~ 12일
  /// - Lv 15 → 도달 ~ 28일 (1개월)
  /// - Lv 20 → 도달 ~ 58일 (2개월)
  /// - Lv 25 → 도달 ~ 100일
  /// - Lv 30 → 도달 ~ 170일
  static int getRequiredExpForLevel(int level) {
    if (level <= 3) return 50;
    if (level <= 7) return 100;
    if (level <= 12) return 200;
    if (level <= 17) return 350;
    if (level <= 22) return 550;
    if (level <= 27) return 800;
    return 1100;
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

  /// 일일 항목 리셋 (자정 넘어간 경우 호출)
  ///
  /// 목표 진행도(todayFeedCount, todaySleepHours/Minutes)는 달성 시에만
  /// 차감되므로 일일 리셋 대상이 아니다. 아래는 날짜가 바뀌어야 리셋되는
  /// 보조 카운터들뿐이다.
  ///
  /// todayEvent는 오늘 부여된 것(lastEventDate == 오늘)만 유지 —
  /// 어제 이벤트(예: adventure 배틀 EXP 2배)가 자정 이월 적용되는 것을 방지.
  /// 새 이벤트는 LoginBonusUseCase가 새 날 첫 접속 시 추첨한다.
  Pet resetDailyGoals() {
    return copyWith(
      todayFedMealSlots: 0,
      todaySleepCount: 0,
      todayAlternativeFeedCount: 0,
      todayAlternativeSleepCount: 0,
      todayAlternativeExerciseCount: 0,
      todaySyncedSteps: 0,
      todaySyncedExerciseMinutes: 0,
      todaySetExpClaimed: 0,
      todayBattleCount: 0,
      todayFeedAchievedCount: 0,
      todaySleepAchievedCount: 0,
      todayExerciseAchievedCount: 0,
      todayEvent: lastEventDate == todayDateString ? todayEvent : '',
      lastGoalResetDate: todayDateString,
    );
  }

  /// 모든 수치가 0인지 확인
  bool get isAllStatsZero => hunger == 0 && happiness == 0 && stamina == 0;

  /// 사망 조건 충족 여부 (모든 수치 0이 5일 이상 지속)
  /// CheckPetDeathUseCase.deathThresholdDays와 동일해야 한다
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

  /// 목표 기간 강제 리셋 필요 여부 (더 이상 주간 리셋을 사용하지 않음)
  bool get needsGoalPeriodReset => false;

  /// 기간 내 운동 걸음 수 (deprecated, 호환용)
  int get periodExerciseSteps => totalSteps - goalStartTotalSteps;

  /// 기간 내 운동 시간 (분, deprecated, 호환용)
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
      todaySleepMinutes: todaySleepMinutes,
      todaySleepCount: todaySleepCount,
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
      feedAchievedCount: feedAchievedCount,
      sleepAchievedCount: sleepAchievedCount,
      exerciseAchievedCount: exerciseAchievedCount,
      lastFeedAchievedDate: lastFeedAchievedDate,
      lastSleepAchievedDate: lastSleepAchievedDate,
      lastExerciseAchievedDate: lastExerciseAchievedDate,
      lastExerciseGoalSteps: lastExerciseGoalSteps,
      lastExerciseGoalMinutes: lastExerciseGoalMinutes,
      lastActivitySyncTime: lastActivitySyncTime,
      todaySetExpClaimed: todaySetExpClaimed,
      totalSetsRewarded: totalSetsRewarded,
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
      todaySleepMinutes: todaySleepMinutes,
      todaySleepCount: todaySleepCount,
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
      feedAchievedCount: feedAchievedCount,
      sleepAchievedCount: sleepAchievedCount,
      exerciseAchievedCount: exerciseAchievedCount,
      lastFeedAchievedDate: lastFeedAchievedDate,
      lastSleepAchievedDate: lastSleepAchievedDate,
      lastExerciseAchievedDate: lastExerciseAchievedDate,
      lastExerciseGoalSteps: lastExerciseGoalSteps,
      lastExerciseGoalMinutes: lastExerciseGoalMinutes,
      lastActivitySyncTime: lastActivitySyncTime,
      todaySetExpClaimed: todaySetExpClaimed,
      totalSetsRewarded: totalSetsRewarded,
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
      todaySleepMinutes: todaySleepMinutes,
      todaySleepCount: todaySleepCount,
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
      feedAchievedCount: feedAchievedCount,
      sleepAchievedCount: sleepAchievedCount,
      exerciseAchievedCount: exerciseAchievedCount,
      lastFeedAchievedDate: lastFeedAchievedDate,
      lastSleepAchievedDate: lastSleepAchievedDate,
      lastExerciseAchievedDate: lastExerciseAchievedDate,
      lastExerciseGoalSteps: lastExerciseGoalSteps,
      lastExerciseGoalMinutes: lastExerciseGoalMinutes,
      lastActivitySyncTime: lastActivitySyncTime,
      todaySetExpClaimed: todaySetExpClaimed,
      totalSetsRewarded: totalSetsRewarded,
    );
  }
}
