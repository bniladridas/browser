// SPDX-License-Identifier: MIT
//
// Copyright 2025 bniladridas. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

import 'package:webview_flutter/webview_flutter.dart';

import '../logging/logger.dart';

class VideoManager {
  static Future<void> pauseVideos(WebViewController controller) async {
    logger.i('Pausing videos');
    try {
      await controller.runJavaScript("""
        // Save current time and pause HTML5 videos
        document.querySelectorAll('video').forEach(v => {
          v.dataset.savedTime = v.currentTime;
          console.log('Saved time:', v.currentTime);
          v.pause();
        });
        // Pause YouTube videos
        document.querySelectorAll('iframe').forEach(iframe => {
          if (iframe.src && iframe.src.includes('youtube.com')) {
            iframe.contentWindow.postMessage('{"event":"command","func":"pauseVideo","args":""}', '*');
          }
        });
      """);
    } catch (e) {
      logger.e('Error pausing videos: $e');
      // Ignore errors, e.g., MissingPluginException on macOS
    }
  }

  static Future<void> resumeVideos(WebViewController controller) async {
    logger.i('Resuming videos');
    try {
      await controller.runJavaScript("""
        setTimeout(() => {
          // Resume HTML5 videos from saved time
          document.querySelectorAll('video').forEach(v => {
            if (v.dataset.savedTime) {
              v.currentTime = parseFloat(v.dataset.savedTime);
              console.log('Restored time:', v.dataset.savedTime);
            }
            v.play();
          });
          // Resume YouTube videos (seek and play)
          document.querySelectorAll('iframe').forEach(iframe => {
            if (iframe.src && iframe.src.includes('youtube.com')) {
              // Note: YouTube seek requires time, but we can't get it easily; assume play resumes
              iframe.contentWindow.postMessage('{"event":"command","func":"playVideo","args":""}', '*');
            }
          });
        }, 500);
      """);
    } catch (e) {
      logger.e('Error resuming videos: $e');
      // Ignore errors, e.g., MissingPluginException on macOS
    }
  }
}
