// SPDX-License-Identifier: MIT
//
// Copyright 2025 bniladridas. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

Future<List<ContentBlocker>> getAdBlockers() async {
  try {
    final jsonString = await rootBundle.loadString('assets/ad_blockers.json');
    final jsonList = jsonDecode(jsonString) as List;
    return jsonList.map((item) {
      final map = item as Map<String, dynamic>;
      return ContentBlocker(
        trigger: ContentBlockerTrigger(urlFilter: map['urlFilter'] as String),
        action: ContentBlockerAction(
          type: ContentBlockerActionType.BLOCK,
        ),
      );
    }).toList();
  } catch (e) {
    // Fallback to empty list if loading fails
    return [];
  }
}
