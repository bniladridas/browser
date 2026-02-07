// SPDX-License-Identifier: MIT
//
// Copyright 2026 bniladridas. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

import 'dart:async';

class NetworkEvent {
  final String url;
  final String method;
  final int? statusCode;
  final Duration duration;
  final bool success;
  final Exception? error;
  final DateTime timestamp;

  NetworkEvent({
    required this.url,
    required this.method,
    this.statusCode,
    required this.duration,
    required this.success,
    this.error,
  }) : timestamp = DateTime.now();

  Map<String, dynamic> toJson() => {
        'url': url,
        'method': method,
        'statusCode': statusCode,
        'durationMs': duration.inMilliseconds,
        'success': success,
        'error': error?.toString(),
        'timestamp': timestamp.toIso8601String(),
      };

  @override
  String toString() {
    final statusStr = statusCode != null ? ' $statusCode' : '';
    final errorStr = error != null ? ' Error: ${error.toString()}' : '';
    return '$method ${url.truncate(80)}$statusStr (${duration.inMilliseconds}ms)$errorStr';
  }
}

class NetworkMonitor {
  static final NetworkMonitor _instance = NetworkMonitor._internal();
  factory NetworkMonitor() => _instance;
  NetworkMonitor._internal();

  final _controller = StreamController<NetworkEvent>.broadcast();
  final _events = <NetworkEvent>[];
  static const int _maxEvents = 100;

  Stream<NetworkEvent> get events => _controller.stream;

  List<NetworkEvent> get recentEvents => List.unmodifiable(_events);

  void logRequest({
    required String url,
    required String method,
    required int statusCode,
    required Duration duration,
  }) {
    final event = NetworkEvent(
      url: url,
      method: method,
      statusCode: statusCode,
      duration: duration,
      success: statusCode >= 200 && statusCode < 400,
    );
    _addEvent(event);
  }

  void logRequestSuccess({
    required String url,
    required String method,
    required Duration duration,
  }) {
    final event = NetworkEvent(
      url: url,
      method: method,
      statusCode: 200,
      duration: duration,
      success: true,
    );
    _addEvent(event);
  }

  void onRequestFailed({
    required String url,
    required String method,
    required Exception error,
    required Duration duration,
    int? statusCode,
  }) {
    final event = NetworkEvent(
      url: url,
      method: method,
      statusCode: statusCode,
      duration: duration,
      success: false,
      error: error,
    );
    _addEvent(event);
  }

  void _addEvent(NetworkEvent event) {
    _events.add(event);
    if (_events.length > _maxEvents) {
      _events.removeAt(0);
    }
    _controller.add(event);
  }

  List<NetworkEvent> getEventsByUrl(String url) {
    return _events.where((e) => e.url.contains(url)).toList();
  }

  List<NetworkEvent> getFailedRequests() {
    return _events.where((e) => !e.success).toList();
  }

  int get successCount {
    return _events.where((e) => e.success).length;
  }

  int get failureCount {
    return _events.where((e) => !e.success).length;
  }

  void clear() {
    _events.clear();
  }
}

extension on String {
  String truncate(int maxLength) {
    if (length <= maxLength) return this;
    return substring(0, maxLength);
  }
}
