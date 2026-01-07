// SPDX-License-Identifier: MIT
//
// Copyright 2025 bniladridas. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';

class AiService {
  static final AiService _instance = AiService._internal();
  factory AiService() => _instance;
  AiService._internal();

  GenerativeModel? _model;
  ChatSession? _chatSession;

  void initialize() {
    try {
      _model = FirebaseAI.googleAI().generativeModel(
        model: 'gemini-2.5-flash-lite',
        generationConfig: GenerationConfig(
          temperature: 0.7,
          maxOutputTokens: 1000,
        ),
      );
      _chatSession = _model?.startChat();
    } catch (e) {
      debugPrint('AI model initialization failed: $e');
      _model = null;
      _chatSession = null;
    }
  }

  Future<String> generateResponse(String prompt) async {
    if (_chatSession == null) {
      return 'AI is not available. Please configure Firebase.';
    }
    final content = Content.text(prompt);
    final response = await _chatSession!.sendMessage(content);
    return response.text ?? 'No response generated.';
  }

  Future<String> summarizeText(String text) async {
    final prompt = 'Summarize the following text:\n\n$text';
    return generateResponse(prompt);
  }
}
