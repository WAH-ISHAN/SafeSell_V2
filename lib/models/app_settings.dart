import 'package:hive/hive.dart';

part 'app_settings.g.dart';

@HiveType(typeId: 3)
class AppSettings extends HiveObject {
  @HiveField(0)
  bool lockEnabled;

  @HiveField(1)
  String lockMode; // 'biometric', 'pin', 'biometric_pin'

  @HiveField(2)
  bool stealthEnabled;

  @HiveField(3)
  bool screenProtectionEnabled;

  @HiveField(4)
  bool isPro;

  @HiveField(5)
  int clipboardClearSeconds; // 0 = disabled

  @HiveField(6)
  bool panicWipeEnabled;

  @HiveField(7)
  int failedAttempts;

  @HiveField(8)
  DateTime? lockoutUntil;

  @HiveField(9)
  int panicWipeThreshold; // default 10

  @HiveField(10)
  int lockAfterSeconds; // 0 = immediate on resume

  @HiveField(11)
  bool usbProtection; // true = require unlock before export/share

  @HiveField(12)
  String importMode; // 'move' or 'copy'

  AppSettings({
    this.lockEnabled = false,
    this.lockMode = 'biometric_pin',
    this.stealthEnabled = false,
    this.screenProtectionEnabled = true,
    this.isPro = false,
    this.clipboardClearSeconds = 30,
    this.panicWipeEnabled = false,
    this.failedAttempts = 0,
    this.lockoutUntil,
    this.panicWipeThreshold = 10,
    this.lockAfterSeconds = 0,
    this.usbProtection = true,
    this.importMode = 'move',
  });
}
