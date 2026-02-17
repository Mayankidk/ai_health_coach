// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'health_log.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HealthLogAdapter extends TypeAdapter<HealthLog> {
  @override
  final int typeId = 4;

  @override
  HealthLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HealthLog(
      content: fields[0] as String,
      isActive: fields[1] as bool,
      createdAt: fields[2] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, HealthLog obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.content)
      ..writeByte(1)
      ..write(obj.isActive)
      ..writeByte(2)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HealthLogAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
