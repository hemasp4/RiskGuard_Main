import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/light_theme.dart';
import 'core/theme/app_theme_provider.dart';
import 'core/theme/app_colors.dart';
import 'core/services/scan_history_provider.dart';
import 'core/services/realtime_protection_provider.dart';
import 'core/services/user_settings_provider.dart';
import 'screens/app_initializer.dart';
import 'screens/voice/voice_analysis_screen.dart';
import 'screens/verification/message_verification_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive for cross-platform local storage
  await Hive.initFlutter();

  // Set system UI overlay style for dark mode by default
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.darkBackground,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => ScanHistoryProvider()),
        ChangeNotifierProvider(create: (_) => RealtimeProtectionProvider()),
        ChangeNotifierProvider(create: (_) => UserSettingsProvider()),
      ],
      child: const RiskGuardApp(),
    ),
  );
}

class RiskGuardApp extends StatefulWidget {
  const RiskGuardApp({super.key});

  @override
  State<RiskGuardApp> createState() => _RiskGuardAppState();
}

class _RiskGuardAppState extends State<RiskGuardApp> {
  @override
  void initState() {
    super.initState();
    // Load persisted state after the widget tree is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ScanHistoryProvider>().loadHistory();
      context.read<RealtimeProtectionProvider>().loadState();
      context.read<UserSettingsProvider>().init();
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    // Update system UI based on theme
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: themeProvider.isDarkMode
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarColor: themeProvider.isDarkMode
            ? AppColors.darkBackground
            : LightColors.lightBackground,
        systemNavigationBarIconBrightness: themeProvider.isDarkMode
            ? Brightness.light
            : Brightness.dark,
      ),
    );

    return MaterialApp(
      title: 'RiskGuard',
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.themeMode,
      theme: AppLightTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: const AppInitializer(),
      routes: {
        '/voice': (context) => const VoiceAnalysisScreen(),
        '/verification': (context) => const MessageVerificationScreen(),
      },
    );
  }
}
