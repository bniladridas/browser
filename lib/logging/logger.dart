// SPDX-License-Identifier: MIT
//
// Copyright 2026 bniladridas. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// Centralized logger for the browser app.
/// Uses the logger package for structured logging.
final Logger logger = Logger(
  printer: PrettyPrinter(
    methodCount: 2,
    errorMethodCount: 8,
    lineLength: 120,
    colors: true,
    printEmojis: false,
    dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
  ),
  level: kReleaseMode ? Level.info : Level.debug,
);

/// Logger variant without method/stack callouts for quieter logs.
final Logger quietLogger = Logger(
  printer: SimplePrinter(printTime: true),
  level: kReleaseMode ? Level.info : Level.debug,
);
