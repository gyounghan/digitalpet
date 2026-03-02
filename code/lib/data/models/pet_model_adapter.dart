import 'package:hive/hive.dart';
import 'pet_model.dart';

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
      hunger: fields[1] as int,
      happiness: fields[2] as int,
      stamina: fields[3] as int,
      level: fields[4] as int,
      exp: fields[5] as int,
      evolutionStage: fields[6] as int,
      lastUpdated: fields[7] as int,
    );
  }
  
  @override
  void write(BinaryWriter writer, PetModel obj) {
    // Hive에 데이터 쓰기
    // 필드 개수와 각 필드를 순서대로 저장
    writer
      ..writeByte(8) // 필드 개수 (id 포함)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.hunger)
      ..writeByte(2)
      ..write(obj.happiness)
      ..writeByte(3)
      ..write(obj.stamina)
      ..writeByte(4)
      ..write(obj.level)
      ..writeByte(5)
      ..write(obj.exp)
      ..writeByte(6)
      ..write(obj.evolutionStage)
      ..writeByte(7)
      ..write(obj.lastUpdated);
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
