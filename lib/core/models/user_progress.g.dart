// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_progress.dart';

class UserProgressAdapter extends TypeAdapter<UserProgress> {
  @override
  final int typeId = 1;

  @override
  UserProgress read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserProgress(
      activeCategory: fields[0] as String,
      activeLevel: fields[1] as String,
      completedSteps: (fields[2] as Map).map(
        (k, v) => MapEntry(k as String, (v as List).cast<int>()),
      ),
      streakDays: fields[3] as int,
      lastActiveDate: fields[4] as DateTime?,
      totalXP: fields[5] as int,
      earnedBadges: (fields[6] as List).cast<String>(),
      dailyGoalMinutes: fields[7] as int,
      isPremium: fields[8] as bool,
      premiumExpiry: fields[9] as DateTime?,
      totalLessonsCompleted: fields[10] as int,
      lastInterstitialShown: fields[11] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, UserProgress obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.activeCategory)
      ..writeByte(1)
      ..write(obj.activeLevel)
      ..writeByte(2)
      ..write(obj.completedSteps)
      ..writeByte(3)
      ..write(obj.streakDays)
      ..writeByte(4)
      ..write(obj.lastActiveDate)
      ..writeByte(5)
      ..write(obj.totalXP)
      ..writeByte(6)
      ..write(obj.earnedBadges)
      ..writeByte(7)
      ..write(obj.dailyGoalMinutes)
      ..writeByte(8)
      ..write(obj.isPremium)
      ..writeByte(9)
      ..write(obj.premiumExpiry)
      ..writeByte(10)
      ..write(obj.totalLessonsCompleted)
      ..writeByte(11)
      ..write(obj.lastInterstitialShown);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProgressAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;

  @override
  int get hashCode => typeId.hashCode;
}
