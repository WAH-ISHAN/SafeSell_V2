// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audit_event.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AuditEventAdapter extends TypeAdapter<AuditEvent> {
  @override
  final int typeId = 2;

  @override
  AuditEvent read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AuditEvent(
      id: fields[0] as String,
      timestamp: fields[1] as DateTime,
      type: fields[2] as String,
      payload: fields[3] as String,
      eventHash: fields[4] as String,
      prevHash: fields[5] as String,
    );
  }

  @override
  void write(BinaryWriter writer, AuditEvent obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.timestamp)
      ..writeByte(2)
      ..write(obj.type)
      ..writeByte(3)
      ..write(obj.payload)
      ..writeByte(4)
      ..write(obj.eventHash)
      ..writeByte(5)
      ..write(obj.prevHash);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuditEventAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
