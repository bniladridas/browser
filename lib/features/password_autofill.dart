// SPDX-License-Identifier: MIT
//
// Copyright 2026 bniladridas. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'password_storage.dart';

class PasswordAutofillService {
  PasswordAutofillService({
    PasswordStorageRepository? repository,
  }) : _repository = repository ?? PasswordStorageRepository();

  final PasswordStorageRepository _repository;

  bool originMatches(String savedOrigin, String currentUrl) {
    try {
      final saved = Uri.parse(savedOrigin);
      final current = Uri.parse(currentUrl);
      return saved.origin == current.origin;
    } catch (_) {
      return false;
    }
  }

  Future<List<PasswordCredential>> getMatchingCredentials(
    String currentUrl,
  ) async {
    final allCredentials = await _repository.listCredentials();
    return allCredentials
        .where((cred) => originMatches(cred.origin, currentUrl))
        .toList();
  }

  String generateAutofillScript(String username, String password) {
    // Use jsonEncode for proper escaping of all special characters
    final escapedUsername = jsonEncode(username);
    final escapedPassword = jsonEncode(password);

    return '''
(function() {
  const forms = document.querySelectorAll('form');
  let filled = false;

  forms.forEach(form => {
    if (filled) return;

    const passwordField = form.querySelector('input[type="password"]');
    if (!passwordField) return;

    const usernameField = form.querySelector('input[type="email"], input[type="text"], input[name*="user"], input[name*="email"], input[id*="user"], input[id*="email"]');

    if (usernameField && passwordField) {
      usernameField.value = $escapedUsername;
      passwordField.value = $escapedPassword;

      usernameField.dispatchEvent(new Event('input', { bubbles: true }));
      usernameField.dispatchEvent(new Event('change', { bubbles: true }));
      passwordField.dispatchEvent(new Event('input', { bubbles: true }));
      passwordField.dispatchEvent(new Event('change', { bubbles: true }));

      filled = true;
    }
  });

  return filled;
})();
''';
  }
}
