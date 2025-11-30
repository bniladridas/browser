// SPDX-License-Identifier: MIT
//
// Copyright 2025 bniladridas. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class FindDialog extends StatefulWidget {
  const FindDialog({super.key, required this.controller});

  final InAppWebViewController? controller;

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
        // ignore: deprecated_member_use
        await widget.controller?.findAllAsync(find: term);
        // ignore: deprecated_member_use
        await widget.controller?.findNext(forward: true);
      } on PlatformException catch (e) {
        debugPrint('Find operation failed: $e');
      }
    }
  }

  Future<void> _findNext() async {
    try {
      // ignore: deprecated_member_use
      await widget.controller?.findNext(forward: true);
    } on PlatformException {
      // ignore
    }
  }

  Future<void> _findPrevious() async {
    try {
      // ignore: deprecated_member_use
      await widget.controller?.findNext(forward: false);
    } on PlatformException {
      // ignore
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
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}