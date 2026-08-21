import 'package:flutter/material.dart';

/// Catppuccin Mocha Color Palette for BinAnalyzer
class AppColors {
  AppColors._();

  // Backgrounds & Surfaces
  static const Color crust = Color(0xFF11111B);      // Darkest background (editor gutter, main canvas)
  static const Color mantle = Color(0xFF181825);     // Panel & viewer background
  static const Color base = Color(0xFF1E1E2E);       // Dialog, toolbar, and card background
  static const Color surface0 = Color(0xFF313244);   // Borders, dividers, subtle chips
  static const Color surface1 = Color(0xFF45475A);   // Active borders, scrollbar thumbs
  static const Color surface2 = Color(0xFF585B70);   // Inactive icons, subtle text

  // Accents & Syntax
  static const Color blue = Color(0xFF89B4FA);       // Primary accent, instructions, arch chips
  static const Color mauve = Color(0xFFCBA6F7);      // Categories, secondary accent
  static const Color green = Color(0xFFA6E3A1);      // Success, opcode hex, reduction metrics
  static const Color red = Color(0xFFF38BA8);        // Errors, SIMD flags, target B accent
  static const Color yellow = Color(0xFFF9E2AF);     // Warnings, labels, presets
  static const Color sky = Color(0xFF89DCEB);        // Directives, prefixes
  static const Color peach = Color(0xFFFAB387);      // Highlights, alternate tags

  // Typography
  static const Color text = Color(0xFFCDD6F4);       // Primary text
  static const Color subtext0 = Color(0xFFA6ADC8);   // Secondary text / subtitles
  static const Color subtext1 = Color(0xFFBAC2DE);   // Lighter secondary text
  static const Color overlay0 = Color(0xFF6C7086);   // Disabled, comments, hints
}
