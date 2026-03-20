// SPDX-License-Identifier: MIT
//
// Copyright 2026 bniladridas. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:ui';

class UserProfile {
  final String id;
  final String name;
  final int colorValue;
  final DateTime createdAt;

  const UserProfile({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.createdAt,
  });

  Color get color => Color(colorValue);

  UserProfile copyWith({
    String? id,
    String? name,
    int? colorValue,
    DateTime? createdAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'colorValue': colorValue,
        'createdAt': createdAt.toIso8601String(),
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final id = json['id'] is String ? json['id'] as String : '';
    final name = json['name'] is String ? json['name'] as String : '';
    int colorValue;
    if (json['colorValue'] is int) {
      colorValue = json['colorValue'] as int;
    } else if (json['colorValue'] is num) {
      colorValue = (json['colorValue'] as num).toInt();
    } else {
      colorValue = availableColors[0];
    }
    DateTime createdAt;
    if (json['createdAt'] is String) {
      createdAt =
          DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now();
    } else {
      createdAt = DateTime.now();
    }
    return UserProfile(
      id: id,
      name: name,
      colorValue: colorValue,
      createdAt: createdAt,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory UserProfile.fromJsonString(String jsonString) {
    return UserProfile.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
  }

  static const List<int> availableColors = [
    0xFF4285F4, // Blue
    0xFFEA4335, // Red
    0xFF34A853, // Green
    0xFFFBBC05, // Yellow
    0xFF9334E6, // Purple
    0xFFFF6D01, // Orange
    0xFF46BDC6, // Teal
    0xFFE91E63, // Pink
  ];

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfile &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
