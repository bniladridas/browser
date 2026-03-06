// SPDX-License-Identifier: MIT
//
// Copyright 2026 bniladridas. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

import 'package:browser/constants.dart';
import 'package:browser/firebase_options.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
    test('getConfig loads from secure storage first', () async {
      SharedPreferences.setMockInitialValues({
        firebaseApiKeyPref: 'legacy-api-key',
      });
      FlutterSecureStorage.setMockInitialValues({
        firebaseApiKeyPref: 'secure-api-key',
        firebaseAppIdPref: 'secure-app-id',
        firebaseSenderIdPref: 'secure-sender-id',
        firebaseProjectIdPref: 'secure-project-id',
        firebaseStorageBucketPref: 'secure-storage-bucket',
      });

      dotenv.env['FIREBASE_API_KEY'] = 'env-api-key';
      dotenv.env['FIREBASE_APP_ID'] = 'env-app-id';
      dotenv.env['FIREBASE_MESSAGING_SENDER_ID'] = 'env-sender-id';
      dotenv.env['FIREBASE_PROJECT_ID'] = 'env-project-id';
      dotenv.env['FIREBASE_STORAGE_BUCKET'] = 'env-storage-bucket';

      final result = await getConfig('FIREBASE_API_KEY', firebaseApiKeyPref);
      expect(result, 'secure-api-key');
    });

    test('getConfig falls back to .env when SharedPreferences is empty',
        () async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});

      dotenv.env['FIREBASE_API_KEY'] = 'env-api-key';
      dotenv.env['FIREBASE_APP_ID'] = 'env-app-id';
      dotenv.env['FIREBASE_MESSAGING_SENDER_ID'] = 'env-sender-id';
      dotenv.env['FIREBASE_PROJECT_ID'] = 'env-project-id';
      dotenv.env['FIREBASE_STORAGE_BUCKET'] = 'env-storage-bucket';

      final result = await getConfig('FIREBASE_API_KEY', firebaseApiKeyPref);
      expect(result, 'env-api-key');
    });

    test('getConfig throws error when both are missing', () async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});

      dotenv.env.remove('FIREBASE_API_KEY');
      dotenv.env.remove('FIREBASE_APP_ID');
      dotenv.env.remove('FIREBASE_MESSAGING_SENDER_ID');
      dotenv.env.remove('FIREBASE_PROJECT_ID');
      dotenv.env.remove('FIREBASE_STORAGE_BUCKET');

      expect(
        () async => await getConfig('FIREBASE_API_KEY', firebaseApiKeyPref),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('getConfig ignores incomplete SharedPreferences overrides', () async {
      SharedPreferences.setMockInitialValues({
        firebaseApiKeyPref: 'prefs-api-key',
        // Missing other fields - should fall back to .env
      });
      FlutterSecureStorage.setMockInitialValues({});

      dotenv.env['FIREBASE_API_KEY'] = 'env-api-key';
      dotenv.env['FIREBASE_APP_ID'] = 'env-app-id';
      dotenv.env['FIREBASE_MESSAGING_SENDER_ID'] = 'env-sender-id';
      dotenv.env['FIREBASE_PROJECT_ID'] = 'env-project-id';
      dotenv.env['FIREBASE_STORAGE_BUCKET'] = 'env-storage-bucket';

      final result = await getConfig('FIREBASE_API_KEY', firebaseApiKeyPref);
      expect(result, 'env-api-key'); // Should use .env, not incomplete prefs
    });

    test('getConfig supports legacy SharedPreferences fallback', () async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(firebaseApiKeyPref, 'test-key');
      await prefs.setString(firebaseAppIdPref, 'test-app');
      await prefs.setString(firebaseSenderIdPref, 'test-sender');
      await prefs.setString(firebaseProjectIdPref, 'test-project');
      await prefs.setString(firebaseStorageBucketPref, 'test-bucket');

      final result = await getConfig('FIREBASE_API_KEY', firebaseApiKeyPref);
      expect(result, 'test-key');
    });
  });
}
