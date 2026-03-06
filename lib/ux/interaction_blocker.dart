// SPDX-License-Identifier: MIT
//
// Copyright 2026 bniladridas. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

class InteractionBlocker extends StatelessWidget {
  const InteractionBlocker({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: MouseRegion(
        cursor: SystemMouseCursors.basic,
        opaque: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap ?? () {},
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}
