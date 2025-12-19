// SPDX-License-Identifier: MIT
//
// Copyright 2025 bniladridas. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

import 'package:flutter_inappwebview/flutter_inappwebview.dart';

List<ContentBlocker> getAdBlockers() {
  return [
    ContentBlocker(
      trigger: ContentBlockerTrigger(urlFilter: ".*doubleclick.net.*"),
      action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
    ),
    ContentBlocker(
      trigger: ContentBlockerTrigger(urlFilter: ".*googlesyndication.com.*"),
      action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
    ),
    ContentBlocker(
      trigger: ContentBlockerTrigger(urlFilter: ".*googleadservices.com.*"),
      action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
    ),
  ];
}
