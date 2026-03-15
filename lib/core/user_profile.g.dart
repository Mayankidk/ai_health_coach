// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_profile.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UserProfileAdapter extends TypeAdapter<UserProfile> {
  @override
  final int typeId = 2;

  @override
  UserProfile read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserProfile(
      userId: fields[0] as String,
      age: fields[1] == null ? 30 : fields[1] as int,
      weight: fields[2] == null ? 70.0 : fields[2] as double,
      fitnessGoal: fields[3] == null ? 'General Health' : fields[3] as String,
      goals: fields[4] == null ? [] : (fields[4] as List).cast<String>(),
      fitnessLevel: fields[5] == null ? 'Beginner' : fields[5] as String,
      dietaryPreference: fields[6] == null ? 'None' : fields[6] as String,
      name: fields[7] == null ? 'User' : fields[7] as String?,
      dailyStepGoal: fields[8] == null ? 10000 : fields[8] as int,
      onboardingCompleted: fields[9] == null ? false : fields[9] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, UserProfile obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.userId)
      ..writeByte(1)
      ..write(obj.age)
      ..writeByte(2)
      ..write(obj.weight)
      ..writeByte(3)
      ..write(obj.fitnessGoal)
      ..writeByte(4)
      ..write(obj.goals)
      ..writeByte(5)
      ..write(obj.fitnessLevel)
      ..writeByte(6)
      ..write(obj.dietaryPreference)
      ..writeByte(7)
      ..write(obj.name)
      ..writeByte(8)
      ..write(obj.dailyStepGoal)
      ..writeByte(9)
      ..write(obj.onboardingCompleted);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfileAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
