import 'package:hive/hive.dart';
import 'pet_model.dart';
import '../../domain/entities/evolution_type.dart';

/// PetModel Hive TypeAdapter
/// Hive 데이터베이스에 PetModel을 저장하고 읽기 위한 어댑터
///
/// 사용법:
/// ```dart
/// Hive.registerAdapter(PetModelAdapter());
/// ```
class PetModelAdapter extends TypeAdapter<PetModel> {
  @override
  final int typeId = 0;

  @override
  PetModel read(BinaryReader reader) {
    // Hive에서 데이터 읽기
    // 각 필드를 순서대로 읽어 PetModel 생성
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };

    final isNewSchema = fields.containsKey(16);
    final todaySleepHours = isNewSchema
        ? (fields[15] as int? ?? 0)
        : (fields[14] as int? ?? 0);
    final lastGoalResetDate = isNewSchema
        ? (fields[16] as String? ?? '')
        : (fields[15] as String? ?? '');

    return PetModel(
      id: fields[0] as String,
      name: fields[1] as String? ?? '펫', // name 필드 추가 (기본값 '펫')
      hunger: fields[2] as int,
      happiness: fields[3] as int,
      stamina: fields[4] as int,
      level: fields[5] as int,
      exp: fields[6] as int,
      evolutionStage: fields[7] as int,
      lastUpdated: fields[8] as int,
      lastStatusDecayUpdated: fields[22] as int? ?? (fields[8] as int),
      totalSteps: fields[9] as int? ?? 0,
      totalExerciseMinutes: fields[10] as int? ?? 0,
      todaySyncedSteps: fields[17] as int? ?? 0,
      todaySyncedExerciseMinutes: fields[18] as int? ?? 0,
      totalIdleHours: fields[11] as int? ?? 0,
      evolutionType: fields[12] != null
          ? EvolutionType.values.firstWhere(
              (e) => e.name == fields[12],
              orElse: () => EvolutionType.balanced,
            )
          : null,
      todayFeedCount: fields[13] as int? ?? 0,
      todayFedMealSlots: isNewSchema ? (fields[14] as int? ?? 0) : 0,
      todaySleepHours: todaySleepHours,
      lastGoalResetDate: lastGoalResetDate,
      todayAlternativeFeedCount: fields[19] as int? ?? 0,
      todayAlternativeSleepCount: fields[20] as int? ?? 0,
      todayAlternativeExerciseCount: fields[21] as int? ?? 0,
      isDead: fields[23] as bool? ?? false,
      deathDate: fields[24] as int?,
      zeroStatStartDate: fields[25] as String?,
      resurrectCount: fields[26] as int? ?? 0,
      goalStartDate: fields[27] as String? ?? '',
      goalStreakCount: fields[28] as int? ?? 0,
      goalStartTotalSteps: fields[29] as int? ?? 0,
      goalStartTotalExerciseMinutes: fields[30] as int? ?? 0,
      battleVictoryCount: fields[31] as int? ?? 0,
      todayEvent: fields[32] as String? ?? '',
      lastEventDate: fields[33] as String? ?? '',
      consecutiveLoginDays: fields[34] as int? ?? 0,
      lastLoginDate: fields[35] as String? ?? '',
      todayBattleCount: fields[36] as int? ?? 0,
      todayLoginCount: fields[37] as int? ?? 0,
      lastLoginTime: fields[38] as int? ?? 0,
    );
  }

  @override
  void write(BinaryWriter writer, PetModel obj) {
    // Hive에 데이터 쓰기
    // 필드 개수와 각 필드를 순서대로 저장
    writer
      ..writeByte(39) // 필드 개수 (HiveField 0-38)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name) // name 필드 추가
      ..writeByte(2)
      ..write(obj.hunger)
      ..writeByte(3)
      ..write(obj.happiness)
      ..writeByte(4)
      ..write(obj.stamina)
      ..writeByte(5)
      ..write(obj.level)
      ..writeByte(6)
      ..write(obj.exp)
      ..writeByte(7)
      ..write(obj.evolutionStage)
      ..writeByte(8)
      ..write(obj.lastUpdated)
      ..writeByte(9)
      ..write(obj.totalSteps)
      ..writeByte(10)
      ..write(obj.totalExerciseMinutes)
      ..writeByte(11)
      ..write(obj.totalIdleHours)
      ..writeByte(12)
      ..write(obj.evolutionType?.name)
      ..writeByte(13)
      ..write(obj.todayFeedCount)
      ..writeByte(14)
      ..write(obj.todayFedMealSlots)
      ..writeByte(15)
      ..write(obj.todaySleepHours)
      ..writeByte(16)
      ..write(obj.lastGoalResetDate)
      ..writeByte(17)
      ..write(obj.todaySyncedSteps)
      ..writeByte(18)
      ..write(obj.todaySyncedExerciseMinutes)
      ..writeByte(19)
      ..write(obj.todayAlternativeFeedCount)
      ..writeByte(20)
      ..write(obj.todayAlternativeSleepCount)
      ..writeByte(21)
      ..write(obj.todayAlternativeExerciseCount)
      ..writeByte(22)
      ..write(obj.lastStatusDecayUpdated)
      ..writeByte(23)
      ..write(obj.isDead)
      ..writeByte(24)
      ..write(obj.deathDate)
      ..writeByte(25)
      ..write(obj.zeroStatStartDate)
      ..writeByte(26)
      ..write(obj.resurrectCount)
      ..writeByte(27)
      ..write(obj.goalStartDate)
      ..writeByte(28)
      ..write(obj.goalStreakCount)
      ..writeByte(29)
      ..write(obj.goalStartTotalSteps)
      ..writeByte(30)
      ..write(obj.goalStartTotalExerciseMinutes)
      ..writeByte(31)
      ..write(obj.battleVictoryCount)
      ..writeByte(32)
      ..write(obj.todayEvent)
      ..writeByte(33)
      ..write(obj.lastEventDate)
      ..writeByte(34)
      ..write(obj.consecutiveLoginDays)
      ..writeByte(35)
      ..write(obj.lastLoginDate)
      ..writeByte(36)
      ..write(obj.todayBattleCount)
      ..writeByte(37)
      ..write(obj.todayLoginCount)
      ..writeByte(38)
      ..write(obj.lastLoginTime);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PetModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
