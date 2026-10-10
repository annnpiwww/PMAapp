import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/constants/app_theme.dart';
import 'core/services/theme_service.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/submission_repository.dart';
import 'data/repositories/template_repository.dart';
import 'data/services/storage_service.dart';
import 'data/services/secure_time_service.dart';
import 'data/services/photo_cleanup_service.dart';
import 'data/services/google_sheets_service.dart';
import 'data/services/notification_service.dart';
import 'features/splash/screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Kunci paten Portrait (tidak auto-rotate ke landscape)
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Fast Startup: Hanya init storage lokal yang blocking untuk frame pertama
  try {
    await StorageService.init();
    ThemeService.init();
  } catch (_) {}

  // Run app langsung agar splash & UI tampil instan tanpa lag
  runApp(const PmaApp());

  // Background non-blocking inits (Repository, Network Time Sync, Auto-clean temporary photos, Flush GSheet offline queue)
  unawaited(Future.wait([
    TemplateRepository.instance.init(),
    SubmissionRepository.instance.init(),
    AuthRepository.instance.init(),
    SecureTimeService.syncNetworkTime(),
    PhotoCleanupService.cleanOldPhotos(maxDays: 7),
    GoogleSheetsService.flushPendingQueue(),
    NotificationService.instance.init(),
  ]));
}

class PmaApp extends StatelessWidget {
  const PmaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeModeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp(
          title: 'PMA App',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: currentMode,
          home: const SplashScreen(),
        );
      },
    );
  }
}
