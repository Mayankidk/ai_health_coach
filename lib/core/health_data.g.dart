// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'health_data.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HealthDataAdapter extends TypeAdapter<HealthData> {
  @override
  final int typeId = 3;

  @override
  HealthData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HealthData(
      steps: fields[0] as int,
      sleepMinutes: fields[1] as int,
      activeEnergyBurned: fields[2] as double?,
      hrv: fields[3] as double?,
    );
  }

  @override
  void write(BinaryWriter writer, HealthData obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.steps)
      ..writeByte(1)
      ..write(obj.sleepMinutes)
      ..writeByte(2)
      ..write(obj.activeEnergyBurned)
      ..writeByte(3)
      ..write(obj.hrv);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HealthDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
