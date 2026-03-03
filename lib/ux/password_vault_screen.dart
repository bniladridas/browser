// SPDX-License-Identifier: MIT
//
// Copyright 2026 bniladridas. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../features/password_storage.dart';
import '../logging/logger.dart';

class PasswordVaultScreen extends StatefulWidget {
  const PasswordVaultScreen({
    super.key,
    PasswordStorageRepository? repository,
  }) : _repository = repository;

  final PasswordStorageRepository? _repository;

  @override
  State<PasswordVaultScreen> createState() => _PasswordVaultScreenState();
}

class _PasswordVaultScreenState extends State<PasswordVaultScreen> {
  static const double _kMacOsTopToolbarInset = 24.0;
  static const double _kMacOsLeadingWidth = 86.0;
  late final PasswordStorageRepository _repository;
  List<PasswordCredential> _credentials = [];
  bool _loading = true;
  String _searchQuery = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _repository = widget._repository ?? PasswordStorageRepository();
    _loadCredentials();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadCredentials() async {
    setState(() => _loading = true);
    try {
      final credentials = await _repository.listCredentials();
      if (mounted) {
        setState(() {
          _credentials = credentials;
          _loading = false;
        });
      }
    } catch (e, s) {
      logger.e('Failed to load credentials', error: e, stackTrace: s);
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  List<PasswordCredential> get _filteredCredentials {
    if (_searchQuery.isEmpty) return _credentials;
    final query = _searchQuery.toLowerCase();
    return _credentials.where((cred) {
      return cred.origin.toLowerCase().contains(query) ||
          cred.username.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _deleteCredential(PasswordCredential credential) async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Password',
          style: theme.textTheme.titleSmall?.copyWith(fontSize: 15),
        ),
        content: Text(
          'Delete password for ${credential.username} on ${credential.origin}?',
          style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _repository.deleteCredential(credential.id);
      await _loadCredentials();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password deleted')),
        );
      }
    }
  }

  Future<void> _deleteAll() async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete All Passwords',
          style: theme.textTheme.titleSmall?.copyWith(fontSize: 15),
        ),
        content: Text(
          'This will permanently delete all saved passwords. This action cannot be undone.',
          style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _repository.clearAllCredentials();
      await _loadCredentials();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All passwords deleted')),
        );
      }
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMacDesktop = defaultTargetPlatform == TargetPlatform.macOS;
    final topToolbarInset = isMacDesktop ? _kMacOsTopToolbarInset : 0.0;

    final appBar = AppBar(
      leadingWidth: isMacDesktop ? _kMacOsLeadingWidth : null,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, size: 20),
        visualDensity: VisualDensity.compact,
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      titleSpacing: isMacDesktop ? 0 : null,
      title: Text(
        'Password Vault',
        style: theme.textTheme.titleSmall?.copyWith(fontSize: 15),
      ),
      actions: [
        if (_credentials.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.delete_sweep, size: 20),
            tooltip: 'Delete All',
            visualDensity: VisualDensity.compact,
            onPressed: _deleteAll,
          ),
      ],
    );

    return Scaffold(
      appBar: topToolbarInset > 0
          ? PreferredSize(
              preferredSize: Size.fromHeight(kToolbarHeight + topToolbarInset),
              child: Column(
                children: [
                  Container(
                    height: topToolbarInset,
                    color: theme.colorScheme.surface,
                  ),
                  appBar,
                ],
              ),
            )
          : appBar,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
            child: TextField(
              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Search',
                isDense: true,
                prefixIcon: const Icon(Icons.search, size: 18),
                prefixIconConstraints:
                    const BoxConstraints(minHeight: 30, minWidth: 34),
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) {
                if (_debounce?.isActive ?? false) _debounce!.cancel();
                _debounce = Timer(const Duration(milliseconds: 300), () {
                  setState(() => _searchQuery = value);
                });
              },
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filteredCredentials.isEmpty
                    ? Center(
                        child: Text(
                          _searchQuery.isEmpty
                              ? 'No saved passwords'
                              : 'No matching passwords',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontSize: 13),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredCredentials.length,
                        itemBuilder: (context, index) {
                          final credential = _filteredCredentials[index];
                          return _PasswordTile(
                            credential: credential,
                            onDelete: () => _deleteCredential(credential),
                            onCopyUsername: () => _copyToClipboard(
                              credential.username,
                              'Username',
                            ),
                            onCopyPassword: () => _copyToClipboard(
                              credential.password,
                              'Password',
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _PasswordTile extends StatefulWidget {
  const _PasswordTile({
    required this.credential,
    required this.onDelete,
    required this.onCopyUsername,
    required this.onCopyPassword,
  });

  final PasswordCredential credential;
  final VoidCallback onDelete;
  final VoidCallback onCopyUsername;
  final VoidCallback onCopyPassword;

  @override
  State<_PasswordTile> createState() => _PasswordTileState();
}

class _PasswordTileState extends State<_PasswordTile> {
  static const double _kCardHorizontalMargin = 12.0;
  static const double _kCardVerticalMargin = 5.0;
  static const double _kTileHorizontalPadding = 10.0;
  static const double _kTileVerticalPadding = 2.0;
  static const double _kBodyHorizontalPadding = 12.0;
  static const double _kBodyBottomPadding = 10.0;
  static const double _kTitleFontSize = 12.0;
  static const double _kSubtitleFontSize = 11.0;
  static const double _kBodyFontSize = 12.0;
  static const double _kIconButtonSize = 18.0;
  static const double _kDeleteIconSize = 16.0;
  static const double _kSectionSpacing = 6.0;
  static const double _kFooterSpacing = 10.0;
  bool _showPassword = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: _kCardHorizontalMargin,
        vertical: _kCardVerticalMargin,
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(
          horizontal: _kTileHorizontalPadding,
          vertical: _kTileVerticalPadding,
        ),
        childrenPadding: EdgeInsets.zero,
        title: Text(
          widget.credential.origin,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontSize: _kTitleFontSize,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          widget.credential.username,
          style:
              theme.textTheme.bodySmall?.copyWith(fontSize: _kSubtitleFontSize),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              _kBodyHorizontalPadding,
              0,
              _kBodyHorizontalPadding,
              _kBodyBottomPadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Username: ${widget.credential.username}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(fontSize: _kBodyFontSize),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: _kIconButtonSize),
                      tooltip: 'Copy username',
                      visualDensity: VisualDensity.compact,
                      onPressed: widget.onCopyUsername,
                    ),
                  ],
                ),
                const SizedBox(height: _kSectionSpacing),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Password: ${_showPassword ? widget.credential.password : '••••••••'}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(fontSize: _kBodyFontSize),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _showPassword ? Icons.visibility_off : Icons.visibility,
                        size: _kIconButtonSize,
                      ),
                      tooltip: _showPassword ? 'Hide' : 'Show',
                      visualDensity: VisualDensity.compact,
                      onPressed: () =>
                          setState(() => _showPassword = !_showPassword),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: _kIconButtonSize),
                      tooltip: 'Copy password',
                      visualDensity: VisualDensity.compact,
                      onPressed: widget.onCopyPassword,
                    ),
                  ],
                ),
                const SizedBox(height: _kFooterSpacing),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.delete, size: _kDeleteIconSize),
                      label: Text(
                        'Delete',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(fontSize: _kBodyFontSize),
                      ),
                      onPressed: widget.onDelete,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
