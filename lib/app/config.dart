/// Feature flags and app configuration.
class AppConfig {
  /// Whether ads are enabled. Set to false to disable all ad loading.
  static const bool adsEnabled = true;

  /// Whether App Check enforcement is enabled.
  static const bool appCheckEnabled = true;

  /// Whether guest (offline-only) mode is allowed.
  static const bool guestModeEnabled = true;

  /// Max failed login attempts before cooldown.
  static const int maxLoginAttempts = 5;
}
