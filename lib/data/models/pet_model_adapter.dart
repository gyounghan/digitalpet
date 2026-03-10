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
      totalSteps: fields[9] as int? ?? 0,
      totalExerciseMinutes: fields[10] as int? ?? 0,
      totalIdleHours: fields[11] as int? ?? 0,
      evolutionType: fields[12] != null
          ? EvolutionType.values.firstWhere(
              (e) => e.name == fields[12],
              orElse: () => EvolutionType.balanced,
            )
          : null,
      todayFeedCount: fields[13] as int? ?? 0,
      todaySleepHours: fields[14] as int? ?? 0,
      lastGoalResetDate: fields[15] as String? ?? '',
    );
  }
  
  @override
  void write(BinaryWriter writer, PetModel obj) {
    // Hive에 데이터 쓰기
    // 필드 개수와 각 필드를 순서대로 저장
    writer
      ..writeByte(16) // 필드 개수 (id, name 포함)
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
      ..write(obj.todaySleepHours)
      ..writeByte(15)
      ..write(obj.lastGoalResetDate);
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
