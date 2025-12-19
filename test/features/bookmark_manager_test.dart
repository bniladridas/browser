import 'package:flutter_test/flutter_test.dart';

import 'package:browser/features/bookmark_manager.dart';

void main() {
  group('BookmarkManager', () {
    test('add bookmark', () {
      final bm = BookmarkManager();
      bm.add('http://example.com', 'Test');
      expect(bm.bookmarks['Test'], contains('http://example.com'));
    });

    test('remove bookmark', () {
      final bm = BookmarkManager();
      bm.add('http://example.com', 'Test');
      bm.remove('http://example.com', 'Test');
      expect(bm.bookmarks.containsKey('Test'), false);
    });

    test('save and load', () {
      final bm = BookmarkManager();
      bm.add('http://example.com', 'Test');
      final json = bm.save();
      final bm2 = BookmarkManager();
      bm2.load(json);
      expect(bm2.bookmarks, bm.bookmarks);
    });
  });
}
