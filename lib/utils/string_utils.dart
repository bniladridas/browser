// SPDX-License-Identifier: MIT
//
// Copyright 2026 bniladridas. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

extension StringTruncate on String {
  String truncate(int maxLength) {
    if (length <= maxLength) return this;
    const ellipsis = '...';
    if (maxLength <= ellipsis.length) return substring(0, maxLength);
    return '${substring(0, maxLength - ellipsis.length)}$ellipsis';
  }
}
