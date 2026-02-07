// SPDX-License-Identifier: MIT
//
// Copyright 2026 bniladridas. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

import 'dart:async';
import 'package:flutter/material.dart';
import '../logging/network_monitor.dart';

class NetworkDebugDialog extends StatefulWidget {
  const NetworkDebugDialog({super.key});

  @override
  State<NetworkDebugDialog> createState() => _NetworkDebugDialogState();
}

class _NetworkDebugDialogState extends State<NetworkDebugDialog> {
  late final StreamSubscription<NetworkEvent> _subscription;
  final List<NetworkEvent> _events = [];

  @override
  void initState() {
    super.initState();
    _events.addAll(NetworkMonitor().recentEvents);
    _subscription = NetworkMonitor().events.listen((event) {
      if (mounted) {
        setState(() {
          _events.insert(0, event);
          if (_events.length > 50) {
            _events.removeLast();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final failedEvents = _events.where((e) => !e.success).toList();

    return AlertDialog(
      title: Row(
        children: [
          const Text('Network Debug'),
          const Spacer(),
          Chip(
            label: Text('${NetworkMonitor().successCount} success'),
            backgroundColor: Colors.green.withValues(alpha: 0.2),
            labelStyle: const TextStyle(fontSize: 12),
          ),
          const SizedBox(width: 8),
          Chip(
            label: Text('${NetworkMonitor().failureCount} failed'),
            backgroundColor: Colors.red.withValues(alpha: 0.2),
            labelStyle: const TextStyle(fontSize: 12, color: Colors.red),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (failedEvents.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(8),
                color: Colors.red.withValues(alpha: 0.1),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red, size: 16),
                    const SizedBox(width: 8),
                    Text('${failedEvents.length} failed requests'),
                    const Spacer(),
                    TextButton(
                      onPressed: () => setState(
                          () => _events.removeWhere((e) => !e.success)),
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            Expanded(
              child: _events.isEmpty
                  ? const Center(child: Text('No network activity yet'))
                  : ListView.builder(
                      itemCount: _events.length,
                      itemBuilder: (context, index) {
                        final event = _events[index];
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            event.success ? Icons.check_circle : Icons.error,
                            color: event.success ? Colors.green : Colors.red,
                            size: 18,
                          ),
                          title: Text(
                            '${event.method} ${event.url.length > 50 ? '${event.url.substring(0, 50)}...' : event.url}',
                            style: TextStyle(
                              fontSize: 12,
                              color: event.success ? null : Colors.red,
                            ),
                          ),
                          subtitle: Row(
                            children: [
                              if (event.statusCode != null)
                                Text(
                                  '${event.statusCode} ',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: event.statusCode! >= 400
                                        ? Colors.red
                                        : null,
                                  ),
                                ),
                              Text(
                                '${event.duration.inMilliseconds}ms',
                                style: const TextStyle(fontSize: 11),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                event.timestamp.toString().split('.').first,
                                style: const TextStyle(fontSize: 10),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            NetworkMonitor().clear();
            setState(() => _events.clear());
          },
          child: const Text('Clear All'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
