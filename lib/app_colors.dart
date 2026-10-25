import 'package:flutter/material.dart';

/// Shared brand palette for the WISE system.
/// Mirrors the web admin dashboard (assets/css/global.css) so every surface
/// uses the same colors.
abstract final class AppColors {
  // Primary Brand Colors
  static const Color primary = Color(0xFF2563EB);
  static const Color primaryDark = Color(0xFF1D4ED8);
  static const Color primaryLight = Color(0xFF3B82F6);
  static const Color primaryContainer = Color(0xFFDBEAFE);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onPrimaryContainer = Color(0xFF1E3A8A);

  // Semantic Colors
  static const Color success = Color(0xFF22C55E);
  static const Color successContainer = Color(0xFFDCFCE7);
  static const Color onSuccessContainer = Color(0xFF14532D);

  static const Color warning = Color(0xFFF59E0B);
  static const Color warningContainer = Color(0xFFFFF3C7);
  static const Color onWarningContainer = Color(0xFF78350F);

  static const Color error = Color(0xFFEF4444);
  static const Color errorContainer = Color(0xFFFEF2F2);
  static const Color onErrorContainer = Color(0xFF7F1D1D);

  // Surface Colors
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF8FAFC);
  static const Color surfaceContainer = Color(0xFFF1F5F9);
  static const Color surfaceContainerHigh = Color(0xFFE2E8F0);
  static const Color surfaceContainerHighest = Color(0xFFCBD5E1);

  // Background
  static const Color background = Color(0xFFF8FAFC);
  static const Color onBackground = Color(0xFF0F172A);

  // Legacy aliases
  static const Color lightBg = Color(0xFFEFF6FF);
  static const Color pageBg = Color(0xFFF4F6F8);

  // Text Colors
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textTertiary = Color(0xFF94A3B8);
  static const Color textInverse = Color(0xFFFFFFFF);

  // Border & Divider
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderStrong = Color(0xFFCBD5E1);

  // Shadow
  static const Color shadow = Color(0x0A0F172A);
  static const Color shadowMedium = Color(0x140F172A);
  static const Color shadowStrong = Color(0x1F0F172A);

  // Status Colors (for schedule status)
  static const Color statusUpcoming = Color(0xFF1E40AF);
  static const Color statusUpcomingBg = Color(0xFFEFF6FF);
  static const Color statusArriving = Color(0xFF92400E);
  static const Color statusArrivingBg = Color(0xFFFEF3C7);
  static const Color statusArrived = Color(0xFF166534);
  static const Color statusArrivedBg = Color(0xFFF0FDF4);
  static const Color statusDelayed = Color(0xFF991B1B);
  static const Color statusDelayedBg = Color(0xFFFEF2F2);
  static const Color statusCompleted = Color(0xFF15803D);
  static const Color statusCompletedBg = Color(0xFFF0FDF4);
  static const Color statusCancelled = Color(0xFF4B5563);
  static const Color statusCancelledBg = Color(0xFFF3F4F6);

  // Zone Colors
  static const Color zone1 = Color(0xFF16A34A);
  static const Color zone2 = Color(0xFF3B82F6);
  static const Color zone3 = Color(0xFFF59E0B);
  static const Color zone4 = Color(0xFF8B5CF6);
  static const Color zone5 = Color(0xFFEC4899);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryDark],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2563EB), Color(0xFF1D4ED8), Color(0xFF1E3A8A)],
  );

  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [success, Color(0xFF16A34A)],
  );

  static const LinearGradient warningGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [warning, Color(0xFFD97706)],
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [surface, surfaceVariant],
  );

  // Glassmorphism
  static const Color glassWhite = Color(0x80FFFFFF);
  static const Color glassBorder = Color(0x33FFFFFF);
}