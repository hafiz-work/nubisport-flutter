import 'package:flutter_test/flutter_test.dart';
import 'package:nubisport_flutter/core/theme/app_theme.dart';

void main() {
  test('app bar title uses the titleLarge size, not the 14px fallback', () {
    for (final theme in [AppTheme.light, AppTheme.dark]) {
      expect(theme.appBarTheme.titleTextStyle?.fontSize, 22);
    }
  });
}
