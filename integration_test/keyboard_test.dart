// SPDX-License-Identifier: MIT
//
// Copyright 2025 bniladridas. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:browser/main.dart';

const testTimeout = Timeout(Duration(seconds: 30));

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Browser App Tests', () {
    testWidgets('Keyboard shortcuts focus URL', (WidgetTester tester) async {
      // Skip on macOS due to app not foregrounding in integration tests
      if (defaultTargetPlatform == TargetPlatform.macOS) {
        return;
      }
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Tap on scaffold to unfocus
      await tester.tap(find.byType(Scaffold));
      await tester.pump();

      // Simulate Ctrl+L (or Cmd+L) to focus URL field
      final modifier = defaultTargetPlatform == TargetPlatform.macOS ? LogicalKeyboardKey.metaLeft : LogicalKeyboardKey.controlLeft;
      await tester.sendKeyDownEvent(modifier);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
      await tester.sendKeyUpEvent(modifier);
      await tester.pump();

      // Check if TextField has focus
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.focusNode?.hasFocus, true);
    }, timeout: testTimeout);
  });
}