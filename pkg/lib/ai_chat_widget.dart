// SPDX-License-Identifier: MIT
//
// Copyright 2025 bniladridas. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'ai_service.dart';

class AiChatWidget extends HookWidget {
  const AiChatWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final messages = useState<List<String>>([]);
    final controller = useTextEditingController();
    final isLoading = useState(false);

    Future<void> sendMessage() async {
      final text = controller.text.trim();
      if (text.isEmpty) return;
      messages.value = [...messages.value, 'You: $text'];
      controller.clear();
      isLoading.value = true;
      try {
        final response = await AiService().generateResponse(text);
        messages.value = [...messages.value, 'AI: $response'];
      } catch (e) {
        messages.value = [...messages.value, 'AI: Error: $e'];
      } finally {
        isLoading.value = false;
      }
      // Keep only last 50 messages for performance
      if (messages.value.length > 50) {
        messages.value = messages.value.sublist(messages.value.length - 50);
      }
    }

    return AlertDialog(
      title: const Text('AI Chat'),
      content: SizedBox(
        width: 400,
        height: 400,
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: messages.value.length,
                itemBuilder: (context, index) =>
                    ListTile(title: Text(messages.value[index])),
              ),
            ),
            if (isLoading.value) const CircularProgressIndicator(),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: const InputDecoration(hintText: 'Ask AI...'),
                    onSubmitted: (_) => sendMessage(),
                  ),
                ),
                IconButton(
                  onPressed: isLoading.value ? null : sendMessage,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
