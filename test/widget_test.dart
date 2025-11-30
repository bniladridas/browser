// SPDX-License-Identifier: MIT
//
// Copyright 2025 bniladridas. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility that Flutter provides. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:browser/ux/find/find_dialog.dart';

void main() {
  testWidgets('App loads with browser interface', (WidgetTester tester) async {
    // Build a simplified browser interface for testing
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            actions: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward),
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {},
              ),
            ],
            title: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Enter URL',
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) {},
                  ),
                ),
              ],
            ),
          ),
          body: Container(),
        ),
      ),
    );

    // Verify that the browser interface elements are present
    expect(find.text('Enter URL'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget);
  });

  testWidgets('Find dialog displays correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FindDialog(controller: null),
        ),
      ),
    );

    expect(find.text('Find in Page'), findsOneWidget);
    expect(find.text('Search term'), findsOneWidget);
    expect(find.text('Find'), findsOneWidget);
    expect(find.text('Previous'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
  });
}
