import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/env.dart';
import 'core/constants/app_constants.dart';
import 'core/errors/error_reporting.dart';
import 'core/routes/app_router.dart';
import 'core/services/app_services.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/message_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Inter Tight',
    ], await rootBundle.loadString('assets/fonts/OFL.txt'));
  });
  installGlobalErrorHandlers();
  usePathUrlStrategy();

  if (!Env.isConfigured) {
    runApp(const _MissingConfigApp());
    return;
  }

  // Session persistence is on by default, so a refresh keeps the same
  // anonymous user (and therefore host ownership).
  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabasePublishableKey,
  );
  AppServices.register();
  runApp(const CrowdDjApp());
}

class CrowdDjApp extends StatelessWidget {
  const CrowdDjApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      routerDelegate: AppRouter.router.routerDelegate,
      routeInformationParser: AppRouter.router.routeInformationParser,
      routeInformationProvider: AppRouter.router.routeInformationProvider,
    );
  }
}

class _MissingConfigApp extends StatelessWidget {
  const _MissingConfigApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const MessageScreen(
        title: 'Backend not configured',
        detail: 'Run with: flutter run -d chrome --dart-define-from-file=env/dev.json',
      ),
    );
  }
}
