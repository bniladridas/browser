// SPDX-License-Identifier: MIT
//
// Copyright 2026 bniladridas. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';

final _versionRegex = RegExp(r'v?(\d+(?:\.\d+)+)');

class UpdateInfo {
  final String version;
  final String downloadUrl;
  final String? checksum;
  final int size;

  UpdateInfo({
    required this.version,
    required this.downloadUrl,
    this.checksum,
    required this.size,
  });
}

class UpdateService {
  static const String _owner = 'bniladridas';
  static const String _repo = 'browser';
  static const String _latestReleaseUrl =
      'https://api.github.com/repos/$_owner/$_repo/releases/latest';

  Future<UpdateInfo?> checkForUpdates() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final response = await http.get(Uri.parse(_latestReleaseUrl));
      if (response.statusCode != 200) {
        throw Exception(
            'Failed to fetch latest release: ${response.statusCode}');
      }

      final data = json.decode(response.body);
      final String tag = data['tag_name'] as String;
      // Extract version: handles 'v1.2.3', 'app-1.2.3', '1.2.3'
      final match = _versionRegex.firstMatch(tag);
      final String latestVersion = match?.group(1) ?? tag.replaceFirst('v', '');

      if (isNewer(currentVersion, latestVersion)) {
        final assets = data['assets'] as List<dynamic>;
        final platformAsset = _getPlatformAsset(assets);
        if (platformAsset != null) {
          String? checksum;
          final assetName = platformAsset['name'] as String;
          final checksumAsset = assets.firstWhere(
            (asset) =>
                (asset['name'] as String).toLowerCase() == '$assetName.sha256',
            orElse: () => null,
          );
          if (checksumAsset != null) {
            final checksumResponse = await http.get(
                Uri.parse(checksumAsset['browser_download_url'] as String));
            if (checksumResponse.statusCode == 200) {
              checksum = checksumResponse.body.trim();
            }
          }

          return UpdateInfo(
            version: latestVersion,
            downloadUrl: platformAsset['browser_download_url'] as String,
            checksum: checksum,
            size: platformAsset['size'] as int,
          );
        }
      }
    } catch (e) {
      debugPrint('Update check failed: $e');
    }
    return null;
  }

  @visibleForTesting
  bool isNewer(String current, String latest) {
    try {
      final currentParts = _parseVersion(current);
      final latestParts = _parseVersion(latest);

      if (currentParts.isEmpty || latestParts.isEmpty) return false;

      final maxLength = currentParts.length > latestParts.length
          ? currentParts.length
          : latestParts.length;
      for (var i = 0; i < maxLength; i++) {
        final c = i < currentParts.length ? currentParts[i] : 0;
        final l = i < latestParts.length ? latestParts[i] : 0;
        if (l > c) return true;
        if (l < c) return false;
      }
    } catch (_) {
      return false;
    }
    return false;
  }

  List<int> _parseVersion(String version) {
    final numericPattern = RegExp(r'\d+');
    final matches = numericPattern.allMatches(version).toList();
    return matches.map((m) => int.tryParse(m.group(0)!) ?? 0).toList();
  }

  Map<String, dynamic>? _getPlatformAsset(List<dynamic> assets) {
    List<String> extensions;
    if (Platform.isMacOS) {
      extensions = ['.dmg', '.pkg'];
    } else if (Platform.isWindows) {
      extensions = ['.exe', '.msi'];
    } else if (Platform.isLinux) {
      extensions = ['.deb', '.rpm', '.tar.gz'];
    } else {
      return null;
    }

    for (final extension in extensions) {
      final asset = assets.firstWhere(
        (asset) => (asset['name'] as String).toLowerCase().endsWith(extension),
        orElse: () => null,
      );
      if (asset != null) return asset;
    }
    return null;
  }

  Future<File?> downloadUpdate(
    String url,
    String version,
    void Function(double progress) onProgress,
    String? expectedChecksum,
  ) async {
    try {
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(url));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw Exception('Download failed: ${response.statusCode}');
      }

      final total = response.contentLength ?? 0;
      var downloaded = 0;

      final tempDir = await getTemporaryDirectory();
      final extension = Platform.isMacOS
          ? '.dmg'
          : Platform.isWindows
              ? '.exe'
              : '.deb';
      final file = File('${tempDir.path}/browser-$version$extension');
      final sink = file.openWrite();

      await response.stream.listen(
        (chunk) {
          downloaded += chunk.length;
          sink.add(chunk);
          if (total > 0) {
            onProgress(downloaded / total);
          }
        },
        onDone: () async {
          await sink.close();
          client.close();

          if (expectedChecksum != null) {
            final bytes = await file.readAsBytes();
            final hash = sha256.convert(bytes);
            final actualChecksum = hash.bytes
                .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
                .join();
            if (actualChecksum != expectedChecksum.toLowerCase()) {
              await file.delete();
              throw Exception('Checksum verification failed');
            }
          }
        },
        onError: (e) async {
          await sink.close();
          client.close();
          await file.delete();
          throw e;
        },
        cancelOnError: true,
      ).asFuture();

      return file;
    } catch (e) {
      debugPrint('Download failed: $e');
      return null;
    }
  }
}
