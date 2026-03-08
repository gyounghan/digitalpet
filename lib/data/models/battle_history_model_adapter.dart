import 'package:hive/hive.dart';
import 'battle_history_model.dart';

/// BattleHistoryModel Hive TypeAdapter
/// Hive 데이터베이스에 BattleHistoryModel을 저장하고 읽기 위한 어댑터
class BattleHistoryModelAdapter extends TypeAdapter<BattleHistoryModel> {
  @override
  final int typeId = 1;
  
  @override
  BattleHistoryModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    
    return BattleHistoryModel(
      id: fields[0] as String,
      date: fields[1] as int,
      isVictory: fields[2] as bool,
      expGained: fields[3] as int,
      steps: fields[4] as int,
      exerciseMinutes: fields[5] as int,
    );
  }
  
  @override
  void write(BinaryWriter writer, BattleHistoryModel obj) {
    writer
      ..writeByte(6) // 필드 개수
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.isVictory)
      ..writeByte(3)
      ..write(obj.expGained)
      ..writeByte(4)
      ..write(obj.steps)
      ..writeByte(5)
      ..write(obj.exerciseMinutes);
  }
  
  @override
  int get hashCode => typeId.hashCode;
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BattleHistoryModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
