// SPDX-License-Identifier: MIT
//
// Copyright 2026 bniladridas. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

class CalloutBox extends StatelessWidget {
  const CalloutBox({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final brightness = MediaQuery.of(context).platformBrightness;
    final isDark = brightness == Brightness.dark;

    final backgroundColor =
        isDark ? const Color(0xFF1e3a5f) : const Color(0xFFcfe8ff);
    final textColor =
        isDark ? const Color(0xFFe6f0ff) : const Color(0xFF0b1f33);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
      ),
      child: DefaultTextStyle(
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w500,
          height: 1.4,
        ),
        child: child,
      ),
    );
  }
}
