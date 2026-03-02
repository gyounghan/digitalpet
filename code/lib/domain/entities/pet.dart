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
  
  Pet({
    required this.id,
    required this.hunger,
    required this.happiness,
    required this.stamina,
    required this.level,
    required this.exp,
    required this.evolutionStage,
    required this.lastUpdated,
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
    );
  }
}
