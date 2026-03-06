// SPDX-License-Identifier: MIT
//
// Copyright 2026 bniladridas. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:flutter/material.dart';

final RegExp _rgbColorPattern = RegExp(r'rgba?\(([^)]+)\)');
final RegExp _hslColorPattern = RegExp(r'hsla?\(([^)]+)\)');
const double _kMinReliableSaturation = 0.08;
const double _kMinReliableLuminance = 0.06;
const double _kMaxReliableLuminance = 0.94;

const Map<String, int> _namedCssColors = {
  'black': 0xFF000000,
  'white': 0xFFFFFFFF,
  'red': 0xFFFF0000,
  'green': 0xFF008000,
  'blue': 0xFF0000FF,
  'yellow': 0xFFFFFF00,
  'cyan': 0xFF00FFFF,
  'aqua': 0xFF00FFFF,
  'magenta': 0xFFFF00FF,
  'fuchsia': 0xFFFF00FF,
  'orange': 0xFFFFA500,
  'purple': 0xFF800080,
  'rebeccapurple': 0xFF663399,
  'gray': 0xFF808080,
  'grey': 0xFF808080,
  'silver': 0xFFC0C0C0,
  'maroon': 0xFF800000,
  'olive': 0xFF808000,
  'lime': 0xFF00FF00,
  'navy': 0xFF000080,
  'teal': 0xFF008080,
};

class ThemeProbeDecision {
  const ThemeProbeDecision({required this.brightness, this.seedColor});

  final Brightness brightness;
  final Color? seedColor;
}

ThemeProbeDecision? resolveThemeProbeDecision(Map<String, dynamic> probe) {
  final sampleBg =
      probe['sampleBg'] is String ? probe['sampleBg'] as String : null;
  final bg = probe['bg'] is String ? probe['bg'] as String : null;
  final themeColor =
      probe['themeColor'] is String ? probe['themeColor'] as String : null;
  final accentHint =
      probe['accentHint'] is String ? probe['accentHint'] as String : null;
  final metaColorScheme = probe['metaColorScheme'] is String
      ? probe['metaColorScheme'] as String
      : null;
  final colorScheme =
      probe['colorScheme'] is String ? probe['colorScheme'] as String : null;
  final textColor =
      probe['textColor'] is String ? probe['textColor'] as String : null;
  final scheme = (metaColorScheme ?? colorScheme ?? '').toLowerCase();

  Brightness? schemeBrightness;
  if (scheme.contains('dark') && !scheme.contains('light')) {
    schemeBrightness = Brightness.dark;
  } else if (scheme.contains('light') && !scheme.contains('dark')) {
    schemeBrightness = Brightness.light;
  }

  final theme = parseThemeCssColor(themeColor);
  final accent = parseThemeCssColor(accentHint);
  final sampled = parseThemeCssColor(sampleBg);
  final rootBg = parseThemeCssColor(bg);

  Color? preferred;
  final reliableCandidates = [theme, accent, sampled, rootBg]
      .whereType<Color>()
      .where(_isReliableSeedColor)
      .toList();
  if (reliableCandidates.isNotEmpty) {
    preferred = reliableCandidates.first;
  } else {
    preferred = theme ?? accent ?? sampled ?? rootBg;
  }

  if (preferred != null) {
    final inferredBrightness =
        preferred.computeLuminance() < 0.5 ? Brightness.dark : Brightness.light;
    return ThemeProbeDecision(
      brightness: schemeBrightness ?? inferredBrightness,
      seedColor: preferred,
    );
  }

  if (schemeBrightness != null) {
    return ThemeProbeDecision(brightness: schemeBrightness);
  }

  final text = parseThemeCssColor(textColor);
  if (text != null) {
    final brightness =
        text.computeLuminance() < 0.5 ? Brightness.light : Brightness.dark;
    return ThemeProbeDecision(brightness: brightness);
  }
  return null;
}

Color? parseThemeCssColor(String? value) {
  if (value == null) return null;
  final normalized = value.trim().toLowerCase();
  if (normalized.isEmpty || normalized == 'transparent') return null;
  if (normalized.startsWith('rgb')) {
    return _parseThemeRgbColor(normalized);
  }
  if (normalized.startsWith('hsl')) {
    return _parseThemeHslColor(normalized);
  }
  if (normalized.startsWith('#')) {
    return _parseThemeHexColor(normalized);
  }
  final named = _namedCssColors[normalized];
  if (named != null) return Color(named);
  return null;
}

Color? _parseThemeRgbColor(String value) {
  final match = _rgbColorPattern.firstMatch(value);
  if (match == null) return null;
  final normalized = match.group(1)!.replaceAll('/', ' ');
  final parts = normalized
      .split(RegExp(r'[,\s]+'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
  if (parts.length < 3) return null;
  final r = _parseThemeRgbChannel(parts[0]);
  final g = _parseThemeRgbChannel(parts[1]);
  final b = _parseThemeRgbChannel(parts[2]);
  if (r == null || g == null || b == null) return null;
  double alpha = 1.0;
  if (parts.length >= 4) {
    alpha = _parseThemeAlphaChannel(parts[3]) ?? 1.0;
  }
  alpha = alpha.clamp(0.0, 1.0);
  if (alpha <= 0.05) return null;
  return Color.fromARGB(
    (alpha * 255).round(),
    _clampThemeChannel(r),
    _clampThemeChannel(g),
    _clampThemeChannel(b),
  );
}

Color? _parseThemeHexColor(String value) {
  var hex = value.substring(1);
  if (hex.length == 4) {
    // #RGBA
    hex =
        '${hex[0]}${hex[0]}${hex[1]}${hex[1]}${hex[2]}${hex[2]}${hex[3]}${hex[3]}';
  }
  if (hex.length == 3) {
    hex = '${hex[0]}${hex[0]}${hex[1]}${hex[1]}${hex[2]}${hex[2]}';
  }
  if (hex.length == 6) {
    final rgb = int.tryParse(hex, radix: 16);
    if (rgb == null) return null;
    return Color.fromARGB(
      255,
      (rgb >> 16) & 0xFF,
      (rgb >> 8) & 0xFF,
      rgb & 0xFF,
    );
  }
  if (hex.length == 8) {
    // CSS uses #RRGGBBAA, not ARGB.
    final rgba = int.tryParse(hex, radix: 16);
    if (rgba == null) return null;
    return Color.fromARGB(
      rgba & 0xFF,
      (rgba >> 24) & 0xFF,
      (rgba >> 16) & 0xFF,
      (rgba >> 8) & 0xFF,
    );
  }
  return null;
}

Color? _parseThemeHslColor(String value) {
  final match = _hslColorPattern.firstMatch(value);
  if (match == null) return null;
  final normalized = match.group(1)!.replaceAll('/', ' ');
  final parts = normalized
      .split(RegExp(r'[,\s]+'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
  if (parts.length < 3) return null;
  final h = _parseThemeAngle(parts[0]);
  final s = _parseThemePercent(parts[1]);
  final l = _parseThemePercent(parts[2]);
  if (h == null || s == null || l == null) return null;
  double alpha = 1.0;
  if (parts.length >= 4) {
    alpha = _parseThemeAlphaChannel(parts[3]) ?? 1.0;
  }
  alpha = alpha.clamp(0.0, 1.0);
  if (alpha <= 0.05) return null;
  return HSLColor.fromAHSL(alpha, h, s, l).toColor();
}

double? _parseThemeAngle(String token) {
  var value = token.trim();
  if (value.endsWith('deg')) {
    value = value.substring(0, value.length - 3);
  } else if (value.endsWith('turn')) {
    final turns = double.tryParse(value.substring(0, value.length - 4));
    if (turns == null) return null;
    return (turns * 360) % 360;
  } else if (value.endsWith('rad')) {
    final radians = double.tryParse(value.substring(0, value.length - 3));
    if (radians == null) return null;
    return (radians * 180 / math.pi) % 360;
  }
  final parsed = double.tryParse(value);
  if (parsed == null) return null;
  final wrapped = parsed % 360;
  return wrapped < 0 ? wrapped + 360 : wrapped;
}

double? _parseThemePercent(String token) {
  final trimmed = token.trim();
  if (!trimmed.endsWith('%')) return null;
  final value = double.tryParse(trimmed.substring(0, trimmed.length - 1));
  if (value == null) return null;
  return (value.clamp(0.0, 100.0) / 100.0);
}

double? _parseThemeRgbChannel(String token) {
  if (token.endsWith('%')) {
    final pct = double.tryParse(token.substring(0, token.length - 1));
    if (pct == null) return null;
    return (pct.clamp(0.0, 100.0) * 2.55);
  }
  return double.tryParse(token);
}

double? _parseThemeAlphaChannel(String token) {
  if (token.endsWith('%')) {
    final pct = double.tryParse(token.substring(0, token.length - 1));
    if (pct == null) return null;
    return (pct.clamp(0.0, 100.0) / 100.0);
  }
  return double.tryParse(token);
}

int _clampThemeChannel(double value) {
  return value.round().clamp(0, 255).toInt();
}

bool _isReliableSeedColor(Color color) {
  final saturation = _colorSaturation(color);
  final luminance = color.computeLuminance();
  return saturation >= _kMinReliableSaturation &&
      luminance > _kMinReliableLuminance &&
      luminance < _kMaxReliableLuminance;
}

double _colorSaturation(Color color) {
  final r = color.r;
  final g = color.g;
  final b = color.b;
  final maxChannel = math.max(r, math.max(g, b));
  final minChannel = math.min(r, math.min(g, b));
  if (maxChannel == 0) return 0;
  return (maxChannel - minChannel) / maxChannel;
}
