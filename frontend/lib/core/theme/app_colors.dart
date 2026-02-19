/// Application color scheme
library;

import 'package:flutter/material.dart';

class AppColors {
  // Custom User Colors - Your Brand Identity
  static const customBackground = Color(0xFFACC8E5); // Light Blue Background
  static const customText = Color(0xFF112A46); // Dark Blue Text

  // Primary Theme Colors - Using Custom Scheme
  static const primary = Color(0xFFACC8E5); // Light Blue (was purple)
  static const primaryDark = Color(0xFF8BA8CA); // Darker Blue
  static const primaryLight = Color(0xFFC4DAF0); // Lighter Blue
  static const accent = Color(0xFF112A46); // Dark Blue (was cyan)

  // Status Colors (Keep for functionality)
  static const success = Color(0xFF10B981); // Emerald
  static const warning = Color(0xFFF59E0B); // Amber
  static const error = Color(0xFFEF4444); // Rose
  static const info = Color(0xFF3B82F6); // Blue

  // Background Colors (Light Theme - Your Custom Scheme)
  static const backgroundLight = Color(
    0xFFF5F9FC,
  ); // Very light blue-white for better readability
  static const surfaceLight = Color(0xFFFFFFFF); // Pure white for cards
  static const cardLight = Color(0xFFFFFFFF); // White cards for contrast

  // Background Colors (Dark Theme)
  static const backgroundDark = Color(
    0xFF0A1929,
  ); // Deep blue-black for dark mode
  static const surfaceDark = Color(0xFF1A2F42); // Lighter dark blue
  static const cardDark = Color(0xFF1E3A52); // Card background

  // Text Colors (Dark Theme - White/Light text on dark background)
  static const textPrimaryDark = Color(0xFFF9FAFB); // Almost white
  static const textSecondaryDark = Color(0xFFD1D5DB); // Light gray
  static const textTertiaryDark = Color(0xFF9CA3AF); // Medium gray

  // Risk Level Colors (Keep existing for compatibility)
  static const riskLow = Color(0xFF10B981); // Emerald
  static const riskMedium = Color(0xFFF59E0B); // Amber
  static const riskHigh = Color(0xFFEF4444); // Rose
  static const riskUnknown = Color(0xFF8F9BB3); // Gray

  // Text Colors (Light Theme - High Contrast for Readability)
  static const textPrimaryLight = Color(
    0xFF0D1F35,
  ); // Very dark blue (almost black) for maximum readability
  static const textSecondaryLight = Color(
    0xFF4A5F7A,
  ); // Medium blue-gray for secondary text

  // Gradients
  static const primaryGradient = LinearGradient(
    colors: [customBackground, Color(0xFF8BA8CA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const accentGradient = LinearGradient(
    colors: [customText, Color(0xFF1A3A5C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const successGradient = LinearGradient(
    colors: [success, Color(0xFF059669)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const backgroundGradient = LinearGradient(
    colors: [customBackground, Color(0xFFC4DAF0)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Risk Level Gradients
  static const riskLowGradient = LinearGradient(
    colors: [riskLow, Color(0xFF059669)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const riskMediumGradient = LinearGradient(
    colors: [riskMedium, Color(0xFFD97706)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const riskHighGradient = LinearGradient(
    colors: [riskHigh, Color(0xFFDC2626)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Overlay Colors
  static const overlayDark = Color(0xCC000000);
  static const glassDark = Color(0x1AFFFFFF);

  // Get risk color based on score (0-100)
  static Color getRiskColor(int score) {
    if (score <= 30) return riskLow;
    if (score <= 70) return riskMedium;
    return riskHigh;
  }

  // Get risk gradient based on score
  static LinearGradient getRiskGradient(int score) {
    if (score <= 30) return riskLowGradient;
    if (score <= 70) return riskMediumGradient;
    return riskHighGradient;
  }
}
