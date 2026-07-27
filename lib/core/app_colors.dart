import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static bool isDark = false;

  static void updateTheme(bool dark) {
    isDark = dark;
  }

  // Brand - Nordic Frost & Midnight Teal
  static Color get primary => isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7);      // Sky Cyan in dark / Electric Ocean Blue in light
  static Color get primaryLight => isDark ? const Color(0xFF7DD3FC) : const Color(0xFF38BDF8);
  static Color get primaryDark => isDark ? const Color(0xFF0284C7) : const Color(0xFF0369A1);
  static Color get accent => isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7);
  static Color get accentGold => isDark ? const Color(0xFFFBBF24) : const Color(0xFFF59E0B);   // Amber gold for accents
  static Color get accentGreen => isDark ? const Color(0xFF34D399) : const Color(0xFF10B981);
  static Color get accentOrange => isDark ? const Color(0xFFFB923C) : const Color(0xFFF97316);

  // Backgrounds
  static Color get background => isDark ? const Color(0xFF0F171E) : const Color(0xFFEBF1F5);   // Deep Abyss Dark / Soft Ice White
  static Color get surface => isDark ? const Color(0xFF1A2634) : const Color(0xFFFFFFFF);      // Deep Ocean Card / Pure White
  static Color get surfaceLight => isDark ? const Color(0xFF263545) : const Color(0xFFDCE6ED); // Elevated surface border/detail
  static Color get gridBg => isDark ? const Color(0xFF0F171E) : const Color(0xFFEBF1F5);       // Grid background

  // Arrow direction colors — Crisp Midnight Navy in light, Bright Ice Cyan in dark
  static Color get arrowUp    => isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B);
  static Color get arrowDown  => isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B);
  static Color get arrowLeft  => isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B);
  static Color get arrowRight => isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B);

  // Difficulty colors (Nordic spectrum from Ice Cyan to Deep Indigo)
  static Color get easy => isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7);
  static Color get medium => isDark ? const Color(0xFF818CF8) : const Color(0xFF6366F1);
  static Color get hard => isDark ? const Color(0xFFA78BFA) : const Color(0xFF8B5CF6);
  static Color get expert => isDark ? const Color(0xFFF472B6) : const Color(0xFFEC4899);
  static Color get master => isDark ? const Color(0xFFFB7185) : const Color(0xFFE11D48);

  // Text
  static Color get textPrimary => isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B);
  static Color get textSecondary => isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  static Color get textMuted => isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);

  // UI Elements
  static Color get heartRed => isDark ? const Color(0xFFF87171) : const Color(0xFFEF4444);
  static Color get heartEmpty => isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);
  static Color get streakFire => isDark ? const Color(0xFFFB923C) : const Color(0xFFF97316);
  static Color get coinGold => isDark ? const Color(0xFFFBBF24) : const Color(0xFFF59E0B);
  static Color get starYellow => isDark ? const Color(0xFFFBBF24) : const Color(0xFFF59E0B);
  static Color get borderGlow => isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7);

  // Gradients
  static LinearGradient get primaryGradient => LinearGradient(
    colors: isDark 
      ? [const Color(0xFF0284C7), const Color(0xFF38BDF8)]
      : [const Color(0xFF0369A1), const Color(0xFF0284C7)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get secondaryGradient => LinearGradient(
    colors: isDark
      ? [const Color(0xFF1E293B), const Color(0xFF334155)]
      : [const Color(0xFFE2E8F0), const Color(0xFFCBD5E1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get bgGradient => LinearGradient(
    colors: isDark
      ? [const Color(0xFF0F171E), const Color(0xFF0A0F14)]
      : [const Color(0xFFEBF1F5), const Color(0xFFDCE6ED)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static LinearGradient get successGradient => LinearGradient(
    colors: isDark
      ? [const Color(0xFF059669), const Color(0xFF10B981)]
      : [const Color(0xFF10B981), const Color(0xFF34D399)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get dangerGradient => LinearGradient(
    colors: isDark
      ? [const Color(0xFFDC2626), const Color(0xFFEF4444)]
      : [const Color(0xFFEF4444), const Color(0xFFF87171)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
