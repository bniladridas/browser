// SPDX-License-Identifier: MIT
//
// Copyright 2025 bniladridas. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:browser/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Find in page dialog opens from menu', (WidgetTester tester) async {
    // Launch the app
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Find the PopupMenuButton (menu button)
    final menuButton = find.byType(PopupMenuButton<String>);
    expect(menuButton, findsOneWidget);

    // Tap the menu button to open the menu
    await tester.tap(menuButton);
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // Find the "Find in Page" menu item
    final findMenuItem = find.text('Find in Page');
    expect(findMenuItem, findsOneWidget);

    // Tap the "Find in Page" menu item
    await tester.tap(findMenuItem);
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // Verify the find dialog appears
    expect(find.text('Find in Page'), findsOneWidget);
    expect(find.text('Search term'), findsOneWidget);
    expect(find.text('Find'), findsOneWidget);
    expect(find.text('Previous'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);

    // Close the dialog
    final closeButton = find.text('Close');
    await tester.tap(closeButton);
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // Verify dialog is closed
    expect(find.text('Find in Page'), findsNothing);
  });
}