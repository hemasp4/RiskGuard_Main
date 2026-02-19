/// RiskGuard - Real-Time AI-Based Digital Risk Detection System
/// RiskGuard - AI-Powered Call Protection Application
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'core/services/whitelist_service.dart';
import 'core/services/api_service.dart';
import 'features/call_detection/providers/call_history_provider.dart';
import 'features/voice_analysis/providers/voice_analysis_provider.dart';
import 'features/message_analysis/providers/message_analysis_provider.dart';
import 'features/video_analysis/providers/video_analysis_provider.dart';
import 'features/risk_scoring/providers/overall_analysis_provider.dart';
import 'features/dashboard/screens/dashboard_screen.dart';
import 'features/voice_analysis/screens/voice_analysis_screen.dart';
import 'features/message_analysis/screens/message_analysis_screen.dart';
import 'features/video_analysis/screens/video_analysis_screen.dart';
import 'features/risk_scoring/screens/overall_analysis_screen.dart';
import 'features/contacts/screens/contacts_management_screen.dart';
import 'features/call_detection/screens/enhanced_call_history_screen.dart';
import 'features/contacts/screens/whitelist_screen.dart';
import 'features/settings/screens/protection_settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize core services
  await _initializeServices();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style for dark theme
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF1A1A2E),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const RiskGuardApp());
}

/// Initialize all core services
Future<void> _initializeServices() async {
  // Initialize whitelist service (Privacy Filter)
  await WhitelistService().init();

  // Initialize protection settings
  await ProtectionSettingsService().init();

  // Initialize API service
  await ApiService().init();
}

class RiskGuardApp extends StatelessWidget {
  const RiskGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CallHistoryProvider()),
        ChangeNotifierProvider(create: (_) => VoiceAnalysisProvider()),
        ChangeNotifierProvider(create: (_) => MessageAnalysisProvider()),
        ChangeNotifierProvider(create: (_) => VideoAnalysisProvider()),
        ChangeNotifierProvider(create: (_) => OverallAnalysisProvider()),
      ],
      child: MaterialApp(
        title: 'RiskGuard',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark,
        home: const DashboardScreen(),
        routes: {
          '/voice-analysis': (context) => const VoiceAnalysisScreen(),
          '/message-analysis': (context) => const MessageAnalysisScreen(),
          '/video-analysis': (context) => const VideoAnalysisScreen(),
          '/overall-analysis': (context) => const OverallAnalysisScreen(),
          '/contacts-management': (context) => const ContactsManagementScreen(),
          '/call-history': (context) => const EnhancedCallHistoryScreen(),
          '/whitelist': (context) => const WhitelistScreen(),
          '/protection-settings': (context) => const ProtectionSettingsScreen(),
        },
      ),
    );
  }
}
