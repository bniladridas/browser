// SPDX-License-Identifier: MIT
//
// Copyright 2026 bniladridas. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final logoSize =
        MediaQuery.sizeOf(context).shortestSide < 420 ? 56.0 : 68.0;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.asset(
                    'assets/icons/app_icon.png',
                    width: logoSize,
                    height: logoSize,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return ColoredBox(
                        color: colorScheme.primaryContainer,
                        child: SizedBox.square(
                          dimension: logoSize,
                          child: Icon(
                            Icons.travel_explore,
                            color: colorScheme.onPrimaryContainer,
                            size: logoSize * 0.54,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Browser',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.82),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: 88,
                  child: LinearProgressIndicator(
                    minHeight: 2,
                    borderRadius: BorderRadius.circular(999),
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.32),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
