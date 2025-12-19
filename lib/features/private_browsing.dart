// SPDX-License-Identifier: MIT
//
// Copyright 2025 bniladridas. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

class PrivateBrowsingSettings {
  final bool cacheEnabled;
  final bool clearCache;

  PrivateBrowsingSettings(
      {required this.cacheEnabled, required this.clearCache});

  factory PrivateBrowsingSettings.fromEnabled(bool enabled) {
    return PrivateBrowsingSettings(
      cacheEnabled: !enabled,
      clearCache: enabled,
    );
  }
}
