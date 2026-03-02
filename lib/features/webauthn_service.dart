// SPDX-License-Identifier: MIT
//
// Copyright 2026 bniladridas. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:passkeys/authenticator.dart';
import 'package:passkeys/types.dart';
import '../logging/logger.dart';

class WebAuthnService {
  final PasskeyAuthenticator _authenticator;

  WebAuthnService({PasskeyAuthenticator? authenticator})
      : _authenticator = authenticator ?? PasskeyAuthenticator();

  Future<bool> isSupported() async {
    try {
      final availabilityGetter = _authenticator.getAvailability();

      if (kIsWeb) {
        final availability = await availabilityGetter.web();
        return availability.hasPasskeySupport;
      } else if (Platform.isIOS || Platform.isMacOS) {
        final availability = await availabilityGetter.iOS();
        return availability.hasPasskeySupport;
      } else if (Platform.isAndroid) {
        final availability = await availabilityGetter.android();
        return availability.hasPasskeySupport;
      } else if (Platform.isWindows) {
        final availability = await availabilityGetter.windows();
        return availability.hasPasskeySupport;
      } else {
        // Unknown platform
        return false;
      }
    } catch (e) {
      logger.e('Error checking passkey support: $e');
      return false;
    }
  }

  Future<RegisterResponseType?> register(RegisterRequestType request) async {
    try {
      return await _authenticator.register(request);
    } catch (e) {
      logger.e('Error during passkey registration: $e');
      return null;
    }
  }

  Future<AuthenticateResponseType?> authenticate(AuthenticateRequestType request) async {
    try {
      return await _authenticator.authenticate(request);
    } catch (e) {
      logger.e('Error during passkey authentication: $e');
      return null;
    }
  }
}
