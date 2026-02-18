import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/app_settings.dart';
import '../security/key_manager.dart';
import '../ui/screens/splash_screen.dart';
import '../ui/screens/login_screen.dart';
import '../ui/screens/register_screen.dart';
import '../ui/screens/key_setup_screen.dart';
import '../ui/screens/calculator_screen.dart';
import '../ui/screens/shell_screen.dart';
import '../ui/screens/dashboard_screen.dart';
import '../ui/screens/vault_screen.dart';
import '../ui/screens/profile_screen.dart';
import '../ui/screens/settings_screen.dart';
import '../ui/screens/security_logs_screen.dart';
import '../ui/screens/backup_screen.dart';
import '../ui/screens/lock_screen.dart';
import '../ui/screens/subscription_screen.dart';
import '../ui/screens/viewer_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

/// Shell routes that require full auth + key + unlock.
const _shellRoutes = {
  '/dashboard',
  '/vault',
  '/profile',
  '/settings',
  '/security-logs',
  '/backup',
  '/subscription',
};

GoRouter createRouter({required KeyManager keyManager}) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/key-setup', builder: (_, __) => const KeySetupScreen()),
      GoRoute(
        path: '/calculator',
        builder: (_, __) => const CalculatorScreen(),
      ),
      GoRoute(path: '/lock', builder: (_, __) => const LockScreen()),
      // Protected Viewer — launched by Android ACTION_VIEW intent
      GoRoute(path: '/view', builder: (_, __) => const ViewerScreen()),
      GoRoute(
        path: '/subscription',
        builder: (_, __) => const SubscriptionScreen(),
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (_, state, child) => ShellScreen(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (_, __) => const DashboardScreen(),
          ),
          GoRoute(path: '/vault', builder: (_, __) => const VaultScreen()),
          GoRoute(
            path: '/profile',
            builder: (_, __) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (_, __) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/security-logs',
            builder: (_, __) => const SecurityLogsScreen(),
          ),
          GoRoute(path: '/backup', builder: (_, __) => const BackupScreen()),
        ],
      ),
    ],
    redirect: (context, state) async {
      final path = state.uri.path;

      // 1. Always allow splash (it shows loading UI only)
      if (path == '/splash') return null;

      // 2. Always allow calculator (stealth mode entry point)
      if (path == '/calculator') return null;

      // 2b. Always allow protected viewer (handles its own auth internally)
      if (path == '/view') return null;

      // 3. Check authentication
      final user = FirebaseAuth.instance.currentUser;
      final isLoggedIn = user != null;
      final isAuthRoute = path == '/login' || path == '/register';

      // Not logged in → must be on auth route
      if (!isLoggedIn && !isAuthRoute) return '/login';

      // Logged in but on auth route → advance through the chain
      if (!isLoggedIn && isAuthRoute) return null;

      // --- From here, user IS logged in ---

      // 4. Check key setup
      final hasKey = await keyManager.isSetup();
      if (!hasKey) {
        // Key not set up → must go to key-setup
        if (path == '/key-setup') return null;
        return '/key-setup';
      }

      // If on auth route and key exists, continue the chain
      if (isAuthRoute) {
        // Check if lock is needed before going to dashboard
        final needsLock = await _isLockRequired(keyManager);
        return needsLock ? '/lock' : '/dashboard';
      }

      // 5. Check lock status (key exists, user logged in)
      if (path == '/key-setup') {
        // Already set up, skip key-setup
        final needsLock = await _isLockRequired(keyManager);
        return needsLock ? '/lock' : '/dashboard';
      }

      // 6. For shell routes (dashboard, vault, etc.) — enforce unlock
      if (_shellRoutes.contains(path)) {
        final needsLock = await _isLockRequired(keyManager);
        if (needsLock) return '/lock';
        return null; // Allowed
      }

      // 7. Lock screen — only show if actually needed
      if (path == '/lock') {
        final needsLock = await _isLockRequired(keyManager);
        if (!needsLock) return '/dashboard';
        return null;
      }

      return null;
    },
  );
}

/// Check if the vault needs to be locked.
/// Lock is required when: lock is enabled AND the master key is NOT in memory.
Future<bool> _isLockRequired(KeyManager keyManager) async {
  try {
    final box = Hive.box<AppSettings>('app_settings_typed');
    final settings = box.get('settings') ?? AppSettings();
    if (!settings.lockEnabled) return false;
    // Lock is enabled — check if vault is currently unlocked in memory
    return !keyManager.isUnlocked;
  } catch (_) {
    return false;
  }
}
