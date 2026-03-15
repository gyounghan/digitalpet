import 'package:hive/hive.dart';
import '../../domain/entities/pet.dart';
import '../../domain/entities/evolution_type.dart';

/// 반려동물 데이터 모델
/// Domain의 Pet 엔티티를 확장하여 Hive 저장 및 JSON 직렬화 지원
///
/// Hive TypeId: 0
/// Hive Box 이름: 'pets'
@HiveType(typeId: 0)
class PetModel extends Pet {
  /// 반려동물 고유 ID
  /// Hive Box의 키로 사용됨
  @HiveField(0)
  @override
  final String id;

  /// 반려동물 이름
  @HiveField(1)
  @override
  final String name;

  /// Hive 필드 어노테이션
  @HiveField(2)
  @override
  final int hunger;

  @HiveField(3)
  @override
  final int happiness;

  @HiveField(4)
  @override
  final int stamina;

  @HiveField(5)
  @override
  final int level;

  @HiveField(6)
  @override
  final int exp;

  @HiveField(7)
  @override
  final int evolutionStage;

  @HiveField(8)
  @override
  final int lastUpdated;

  @HiveField(9)
  @override
  final int totalSteps;

  @HiveField(10)
  @override
  final int totalExerciseMinutes;

  @HiveField(17)
  @override
  final int todaySyncedSteps;

  @HiveField(18)
  @override
  final int todaySyncedExerciseMinutes;

  @HiveField(11)
  @override
  final int totalIdleHours;

  @HiveField(12)
  @override
  final EvolutionType? evolutionType;

  @HiveField(13)
  @override
  final int todayFeedCount;

  @HiveField(14)
  @override
  final int todayFedMealSlots;

  @HiveField(15)
  @override
  final int todaySleepHours;

  @HiveField(16)
  @override
  final String lastGoalResetDate;

  @HiveField(19)
  @override
  final int todayAlternativeFeedCount;

  @HiveField(20)
  @override
  final int todayAlternativeSleepCount;

  @HiveField(21)
  @override
  final int todayAlternativeExerciseCount;

  PetModel({
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
  }) : super(
         id: id,
         name: name,
         hunger: hunger,
         happiness: happiness,
         stamina: stamina,
         level: level,
         exp: exp,
         evolutionStage: evolutionStage,
         lastUpdated: lastUpdated,
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
       );

  /// JSON에서 PetModel 생성
  ///
  /// [json] JSON 맵 데이터
  ///
  /// 반환: PetModel 인스턴스
  factory PetModel.fromJson(Map<String, dynamic> json) {
    return PetModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? '펫',
      hunger: json['hunger'] as int,
      happiness: json['happiness'] as int,
      stamina: json['stamina'] as int,
      level: json['level'] as int,
      exp: json['exp'] as int,
      evolutionStage: json['evolutionStage'] as int,
      lastUpdated: json['lastUpdated'] as int,
      totalSteps: json['totalSteps'] as int? ?? 0,
      totalExerciseMinutes: json['totalExerciseMinutes'] as int? ?? 0,
      todaySyncedSteps: json['todaySyncedSteps'] as int? ?? 0,
      todaySyncedExerciseMinutes: json['todaySyncedExerciseMinutes'] as int? ?? 0,
      totalIdleHours: json['totalIdleHours'] as int? ?? 0,
      evolutionType: json['evolutionType'] != null
          ? EvolutionType.values.firstWhere(
              (e) => e.name == json['evolutionType'],
              orElse: () => EvolutionType.balanced,
            )
          : null,
      todayFeedCount: json['todayFeedCount'] as int? ?? 0,
      todayFedMealSlots: json['todayFedMealSlots'] as int? ?? 0,
      todaySleepHours: json['todaySleepHours'] as int? ?? 0,
      todayAlternativeFeedCount: json['todayAlternativeFeedCount'] as int? ?? 0,
      todayAlternativeSleepCount: json['todayAlternativeSleepCount'] as int? ?? 0,
      todayAlternativeExerciseCount: json['todayAlternativeExerciseCount'] as int? ?? 0,
      lastGoalResetDate: json['lastGoalResetDate'] as String? ?? '',
    );
  }

  /// PetModel을 JSON으로 변환
  ///
  /// 반환: JSON 맵 데이터
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'hunger': hunger,
      'happiness': happiness,
      'stamina': stamina,
      'level': level,
      'exp': exp,
      'evolutionStage': evolutionStage,
      'lastUpdated': lastUpdated,
      'totalSteps': totalSteps,
      'totalExerciseMinutes': totalExerciseMinutes,
      'todaySyncedSteps': todaySyncedSteps,
      'todaySyncedExerciseMinutes': todaySyncedExerciseMinutes,
      'totalIdleHours': totalIdleHours,
      'evolutionType': evolutionType?.name,
      'todayFeedCount': todayFeedCount,
      'todayFedMealSlots': todayFedMealSlots,
      'todaySleepHours': todaySleepHours,
      'todayAlternativeFeedCount': todayAlternativeFeedCount,
      'todayAlternativeSleepCount': todayAlternativeSleepCount,
      'todayAlternativeExerciseCount': todayAlternativeExerciseCount,
      'lastGoalResetDate': lastGoalResetDate,
    };
  }

  /// Domain Entity (Pet)에서 PetModel 생성
  ///
  /// [pet] Domain 엔티티
  ///
  /// 반환: PetModel 인스턴스
  factory PetModel.fromEntity(Pet pet) {
    return PetModel(
      id: pet.id,
      name: pet.name,
      hunger: pet.hunger,
      happiness: pet.happiness,
      stamina: pet.stamina,
      level: pet.level,
      exp: pet.exp,
      evolutionStage: pet.evolutionStage,
      lastUpdated: pet.lastUpdated,
      totalSteps: pet.totalSteps,
      totalExerciseMinutes: pet.totalExerciseMinutes,
      todaySyncedSteps: pet.todaySyncedSteps,
      todaySyncedExerciseMinutes: pet.todaySyncedExerciseMinutes,
      totalIdleHours: pet.totalIdleHours,
      evolutionType: pet.evolutionType,
      todayFeedCount: pet.todayFeedCount,
      todayFedMealSlots: pet.todayFedMealSlots,
      todaySleepHours: pet.todaySleepHours,
      todayAlternativeFeedCount: pet.todayAlternativeFeedCount,
      todayAlternativeSleepCount: pet.todayAlternativeSleepCount,
      todayAlternativeExerciseCount: pet.todayAlternativeExerciseCount,
      lastGoalResetDate: pet.lastGoalResetDate,
    );
  }

  /// PetModel을 Domain Entity로 변환
  ///
  /// 반환: Pet 엔티티
  Pet toEntity() {
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
    );
  }

  /// PetModel 복사본 생성
  ///
  /// 특정 필드만 변경하여 새로운 PetModel 인스턴스 반환
  @override
  PetModel copyWith({
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
    return PetModel(
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
}
