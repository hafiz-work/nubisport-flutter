import 'package:flutter/material.dart';

/// Brand palette - same values as the web tokens (nubisport-astro src/styles/global.css).
/// The web has no dark mode; the dark set uses the web's "on dark" surfaces (navy header/hero).
abstract final class AppColors {
  static const navy = Color(0xFF0A1A33);
  static const navy2 = Color(0xFF12264A);
  static const orange = Color(0xFFFF5A1F);
  static const orangeHover = Color(0xFFFF7A45);
  static const orangeInk = Color(0xFFC2410C);

  static const ink = Color(0xFF0F172A);
  static const muted = Color(0xFF475569);
  static const line = Color(0xFFE2E8F0);
  static const paper = Color(0xFFFFFFFF);
  static const paper2 = Color(0xFFF8FAFC);

  static const onDark = Color(0xFFCBD5E1);
  static const onDarkMuted = Color(0xFF94A3B8);
  static const onDarkLine = Color(0x40FFFFFF); // rgb(255 255 255 / 0.25)

  static const dangerInk = Color(0xFF991B1B);
  static const dangerBg = Color(0xFFFEF2F2);
  static const dangerLine = Color(0xFFFECACA);
  static const successInk = Color(0xFF14532D);
  static const successBg = Color(0xFFF0FDF4);
  static const infoInk = Color(0xFF1E3A8A);
  static const infoBg = Color(0xFFEFF6FF);

  // Dark-only: alert tones readable on navy.
  static const dangerOnDark = Color(0xFFFCA5A5);
  static const dangerBgDark = Color(0xFF3B1218);
}
