// SPDX-License-Identifier: MIT
//
// Copyright 2026 bniladridas. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

import 'package:browser/firebase_options.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Initialize dotenv with empty values for testing
    await dotenv.load(mergeWith: {
      'FIREBASE_API_KEY': '',
      'FIREBASE_APP_ID': '',
      'FIREBASE_MESSAGING_SENDER_ID': '',
      'FIREBASE_PROJECT_ID': '',
      'FIREBASE_STORAGE_BUCKET': '',
    });
  });

  group('Firebase Options Configuration', () {
    test('getConfig loads from SharedPreferences first', () async {
      SharedPreferences.setMockInitialValues({
        'firebase_FIREBASE_API_KEY': 'prefs-api-key',
      });

      dotenv.env['FIREBASE_API_KEY'] = 'env-api-key';

      final result = await getConfig('FIREBASE_API_KEY');
      expect(result, 'prefs-api-key');
    });

    test('getConfig falls back to .env when SharedPreferences is empty', () async {
      SharedPreferences.setMockInitialValues({});

      dotenv.env['FIREBASE_API_KEY'] = 'env-api-key';

      final result = await getConfig('FIREBASE_API_KEY');
      expect(result, 'env-api-key');
    });

    test('getConfig throws error when both are missing', () async {
      SharedPreferences.setMockInitialValues({});

      dotenv.env.remove('FIREBASE_API_KEY');

      expect(
        () async => await getConfig('FIREBASE_API_KEY'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('getConfig throws error when both are empty strings', () async {
      SharedPreferences.setMockInitialValues({
        'firebase_FIREBASE_API_KEY': '',
      });

      dotenv.env['FIREBASE_API_KEY'] = '';

      expect(
        () async => await getConfig('FIREBASE_API_KEY'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('SharedPreferences stores Firebase keys correctly', () async {
      SharedPreferences.setMockInitialValues({});

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('firebase_FIREBASE_API_KEY', 'test-key');
      await prefs.setString('firebase_FIREBASE_APP_ID', 'test-app');

      expect(prefs.getString('firebase_FIREBASE_API_KEY'), 'test-key');
      expect(prefs.getString('firebase_FIREBASE_APP_ID'), 'test-app');
    });
  });
}
