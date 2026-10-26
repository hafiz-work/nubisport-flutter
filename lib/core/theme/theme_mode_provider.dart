import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// App-wide light/dark choice (Tema page). Session-only for now.
final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);

class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.system;

  void set(ThemeMode mode) => state = mode;
}

String themeModeLabel(ThemeMode mode) => switch (mode) {
  ThemeMode.system => 'Ikut sistem',
  ThemeMode.light => 'Cerah',
  ThemeMode.dark => 'Gelap',
};
