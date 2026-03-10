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
  
  /// 누적 걸음 수
  /// 펫이 생성된 이후부터의 총 걸음 수
  final int totalSteps;
  
  /// 누적 운동 시간 (분)
  /// 펫이 생성된 이후부터의 총 운동 시간
  final int totalExerciseMinutes;
  
  /// 누적 미사용 시간 (시간)
  /// 펫이 생성된 이후부터의 총 미사용 시간
  final int totalIdleHours;
  
  /// 진화 방향 타입
  /// 누적 활동 패턴에 따라 결정되는 진화 방향 (null이면 아직 결정되지 않음)
  final EvolutionType? evolutionType;
  
  /// 오늘의 Feed 횟수 (일일 목표 추적)
  /// 식사 시간대에 Feed 액션을 수행한 횟수 (최대 3회)
  final int todayFeedCount;
  
  /// 오늘의 수면 시간 (시간, 일일 목표 추적)
  /// 오늘 0시부터 현재까지의 총 수면 시간
  final int todaySleepHours;
  
  /// 마지막 목표 리셋 날짜 (YYYY-MM-DD 형식)
  /// 날짜가 변경되면 todayFeedCount와 todaySleepHours를 리셋
  final String lastGoalResetDate;
  
  /// 펫의 현재 기분 상태
  /// hunger, happiness, stamina 값에 따라 자동 계산
  PetMood get mood {
    // 모든 수치가 90 이상이면 활기참 상태
    if (hunger >= 90 && happiness >= 90 && stamina >= 90) {
      return PetMood.energetic;
    }
    
    // 모든 수치가 80 이상이면 기쁨 상태
    if (hunger >= 80 && happiness >= 80 && stamina >= 80) {
      return PetMood.happy;
    }
    
    // 포만감이 90 이상이고 다른 수치도 60 이상이면 배부름 상태
    if (hunger >= 90 && happiness >= 60 && stamina >= 60) {
      return PetMood.full;
    }
    
    // 대부분의 수치가 70 이상이면 만족함 상태
    if ((hunger >= 70 && happiness >= 70) || 
        (hunger >= 70 && stamina >= 70) || 
        (happiness >= 70 && stamina >= 70)) {
      return PetMood.satisfied;
    }
    
    // 배고픔이 20 이하이면 배고픔 상태
    if (hunger <= 20) {
      return PetMood.hungry;
    }
    
    // 체력이 20 이하이면 피곤함 상태
    if (stamina <= 20) {
      return PetMood.tired;
    }
    
    // 체력이 30 이하이면 졸림 상태
    if (stamina <= 30) {
      return PetMood.sleepy;
    }
    
    // 행복도가 20 이하이면 불안함 상태
    if (happiness <= 20) {
      return PetMood.anxious;
    }
    
    // 행복도가 30 이하이면 지루함 상태
    if (happiness <= 30) {
      return PetMood.bored;
    }
    
    // 수치가 불균형할 때 (한 수치는 높고 다른 수치는 낮을 때) 불안함 상태
    final avg = (hunger + happiness + stamina) / 3;
    final maxDiff = [
      (hunger - avg).abs(),
      (happiness - avg).abs(),
      (stamina - avg).abs(),
    ].reduce((a, b) => a > b ? a : b);
    if (maxDiff > 40) {
      return PetMood.anxious;
    }
    
    // 그 외는 보통 상태
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
    this.totalSteps = 0,
    this.totalExerciseMinutes = 0,
    this.totalIdleHours = 0,
    this.evolutionType,
    this.todayFeedCount = 0,
    this.todaySleepHours = 0,
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
    int? totalSteps,
    int? totalExerciseMinutes,
    int? totalIdleHours,
    EvolutionType? evolutionType,
    int? todayFeedCount,
    int? todaySleepHours,
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
      totalSteps: totalSteps ?? this.totalSteps,
      totalExerciseMinutes: totalExerciseMinutes ?? this.totalExerciseMinutes,
      totalIdleHours: totalIdleHours ?? this.totalIdleHours,
      evolutionType: evolutionType ?? this.evolutionType,
      todayFeedCount: todayFeedCount ?? this.todayFeedCount,
      todaySleepHours: todaySleepHours ?? this.todaySleepHours,
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
      todaySleepHours: 0,
      lastGoalResetDate: todayDateString,
    );
  }
}
