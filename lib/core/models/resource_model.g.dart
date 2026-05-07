// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'resource_model.dart';

class ResourceModelAdapter extends TypeAdapter<ResourceModel> {
  @override
  final int typeId = 0;

  @override
  ResourceModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ResourceModel(
      id: fields[0] as String,
      title: fields[1] as String,
      url: fields[2] as String,
      category: fields[3] as String,
      type: fields[4] as String,
      sourceName: fields[5] as String,
      thumbnail: fields[6] as String?,
      publishedAt: fields[7] as DateTime,
      description: fields[8] as String?,
      isBookmarked: fields[9] as bool,
      isRead: fields[10] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, ResourceModel obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.url)
      ..writeByte(3)
      ..write(obj.category)
      ..writeByte(4)
      ..write(obj.type)
      ..writeByte(5)
      ..write(obj.sourceName)
      ..writeByte(6)
      ..write(obj.thumbnail)
      ..writeByte(7)
      ..write(obj.publishedAt)
      ..writeByte(8)
      ..write(obj.description)
      ..writeByte(9)
      ..write(obj.isBookmarked)
      ..writeByte(10)
      ..write(obj.isRead);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ResourceModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;

  @override
  int get hashCode => typeId.hashCode;
}
