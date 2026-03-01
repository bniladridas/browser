// SPDX-License-Identifier: MIT
//
// Copyright 2026 bniladridas. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:browser/ux/save_password_prompt.dart';

void main() {
  group('SavePasswordPrompt', () {
    testWidgets('should display origin and username', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SavePasswordPrompt(
              origin: 'example.com',
              username: 'user@example.com',
              onAction: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Save password?'), findsOneWidget);
      expect(
        find.textContaining('user@example.com'),
        findsOneWidget,
      );
      expect(find.textContaining('example.com'), findsOneWidget);
    });

    testWidgets('should have all three action buttons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SavePasswordPrompt(
              origin: 'example.com',
              username: 'user@example.com',
              onAction: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Never for this site'), findsOneWidget);
      expect(find.text('Not now'), findsOneWidget);
    });

    testWidgets('should call onAction with save when Save is tapped',
        (tester) async {
      SavePasswordAction? capturedAction;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SavePasswordPrompt(
              origin: 'example.com',
              username: 'user@example.com',
              onAction: (action) => capturedAction = action,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Save'));
      expect(capturedAction, SavePasswordAction.save);
    });

    testWidgets(
        'should call onAction with neverForSite when Never is tapped',
        (tester) async {
      SavePasswordAction? capturedAction;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SavePasswordPrompt(
              origin: 'example.com',
              username: 'user@example.com',
              onAction: (action) => capturedAction = action,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Never for this site'));
      expect(capturedAction, SavePasswordAction.neverForSite);
    });

    testWidgets('should call onAction with notNow when Not now is tapped',
        (tester) async {
      SavePasswordAction? capturedAction;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SavePasswordPrompt(
              origin: 'example.com',
              username: 'user@example.com',
              onAction: (action) => capturedAction = action,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Not now'));
      expect(capturedAction, SavePasswordAction.notNow);
    });
  });
}
