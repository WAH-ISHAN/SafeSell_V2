// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vault_file.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class VaultFileAdapter extends TypeAdapter<VaultFile> {
  @override
  final int typeId = 1;

  @override
  VaultFile read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return VaultFile(
      id: fields[0] as String,
      name: fields[1] as String,
      type: fields[2] as String,
      size: fields[3] as int,
      createdAt: fields[4] as DateTime,
      encPath: fields[5] as String?,
      uri: fields[6] as String?,
      mode: fields[7] as VaultMode,
      category: fields[8] as String,
    );
  }

  @override
  void write(BinaryWriter writer, VaultFile obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.type)
      ..writeByte(3)
      ..write(obj.size)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.encPath)
      ..writeByte(6)
      ..write(obj.uri)
      ..writeByte(7)
      ..write(obj.mode)
      ..writeByte(8)
      ..write(obj.category);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VaultFileAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class VaultModeAdapter extends TypeAdapter<VaultMode> {
  @override
  final int typeId = 0;

  @override
  VaultMode read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return VaultMode.private;
      case 1:
        return VaultMode.galleryProtected;
      default:
        return VaultMode.private;
    }
  }

  @override
  void write(BinaryWriter writer, VaultMode obj) {
    switch (obj) {
      case VaultMode.private:
        writer.writeByte(0);
        break;
      case VaultMode.galleryProtected:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VaultModeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
