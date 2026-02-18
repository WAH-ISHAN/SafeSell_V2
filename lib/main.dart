import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:go_router/go_router.dart';

import 'app/config.dart';
import 'app/routes.dart';
import 'app/theme.dart';

import 'models/audit_event.dart';
import 'models/app_settings.dart';
import 'models/vault_file.dart';
import 'models/registered_device.dart';

import 'security/key_manager.dart';
import 'services/ads_service.dart';
import 'services/connectivity_service.dart';

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // System UI
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: SafeShellTheme.bgDark,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
      );

      // Hive (local, synchronous-like, usually safe)
      await Hive.initFlutter();
      Hive.registerAdapter(VaultFileAdapter());
      Hive.registerAdapter(VaultModeAdapter());
      Hive.registerAdapter(AuditEventAdapter());
      Hive.registerAdapter(AppSettingsAdapter());
      Hive.registerAdapter(RegisteredDeviceAdapter());

      await Hive.openBox<VaultFile>('vault_files');
      await Hive.openBox<AuditEvent>('audit_events');
      await Hive.openBox<AppSettings>('app_settings_typed');
      await Hive.openBox('app_settings_box');

      // Start connectivity monitoring immediately
      ConnectivityService.instance.startMonitoring();

      // Disable runtime font fetching (Play Store compliance)
      GoogleFonts.config.allowRuntimeFetching = false;

      // Initialize Firebase non-blocking (app works offline / guest mode)
      _initFirebase();

      // Create .nomedia in vault directory (non-blocking)
      _ensureNomedia();

      runApp(const SafeShellApp());
    },
    (error, stack) {
      debugPrint('[SafeShell] Uncaught error: $error\n$stack');
    },
  );
}

Future<void> _initFirebase() async {
  try {
    await Firebase.initializeApp();

    if (AppConfig.appCheckEnabled) {
      await FirebaseAppCheck.instance.activate(
        androidProvider: AndroidProvider.playIntegrity,
      );
    }
  } catch (e) {
    debugPrint('[SafeShell] Firebase/AppCheck init failed: $e');
  }
}

/// Create .nomedia file in vault directory to prevent gallery from indexing encrypted files.
Future<void> _ensureNomedia() async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final vaultDir = Directory('${dir.path}/vault');
    if (!await vaultDir.exists()) {
      await vaultDir.create(recursive: true);
    }
    final nomedia = File('${vaultDir.path}/.nomedia');
    if (!await nomedia.exists()) {
      await nomedia.create();
    }
  } catch (e) {
    debugPrint('[SafeShell] .nomedia creation failed: $e');
  }
}

class SafeShellApp extends StatefulWidget {
  const SafeShellApp({super.key});

  @override
  State<SafeShellApp> createState() => _SafeShellAppState();
}

class _SafeShellAppState extends State<SafeShellApp> {
  late final GoRouter _router;
  final _keyManager = KeyManager();

  @override
  void initState() {
    super.initState();
    _router = createRouter(keyManager: _keyManager);

    // Defer Ads init to avoid blocking main thread / GPU surface issues
    if (AppConfig.adsEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Small delay to let first frame render
        Future.delayed(const Duration(milliseconds: 500), () {
          AdsService.init().catchError((e) {
            debugPrint('[SafeShell] Ads init failed: $e');
          });
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'SafeShell',
      debugShowCheckedModeBanner: false,
      theme: SafeShellTheme.darkTheme,
      routerConfig: _router,
    );
  }
}
