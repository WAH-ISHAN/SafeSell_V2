// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'registered_device.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RegisteredDeviceAdapter extends TypeAdapter<RegisteredDevice> {
  @override
  final int typeId = 10;

  @override
  RegisteredDevice read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RegisteredDevice(
      id: fields[0] as String,
      name: fields[1] as String,
      model: fields[2] as String,
      osVersion: fields[3] as String,
      platform: fields[4] as String,
      registeredAt: fields[5] as DateTime,
      lastSeenAt: fields[6] as DateTime,
      isTrusted: fields[7] as bool,
      isCurrentDevice: fields[8] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, RegisteredDevice obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.model)
      ..writeByte(3)
      ..write(obj.osVersion)
      ..writeByte(4)
      ..write(obj.platform)
      ..writeByte(5)
      ..write(obj.registeredAt)
      ..writeByte(6)
      ..write(obj.lastSeenAt)
      ..writeByte(7)
      ..write(obj.isTrusted)
      ..writeByte(8)
      ..write(obj.isCurrentDevice);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RegisteredDeviceAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
