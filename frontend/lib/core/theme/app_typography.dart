/// App-wide typography definitions
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Modern typography system for RiskGuard
class AppTypography {
  // Base text theme using Inter (modern, highly readable)
  static final TextTheme textTheme = GoogleFonts.interTextTheme();

  // ========== DISPLAY STYLES (Large headings) ==========

  static final TextStyle displayLarge = GoogleFonts.inter(
    fontSize: 57,
    fontWeight: FontWeight.w700, // Bold
    letterSpacing: -0.25,
    height: 1.12,
  );

  static final TextStyle displayMedium = GoogleFonts.inter(
    fontSize: 45,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    height: 1.16,
  );

  static final TextStyle displaySmall = GoogleFonts.inter(
    fontSize: 36,
    fontWeight: FontWeight.w600, // Semi-bold
    letterSpacing: 0,
    height: 1.22,
  );

  // ========== HEADLINE STYLES (Section headings) ==========

  static final TextStyle headlineLarge = GoogleFonts.inter(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    height: 1.25,
  );

  static final TextStyle headlineMedium = GoogleFonts.inter(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.29,
  );

  static final TextStyle headlineSmall = GoogleFonts.inter(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.33,
  );

  // ========== TITLE STYLES (Card titles, list items) ==========

  static final TextStyle titleLarge = GoogleFonts.inter(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.27,
  );

  static final TextStyle titleMedium = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.15,
    height: 1.50,
  );

  static final TextStyle titleSmall = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.43,
  );

  // ========== BODY STYLES (Paragraphs, descriptions) ==========

  static final TextStyle bodyLarge = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w400, // Regular
    letterSpacing: 0.5,
    height: 1.50,
  );

  static final TextStyle bodyMedium = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.25,
    height: 1.43,
  );

  static final TextStyle bodySmall = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.4,
    height: 1.33,
  );

  // ========== LABEL STYLES (Buttons, tabs, badges) ==========

  static final TextStyle labelLarge = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.43,
  );

  static final TextStyle labelMedium = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    height: 1.33,
  );

  static final TextStyle labelSmall = GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w500, // Medium
    letterSpacing: 0.5,
    height: 1.45,
  );

  // ========== CUSTOM STYLES FOR SPECIFIC USE CASES ==========

  /// Risk score number - large, bold, eye-catching
  static final TextStyle riskScoreLarge = GoogleFonts.inter(
    fontSize: 72,
    fontWeight: FontWeight.w800, // Extra bold
    letterSpacing: -2,
    height: 1.0,
  );

  /// Risk score medium - for cards
  static final TextStyle riskScoreMedium = GoogleFonts.inter(
    fontSize: 48,
    fontWeight: FontWeight.w700,
    letterSpacing: -1,
    height: 1.0,
  );

  /// Stat numbers - dashboard metrics
  static final TextStyle statNumber = GoogleFonts.inter(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.2,
  );

  /// Stat label - dashboard metric labels
  static final TextStyle statLabel = GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.8,
    height: 1.4,
  );

  /// Button text - uppercase, bold, spaced
  static final TextStyle buttonText = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.25,
    height: 1.0,
  );

  /// Chip/Badge text - small, semi-bold
  static final TextStyle chipText = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    height: 1.0,
  );

  /// Overline text - small caps style for categories
  static final TextStyle overline = GoogleFonts.inter(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.5,
    height: 1.6,
  );

  /// Caption text - very small supplementary text
  static final TextStyle caption = GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.4,
    height: 1.36,
  );

  /// Phone number display - monospace for better readability
  static final TextStyle phoneNumber = GoogleFonts.robotoMono(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    height: 1.5,
  );

  /// Timestamp - subtle, smaller
  static final TextStyle timestamp = GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.3,
    height: 1.45,
    fontStyle: FontStyle.italic,
  );

  /// Alert text - attention-grabbing
  static final TextStyle alert = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.25,
    height: 1.5,
  );
}
