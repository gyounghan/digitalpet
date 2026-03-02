/// 유효성 검사 유틸리티
/// Pet 모델의 값 범위 검증 등에 사용
class Validators {
  Validators._(); // private constructor
  
  /// 값이 0~100 범위 내에 있는지 확인
  /// 
  /// [value] 검증할 값
  /// 
  /// 반환: 유효하면 true, 아니면 false
  static bool isValidPercentage(int value) {
    return value >= 0 && value <= 100;
  }
  
  /// 배고픔 값 유효성 검사
  /// 
  /// [hunger] 배고픔 수치
  /// 
  /// 반환: 유효하면 true, 아니면 false
  static bool isValidHunger(int hunger) {
    return isValidPercentage(hunger);
  }
  
  /// 행복도 값 유효성 검사
  /// 
  /// [happiness] 행복도 수치
  /// 
  /// 반환: 유효하면 true, 아니면 false
  static bool isValidHappiness(int happiness) {
    return isValidPercentage(happiness);
  }
  
  /// 체력 값 유효성 검사
  /// 
  /// [stamina] 체력 수치
  /// 
  /// 반환: 유효하면 true, 아니면 false
  static bool isValidStamina(int stamina) {
    return isValidPercentage(stamina);
  }
}
