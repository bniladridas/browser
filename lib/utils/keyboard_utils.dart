// SPDX-License-Identifier: MIT
//
// Copyright 2026 bniladridas. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class KeyboardUtils {
  static bool get _isMacOS => defaultTargetPlatform == TargetPlatform.macOS;

  static bool get _isModifierPressed =>
      (_isMacOS && HardwareKeyboard.instance.isMetaPressed) ||
      (!_isMacOS && HardwareKeyboard.instance.isControlPressed);

  static bool isBackKey(KeyEvent event) {
    // Cmd+[ on macOS, Alt+Left on Windows/Linux
    if (_isMacOS) {
      return event.logicalKey == LogicalKeyboardKey.bracketLeft &&
          HardwareKeyboard.instance.isMetaPressed &&
          !HardwareKeyboard.instance.isShiftPressed;
    }
    return event.logicalKey == LogicalKeyboardKey.arrowLeft &&
        HardwareKeyboard.instance.isAltPressed;
  }

  static bool isForwardKey(KeyEvent event) {
    // Cmd+] on macOS, Alt+Right on Windows/Linux
    if (_isMacOS) {
      return event.logicalKey == LogicalKeyboardKey.bracketRight &&
          HardwareKeyboard.instance.isMetaPressed &&
          !HardwareKeyboard.instance.isShiftPressed;
    }
    return event.logicalKey == LogicalKeyboardKey.arrowRight &&
        HardwareKeyboard.instance.isAltPressed;
  }

  static bool isRefreshKey(KeyEvent event) {
    return event.logicalKey == LogicalKeyboardKey.keyR && _isModifierPressed;
  }

  static bool isNewTabKey(KeyEvent event) {
    return event.logicalKey == LogicalKeyboardKey.keyT && _isModifierPressed;
  }

  static bool isCloseTabKey(KeyEvent event) {
    return event.logicalKey == LogicalKeyboardKey.keyW && _isModifierPressed;
  }

  static bool isFocusUrlKey(KeyEvent event) {
    return event.logicalKey == LogicalKeyboardKey.keyF &&
        _isModifierPressed &&
        !HardwareKeyboard.instance.isShiftPressed;
  }

  static bool isFontPickerKey(KeyEvent event) {
    return event.logicalKey == LogicalKeyboardKey.keyF &&
        _isModifierPressed &&
        HardwareKeyboard.instance.isShiftPressed;
  }

  static bool isEscapeKey(KeyEvent event) {
    return event.logicalKey == LogicalKeyboardKey.escape;
  }

  static bool isPreviousTabKey(KeyEvent event) {
    // Cmd+Option+Left on macOS, Ctrl+Shift+Tab on Windows/Linux
    if (_isMacOS) {
      return event.logicalKey == LogicalKeyboardKey.arrowLeft &&
          HardwareKeyboard.instance.isMetaPressed &&
          HardwareKeyboard.instance.isAltPressed;
    }
    return event.logicalKey == LogicalKeyboardKey.tab &&
        HardwareKeyboard.instance.isControlPressed &&
        HardwareKeyboard.instance.isShiftPressed;
  }

  static bool isNextTabKey(KeyEvent event) {
    // Cmd+Option+Right on macOS, Ctrl+Tab on Windows/Linux
    if (_isMacOS) {
      return event.logicalKey == LogicalKeyboardKey.arrowRight &&
          HardwareKeyboard.instance.isMetaPressed &&
          HardwareKeyboard.instance.isAltPressed;
    }
    return event.logicalKey == LogicalKeyboardKey.tab &&
        HardwareKeyboard.instance.isControlPressed &&
        !HardwareKeyboard.instance.isShiftPressed;
  }
}
