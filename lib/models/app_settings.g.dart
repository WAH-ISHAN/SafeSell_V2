// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_settings.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AppSettingsAdapter extends TypeAdapter<AppSettings> {
  @override
  final int typeId = 3;

  @override
  AppSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AppSettings(
      lockEnabled: fields[0] as bool,
      lockMode: fields[1] as String,
      stealthEnabled: fields[2] as bool,
      screenProtectionEnabled: fields[3] as bool,
      isPro: fields[4] as bool,
      clipboardClearSeconds: fields[5] as int,
      panicWipeEnabled: fields[6] as bool,
      failedAttempts: fields[7] as int,
      lockoutUntil: fields[8] as DateTime?,
      panicWipeThreshold: fields[9] as int,
      lockAfterSeconds: fields[10] as int,
      usbProtection: fields[11] == null ? true : fields[11] as bool,
      importMode: fields[12] == null ? 'move' : fields[12] as String,
    );
  }

  @override
  void write(BinaryWriter writer, AppSettings obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.lockEnabled)
      ..writeByte(1)
      ..write(obj.lockMode)
      ..writeByte(2)
      ..write(obj.stealthEnabled)
      ..writeByte(3)
      ..write(obj.screenProtectionEnabled)
      ..writeByte(4)
      ..write(obj.isPro)
      ..writeByte(5)
      ..write(obj.clipboardClearSeconds)
      ..writeByte(6)
      ..write(obj.panicWipeEnabled)
      ..writeByte(7)
      ..write(obj.failedAttempts)
      ..writeByte(8)
      ..write(obj.lockoutUntil)
      ..writeByte(9)
      ..write(obj.panicWipeThreshold)
      ..writeByte(10)
      ..write(obj.lockAfterSeconds)
      ..writeByte(11)
      ..write(obj.usbProtection)
      ..writeByte(12)
      ..write(obj.importMode);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
