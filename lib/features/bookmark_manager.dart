// SPDX-License-Identifier: MIT
//
// Copyright 2025 bniladridas. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

import 'dart:convert';

class BookmarkManager {
  Map<String, List<String>> bookmarks = {};

  void load(String json) {
    final decoded = jsonDecode(json);
    if (decoded is List) {
      // old format
      bookmarks['General'] = List<String>.from(decoded);
    } else if (decoded is Map) {
      bookmarks = Map<String, List<String>>.from(
          decoded.map((k, v) => MapEntry(k, List<String>.from(v))));
    }
  }

  String save() => jsonEncode(bookmarks);

  void add(String url, String category) {
    if (!bookmarks.containsKey(category)) bookmarks[category] = [];
    if (!bookmarks[category]!.contains(url)) bookmarks[category]!.add(url);
  }

  void remove(String url, String category) {
    bookmarks[category]?.remove(url);
    if (bookmarks[category]?.isEmpty ?? false) bookmarks.remove(category);
  }

  void clear() => bookmarks.clear();
}
