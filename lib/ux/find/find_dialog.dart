// SPDX-License-Identifier: MIT
//
// Copyright 2025 bniladridas. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class FindDialog extends StatefulWidget {
  const FindDialog({super.key, required this.findInteractionController});

  final FindInteractionController findInteractionController;

  @override
  State<FindDialog> createState() => _FindDialogState();
}

class _FindDialogState extends State<FindDialog> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _find() async {
    final term = _searchController.text;
    if (term.isNotEmpty) {
      try {
        await widget.findInteractionController.findAll(find: term);
        await widget.findInteractionController.findNext(forward: true);
      } catch (e) {
        debugPrint('Find operation failed: $e');
      }
    }
  }

  Future<void> _findNext() async {
    try {
      await widget.findInteractionController.findNext(forward: true);
    } catch (e) {
      debugPrint('Find next operation failed: $e');
    }
  }

  Future<void> _findPrevious() async {
    try {
      await widget.findInteractionController.findNext(forward: false);
    } catch (e) {
      debugPrint('Find previous operation failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Find in Page'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(labelText: 'Search term'),
            onSubmitted: (_) => _find(),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton(
                onPressed: _find,
                child: const Text('Find'),
              ),
              TextButton(
                onPressed: _findPrevious,
                child: const Text('Previous'),
              ),
              TextButton(
                onPressed: _findNext,
                child: const Text('Next'),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () async {
            final navigator = Navigator.of(context);
            try {
              await widget.findInteractionController.clearMatches();
            } catch (e) {
              debugPrint('Clear matches failed: $e');
            }
            navigator.pop();
          },
          child: const Text('Close'),
        ),
      ],
    );
  }
}
