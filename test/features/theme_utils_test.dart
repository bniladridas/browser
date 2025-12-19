import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:browser/features/theme_utils.dart';

void main() {
  group('ThemeUtils', () {
    test('toThemeMode', () {
      expect(toThemeMode(AppThemeMode.light), ThemeMode.light);
      expect(toThemeMode(AppThemeMode.dark), ThemeMode.dark);
      expect(toThemeMode(AppThemeMode.system), ThemeMode.system);
    });

    test('fromThemeMode', () {
      expect(fromThemeMode(ThemeMode.light), AppThemeMode.light);
      expect(fromThemeMode(ThemeMode.dark), AppThemeMode.dark);
      expect(fromThemeMode(ThemeMode.system), AppThemeMode.system);
    });
  });
}
