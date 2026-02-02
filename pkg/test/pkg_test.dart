// SPDX-License-Identifier: MIT

import 'package:flutter_test/flutter_test.dart';
import 'package:pkg/pkg.dart';

void main() {
  test('AiService handles no model gracefully', () async {
    final service = AiService();
    // Without Firebase init, model is null
    final response = await service.generateResponse('test');
    expect(response, 'AI is not available. Please configure Firebase.');
  });
}
