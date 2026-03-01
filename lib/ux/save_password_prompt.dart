// SPDX-License-Identifier: MIT
//
// Copyright 2026 bniladridas. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import '../utils/string_utils.dart';

enum SavePasswordAction {
  save,
  neverForSite,
  notNow,
}

class SavePasswordPrompt extends StatelessWidget {
  const SavePasswordPrompt({
    super.key,
    required this.origin,
    required this.username,
    required this.onAction,
  });

  final String origin;
  final String username;
  final void Function(SavePasswordAction) onAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Save password?',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Save password for ${username.truncate(30)} on ${origin.truncate(40)}?',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton(
                  onPressed: () => onAction(SavePasswordAction.neverForSite),
                  child: const Text('Never for this site'),
                ),
                TextButton(
                  onPressed: () => onAction(SavePasswordAction.notNow),
                  child: const Text('Not now'),
                ),
                FilledButton(
                  onPressed: () => onAction(SavePasswordAction.save),
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
