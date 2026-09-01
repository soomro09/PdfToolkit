import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

// 🎨 Global Riverpod provider for the accent color
final accentColorProvider = StateProvider<Color>((ref) => AppColors._defaultRed);

class AppColors {
  static const Color _defaultRed = Color(0xFFE53935);

  // 🚀 Change from 'static const' to a static getter that reads the active color or defaults to red
  // (We'll bind this to Riverpod inside your main app wrapper)
  static Color primaryRed = _defaultRed;
  static Color primaryRedDark = const Color(0xFFB71C1C);
  static Color accentRedLight = const Color(0xFFFFEBEE);

  // Backgrounds & Surfaces
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF1F5F9);

  // Text & Icons
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);

  // Borders & Dividers
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderSubtle = Color(0xFFF1F5F9);

  // Status & Utility
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
}