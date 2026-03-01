// SPDX-License-Identifier: MIT
//
// Copyright 2026 bniladridas. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';

extension PlatformExtension on TargetPlatform {
  bool get isMacOS => this == TargetPlatform.macOS;
}

bool get isCommandKey => defaultTargetPlatform == TargetPlatform.macOS;
bool get isControlKey => defaultTargetPlatform != TargetPlatform.macOS;
