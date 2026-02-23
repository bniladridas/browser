// SPDX-License-Identifier: MIT
//
// Copyright 2026 bniladridas. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

import 'package:flutter_test/flutter_test.dart';
import 'package:browser/logging/network_monitor.dart';

void main() {
  test('NetworkEvent has correct properties', () {
    final event = NetworkEvent(
      url: 'https://example.com/api',
      method: 'GET',
      statusCode: 200,
      duration: const Duration(milliseconds: 100),
      success: true,
    );

    expect(event.url, equals('https://example.com/api'));
    expect(event.method, equals('GET'));
    expect(event.statusCode, equals(200));
    expect(event.success, isTrue);
    expect(event.duration, equals(const Duration(milliseconds: 100)));
    expect(event.timestamp, isNotNull);
  });

  test('NetworkEvent toJson produces valid JSON', () {
    final event = NetworkEvent(
      url: 'https://example.com',
      method: 'GET',
      statusCode: 200,
      duration: const Duration(milliseconds: 100),
      success: true,
    );

    final json = event.toJson();
    expect(json['url'], equals('https://example.com'));
    expect(json['method'], equals('GET'));
    expect(json['statusCode'], equals(200));
    expect(json['durationMs'], equals(100));
    expect(json['success'], isTrue);
    expect(json.containsKey('timestamp'), isTrue);
  });

  test('NetworkEvent toString is readable', () {
    final event = NetworkEvent(
      url: 'https://example.com/api/users',
      method: 'GET',
      statusCode: 200,
      duration: const Duration(milliseconds: 50),
      success: true,
    );

    final str = event.toString();
    expect(str, contains('GET'));
    expect(str, contains('200'));
    expect(str, contains('50ms'));
  });

  test('NetworkMonitor logs and stores events', () {
    final monitor = NetworkMonitor();
    monitor.clear();

    monitor.logRequest(
      url: 'https://example.com/api',
      method: 'GET',
      statusCode: 200,
      duration: const Duration(milliseconds: 100),
    );

    expect(monitor.recentEvents.length, equals(1));
    expect(monitor.recentEvents[0].url, equals('https://example.com/api'));
  });

  test('NetworkMonitor tracks success and failure counts', () {
    final monitor = NetworkMonitor();
    monitor.clear();

    monitor.logRequest(
      url: 'https://example.com/1',
      method: 'GET',
      statusCode: 200,
      duration: Duration.zero,
    );
    monitor.onRequestFailed(
      url: 'https://example.com/2',
      method: 'GET',
      error: Exception('Error'),
      duration: Duration.zero,
    );

    expect(monitor.successCount, equals(1));
    expect(monitor.failureCount, equals(1));
  });

  test('NetworkMonitor filters failed requests', () {
    final monitor = NetworkMonitor();
    monitor.clear();

    monitor.logRequest(
      url: 'https://example.com/success',
      method: 'GET',
      statusCode: 200,
      duration: Duration.zero,
    );
    monitor.onRequestFailed(
      url: 'https://example.com/fail1',
      method: 'GET',
      error: Exception('Error 1'),
      duration: Duration.zero,
    );
    monitor.onRequestFailed(
      url: 'https://example.com/fail2',
      method: 'GET',
      error: Exception('Error 2'),
      duration: Duration.zero,
    );

    final failed = monitor.getFailedRequests();
    expect(failed.length, equals(2));
  });

  test('NetworkMonitor filters events by URL', () {
    final monitor = NetworkMonitor();
    monitor.clear();

    monitor.logRequest(
      url: 'https://api.example.com/users',
      method: 'GET',
      statusCode: 200,
      duration: Duration.zero,
    );
    monitor.logRequest(
      url: 'https://api.example.com/posts',
      method: 'GET',
      statusCode: 200,
      duration: Duration.zero,
    );
    monitor.logRequest(
      url: 'https://other.com/api',
      method: 'GET',
      statusCode: 200,
      duration: Duration.zero,
    );

    final apiEvents = monitor.getEventsByUrl('api.example.com');
    expect(apiEvents.length, equals(2));
  });

  test('NetworkMonitor clears all events', () {
    final monitor = NetworkMonitor();
    monitor.clear();

    monitor.logRequest(
      url: 'https://example.com',
      method: 'GET',
      statusCode: 200,
      duration: Duration.zero,
    );
    monitor.onRequestFailed(
      url: 'https://example.com',
      method: 'POST',
      error: Exception('Error'),
      duration: Duration.zero,
    );

    expect(monitor.recentEvents.length, equals(2));

    monitor.clear();

    expect(monitor.recentEvents, isEmpty);
    expect(monitor.successCount, equals(0));
    expect(monitor.failureCount, equals(0));
  });

  test('NetworkMonitor events stream emits new events', () async {
    final monitor = NetworkMonitor();
    monitor.clear();

    final events = <NetworkEvent>[];
    final subscription = monitor.events.listen(events.add);

    monitor.logRequest(
      url: 'https://example.com',
      method: 'GET',
      statusCode: 200,
      duration: Duration.zero,
    );

    await Future.delayed(Duration.zero);

    expect(events.length, equals(1));
    expect(events[0].url, equals('https://example.com'));

    subscription.cancel();
  });
}
