// SPDX-License-Identifier: MIT
//
// Copyright 2025 bniladridas. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class VideoManager {
  static Future<void> pauseVideos(InAppWebViewController controller) async {
    debugPrint('Pausing videos');
    try {
      await controller.evaluateJavascript(source: """
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
      debugPrint('Error pausing videos: $e');
      // Ignore errors, e.g., MissingPluginException on macOS
    }
  }

  static Future<void> resumeVideos(InAppWebViewController controller) async {
    debugPrint('Resuming videos');
    try {
      await controller.evaluateJavascript(source: """
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
      debugPrint('Error resuming videos: $e');
      // Ignore errors, e.g., MissingPluginException on macOS
    }
  }
}
