// SPDX-License-Identifier: MIT
//
// Copyright 2026 bniladridas. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Password'),
        content: Text(
          'Delete password for ${credential.username} on ${credential.origin}?',
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete All Passwords'),
        content: const Text(
          'This will permanently delete all saved passwords. This action cannot be undone.',
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Password Vault'),
        actions: [
          if (_credentials.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: 'Delete All',
              onPressed: _deleteAll,
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Search',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
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
                          style: Theme.of(context).textTheme.bodyLarge,
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
  bool _showPassword = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        title: Text(widget.credential.origin),
        subtitle: Text(widget.credential.username),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Username: ${widget.credential.username}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 20),
                      tooltip: 'Copy username',
                      onPressed: widget.onCopyUsername,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Password: ${_showPassword ? widget.credential.password : '••••••••'}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _showPassword ? Icons.visibility_off : Icons.visibility,
                        size: 20,
                      ),
                      tooltip: _showPassword ? 'Hide' : 'Show',
                      onPressed: () => setState(() => _showPassword = !_showPassword),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 20),
                      tooltip: 'Copy password',
                      onPressed: widget.onCopyPassword,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.delete),
                      label: const Text('Delete'),
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
