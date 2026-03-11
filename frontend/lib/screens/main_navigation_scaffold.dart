import 'package:flutter/material.dart';
import 'package:risk_guard/core/theme/app_colors.dart';
import 'package:risk_guard/screens/home/home_screen.dart';
import 'package:risk_guard/screens/history/history_screen.dart';
import 'package:risk_guard/screens/voice/voice_analysis_screen.dart';
import 'package:risk_guard/screens/image_recognition/image_recognition_screen.dart';
import 'package:risk_guard/screens/profile/profile_screen.dart';
import 'package:risk_guard/widgets/custom_bottom_nav.dart';

/// Main navigation scaffold with persistent bottom navbar
class MainNavigationScaffold extends StatefulWidget {
  const MainNavigationScaffold({super.key});

  @override
  State<MainNavigationScaffold> createState() => _MainNavigationScaffoldState();
}

class _MainNavigationScaffoldState extends State<MainNavigationScaffold> {
  int _currentIndex = 2;

  // All screens that can be navigated to
  final List<Widget> _screens = const [
    HistoryScreen(),
    VoiceAnalysisScreen(),
    HomeScreen(),
    ImageRecognitionScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: Stack(
        children: [
          // Main content with smooth transitions
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeInOut,
            switchOutCurve: Curves.easeInOut,
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.05, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: KeyedSubtree(
              key: ValueKey<int>(_currentIndex),
              child: _screens[_currentIndex],
            ),
          ),

          // Persistent bottom navigation
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: CustomBottomNav(
              currentIndex: _currentIndex,
              onTap: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}
