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
}

/// 반려동물 엔티티
/// Domain 레이어의 순수 Dart 클래스로, 비즈니스 로직의 핵심 모델
/// Flutter나 외부 패키지에 의존하지 않는 순수 Dart 클래스
class Pet {
  /// 반려동물 고유 ID
  final String id;
  
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
  
  /// 펫의 현재 기분 상태
  /// hunger, happiness, stamina 값에 따라 자동 계산
  PetMood get mood {
    // 배고픔이 30 이하이면 배고픔 상태
    if (hunger <= 30) {
      return PetMood.hungry;
    }
    
    // 체력이 30 이하이면 졸림 상태
    if (stamina <= 30) {
      return PetMood.sleepy;
    }
    
    // 행복도가 30 이하이면 지루함 상태
    if (happiness <= 30) {
      return PetMood.bored;
    }
    
    // 모든 수치가 70 이상이면 기쁨 상태
    if (hunger >= 70 && happiness >= 70 && stamina >= 70) {
      return PetMood.happy;
    }
    
    // 그 외는 보통 상태
    return PetMood.normal;
  }
  
  Pet({
    required this.id,
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
  });
  
  /// Pet 객체 복사본 생성
  /// 특정 필드만 변경하여 새로운 Pet 인스턴스 반환
  Pet copyWith({
    String? id,
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
  }) {
    return Pet(
      id: id ?? this.id,
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
    );
  }
}
