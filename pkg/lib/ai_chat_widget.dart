// SPDX-License-Identifier: MIT
//
// Copyright 2026 bniladridas. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import 'ai_service.dart';
import 'callout_box.dart';

class AiChatWidget extends HookWidget {
  const AiChatWidget({super.key, this.pageTitle, this.pageUrl});

  final String? pageTitle;
  final String? pageUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const compactDensity = VisualDensity(horizontal: -2, vertical: -2);
    final messages = useState<List<String>>([]);
    final controller = useTextEditingController();
    final isLoading = useState(false);
    final aiService = useMemoized(() => AiService(), []);

    Future<void> sendMessage() async {
      final text = controller.text.trim();
      if (text.isEmpty) return;
      messages.value.add('You: $text');
      messages.value = List.from(messages.value);
      controller.clear();
      isLoading.value = true;
      try {
        String prompt = text;
        final lowerText = text.toLowerCase();
        if (lowerText.contains('page') ||
            lowerText.contains('website') ||
            lowerText.contains('tell me about') ||
            lowerText.contains('what is this') ||
            lowerText.contains('current site')) {
          final context =
              'Current page: ${pageTitle != null ? 'Title: "$pageTitle"' : 'Title unknown'}, URL: ${pageUrl ?? 'unknown'}. ';
          prompt = context + text;
        }
        final (thought, response) = await aiService.generateResponse(prompt);
        if (thought != null && thought.isNotEmpty) {
          messages.value = [...messages.value, 'AI_THOUGHT: $thought'];
        }
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
      title: Text(
        'AI Chat',
        style: theme.textTheme.titleSmall?.copyWith(fontSize: 15),
      ),
      content: SizedBox(
        width: 380,
        height: 360,
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: messages.value.length,
                itemBuilder: (context, index) {
                  final message = messages.value[index];
                  if (message.startsWith('AI: ')) {
                    final content = message.substring(4);
                    final hasEmphasis =
                        content.contains('**') ||
                        content.contains('*') ||
                        content.contains('warning') ||
                        content.contains('error') ||
                        content.contains('suggestion') ||
                        content.contains('option');
                    final child = MarkdownBody(
                      data: content,
                      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                        p: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
                      ),
                    );
                    return ListTile(
                      dense: true,
                      visualDensity: compactDensity,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      hoverColor: Colors.transparent,
                      title: hasEmphasis ? CalloutBox(child: child) : child,
                    );
                  } else if (message.startsWith('AI_THOUGHT: ')) {
                    final content = message.substring(12);
                    return ListTile(
                      dense: true,
                      visualDensity: compactDensity,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      hoverColor: Colors.transparent,
                      title: CalloutBox(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Reasoning',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontSize: 10,
                                color: theme.colorScheme.onSurfaceVariant,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            const SizedBox(height: 4),
                            MarkdownBody(
                              data: content,
                              styleSheet:
                                  MarkdownStyleSheet.fromTheme(theme).copyWith(
                                p: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  } else {
                    return ListTile(
                      dense: true,
                      visualDensity: compactDensity,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      hoverColor: Colors.transparent,
                      title: Text(
                        message,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 12,
                        ),
                      ),
                    );
                  }
                },
              ),
            ),
            if (isLoading.value)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Ask AI...',
                      isDense: true,
                      filled: false,
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    onSubmitted: (_) => sendMessage(),
                  ),
                ),
                IconButton(
                  onPressed: isLoading.value ? null : sendMessage,
                  visualDensity: compactDensity,
                  icon: const Icon(Icons.send, size: 18),
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
