// SPDX-License-Identifier: MIT
//
// Copyright 2026 bniladridas. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:collection';
import 'package:flutter/material.dart';
import '../utils/string_utils.dart';
import '../logging/network_monitor.dart';

class NetworkDebugDialog extends StatefulWidget {
  const NetworkDebugDialog({super.key});

  @override
  State<NetworkDebugDialog> createState() => _NetworkDebugDialogState();
}

class _NetworkDebugDialogState extends State<NetworkDebugDialog> {
  late final StreamSubscription<NetworkEvent> _subscription;
  final _events = ListQueue<NetworkEvent>();

  @override
  void initState() {
    super.initState();
    _events.addAll(NetworkMonitor().recentEvents);
    _subscription = NetworkMonitor().events.listen((event) {
      if (mounted) {
        setState(() {
          _events.addLast(event);
          if (_events.length > 50) {
            _events.removeFirst();
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
    final theme = Theme.of(context);
    const compactDensity = VisualDensity(horizontal: -2, vertical: -2);
    final failedEvents = _events.where((e) => !e.success).toList();

    return AlertDialog(
      title: Row(
        children: [
          Text(
            'Network Debug',
            style: theme.textTheme.titleSmall?.copyWith(fontSize: 15),
          ),
          const Spacer(),
          RawChip(
            visualDensity: compactDensity,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            label: Text(
              '${NetworkMonitor().successCount} ok',
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
            ),
            backgroundColor: Colors.green.withValues(alpha: 0.2),
          ),
          const SizedBox(width: 6),
          RawChip(
            visualDensity: compactDensity,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            label: Text(
              '${NetworkMonitor().failureCount} fail',
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontSize: 10, color: Colors.red),
            ),
            backgroundColor: Colors.red.withValues(alpha: 0.2),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 340,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (failedEvents.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                color: Colors.red.withValues(alpha: 0.1),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      '${failedEvents.length} failed requests',
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
            ],
            Expanded(
              child: _events.isEmpty
                  ? Center(
                      child: Text(
                        'No network activity yet',
                        style:
                            theme.textTheme.bodySmall?.copyWith(fontSize: 12),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _events.length,
                      itemBuilder: (context, index) {
                        final event = _events.toList()[index];
                        return ListTile(
                          dense: true,
                          visualDensity: compactDensity,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 6),
                          minLeadingWidth: 18,
                          leading: Icon(
                            event.success ? Icons.check_circle : Icons.error,
                            color: event.success ? Colors.green : Colors.red,
                            size: 16,
                          ),
                          title: Text(
                            '${event.method} ${event.url.truncate(50)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                              color: event.success ? null : Colors.red,
                            ),
                          ),
                          subtitle: Row(
                            children: [
                              if (event.statusCode != null)
                                Text(
                                  '${event.statusCode} ',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontSize: 10,
                                    color: event.statusCode! >= 400
                                        ? Colors.red
                                        : null,
                                  ),
                                ),
                              Text(
                                '${event.duration.inMilliseconds}ms',
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(fontSize: 10),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                event.timestamp.toString().split('.').first,
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(fontSize: 9),
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
