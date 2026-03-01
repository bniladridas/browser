// SPDX-License-Identifier: MIT
//
// Copyright 2026 bniladridas. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

class LoginCredentials {
  const LoginCredentials({
    required this.origin,
    required this.username,
    required this.password,
  });

  final String origin;
  final String username;
  final String password;

  factory LoginCredentials.fromJson(Map<String, dynamic> json) {
    return LoginCredentials(
      origin: json['origin'] as String,
      username: json['username'] as String,
      password: json['password'] as String,
    );
  }
}

const String loginDetectionScript = '''
(function() {
  if (window.loginDetectorInstalled) return;
  window.loginDetectorInstalled = true;

  function detectPasswordFields() {
    const forms = document.querySelectorAll('form');
    forms.forEach(form => {
      if (form.dataset.loginDetectorAdded) return;
      form.dataset.loginDetectorAdded = 'true';

      const passwordFields = form.querySelectorAll('input[type="password"]');
      if (passwordFields.length === 0) return;

      form.addEventListener('submit', function(e) {
        const usernameField = form.querySelector('input[type="email"], input[type="text"], input[name*="user"], input[name*="email"], input[id*="user"], input[id*="email"]');
        const passwordField = form.querySelector('input[type="password"]');

        if (usernameField && passwordField && usernameField.value && passwordField.value) {
          LoginDetector.postMessage(JSON.stringify({
            origin: window.location.origin,
            username: usernameField.value,
            password: passwordField.value
          }));
        }
      });
    });
  }

  detectPasswordFields();

  const observer = new MutationObserver(detectPasswordFields);
  observer.observe(document.body, { childList: true, subtree: true });
})();
''';
