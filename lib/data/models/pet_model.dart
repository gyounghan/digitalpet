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

  @HiveField(22)
  @override
  final int lastStatusDecayUpdated;

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

  @HiveField(23)
  @override
  final bool isDead;

  @HiveField(24)
  @override
  final int? deathDate;

  @HiveField(25)
  @override
  final String? zeroStatStartDate;

  @HiveField(26)
  @override
  final int resurrectCount;

  @HiveField(27)
  @override
  final String goalStartDate;

  @HiveField(28)
  @override
  final int goalStreakCount;

  @HiveField(29)
  @override
  final int goalStartTotalSteps;

  @HiveField(30)
  @override
  final int goalStartTotalExerciseMinutes;

  @HiveField(31)
  @override
  final int battleVictoryCount;

  @HiveField(32)
  @override
  final String todayEvent;

  @HiveField(33)
  @override
  final String lastEventDate;

  @HiveField(34)
  @override
  final int consecutiveLoginDays;

  @HiveField(35)
  @override
  final String lastLoginDate;

  @HiveField(36)
  @override
  final int todayBattleCount;

  @HiveField(37)
  @override
  final int todayLoginCount;

  @HiveField(38)
  @override
  final int lastLoginTime;

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
      lastStatusDecayUpdated: json['lastStatusDecayUpdated'] as int? ?? json['lastUpdated'] as int,
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
      isDead: json['isDead'] as bool? ?? false,
      deathDate: json['deathDate'] as int?,
      zeroStatStartDate: json['zeroStatStartDate'] as String?,
      resurrectCount: json['resurrectCount'] as int? ?? 0,
      goalStartDate: json['goalStartDate'] as String? ?? '',
      goalStreakCount: json['goalStreakCount'] as int? ?? 0,
      goalStartTotalSteps: json['goalStartTotalSteps'] as int? ?? 0,
      goalStartTotalExerciseMinutes: json['goalStartTotalExerciseMinutes'] as int? ?? 0,
      battleVictoryCount: json['battleVictoryCount'] as int? ?? 0,
      todayEvent: json['todayEvent'] as String? ?? '',
      lastEventDate: json['lastEventDate'] as String? ?? '',
      consecutiveLoginDays: json['consecutiveLoginDays'] as int? ?? 0,
      lastLoginDate: json['lastLoginDate'] as String? ?? '',
      todayBattleCount: json['todayBattleCount'] as int? ?? 0,
      todayLoginCount: json['todayLoginCount'] as int? ?? 0,
      lastLoginTime: json['lastLoginTime'] as int? ?? 0,
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
      'lastStatusDecayUpdated': lastStatusDecayUpdated,
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
      'isDead': isDead,
      'deathDate': deathDate,
      'zeroStatStartDate': zeroStatStartDate,
      'resurrectCount': resurrectCount,
      'goalStartDate': goalStartDate,
      'goalStreakCount': goalStreakCount,
      'goalStartTotalSteps': goalStartTotalSteps,
      'goalStartTotalExerciseMinutes': goalStartTotalExerciseMinutes,
      'battleVictoryCount': battleVictoryCount,
      'todayEvent': todayEvent,
      'lastEventDate': lastEventDate,
      'consecutiveLoginDays': consecutiveLoginDays,
      'lastLoginDate': lastLoginDate,
      'todayBattleCount': todayBattleCount,
      'todayLoginCount': todayLoginCount,
      'lastLoginTime': lastLoginTime,
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
      lastStatusDecayUpdated: pet.lastStatusDecayUpdated,
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
      isDead: pet.isDead,
      deathDate: pet.deathDate,
      zeroStatStartDate: pet.zeroStatStartDate,
      resurrectCount: pet.resurrectCount,
      goalStartDate: pet.goalStartDate,
      goalStreakCount: pet.goalStreakCount,
      goalStartTotalSteps: pet.goalStartTotalSteps,
      goalStartTotalExerciseMinutes: pet.goalStartTotalExerciseMinutes,
      battleVictoryCount: pet.battleVictoryCount,
      todayEvent: pet.todayEvent,
      lastEventDate: pet.lastEventDate,
      consecutiveLoginDays: pet.consecutiveLoginDays,
      lastLoginDate: pet.lastLoginDate,
      todayBattleCount: pet.todayBattleCount,
      todayLoginCount: pet.todayLoginCount,
      lastLoginTime: pet.lastLoginTime,
    );
  }

  /// PetModel�� Domain Entity로 변환
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
    );
  }
}
