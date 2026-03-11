import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:risk_guard/screens/onboarding/permission_request_screen.dart';
import 'package:risk_guard/screens/main_navigation_scaffold.dart';

/// Wrapper screen that shows permission request on first launch
class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  bool _isFirstLaunch = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkFirstLaunch();
  }

  Future<void> _checkFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenPermissions = prefs.getBool('has_seen_permissions') ?? false;

    setState(() {
      _isFirstLaunch = !hasSeenPermissions;
      _isLoading = false;
    });
  }

  Future<void> _onPermissionsComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_permissions', true);

    setState(() {
      _isFirstLaunch = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_isFirstLaunch) {
      return PermissionRequestScreen(
        onPermissionsGranted: _onPermissionsComplete,
      );
    }

    return const MainNavigationScaffold();
  }
}
