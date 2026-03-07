/// Hive 관련 상수
/// Hive Box 이름, TypeId 등을 중앙에서 관리
class HiveConstants {
  HiveConstants._(); // private constructor
  
  /// PetModel Hive TypeId
  static const int petModelTypeId = 0;
  
  /// Pet 데이터 저장용 Hive Box 이름
  static const String petBoxName = 'pets';
  
  /// PhoneUsage 데이터 저장용 Hive Box 이름
  static const String phoneUsageBoxName = 'phone_usage';
}
