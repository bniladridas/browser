#!/bin/bash
# SPDX-License-Identifier: MIT
#
# Copyright 2025 bniladridas. All rights reserved.
# Use of this source code is governed by a MIT license that can be
# found in the LICENSE file.

echo "Running integration tests..."

if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "On macOS, running only app_test.dart due to webview issues."
    if flutter test integration_test/app_test.dart; then
        echo "app_test.dart passed!"
    else
        echo "app_test.dart failed. Check the output above for details."
        exit 1
    fi
else
    if flutter test integration_test/; then
        echo "All tests passed!"
    else
        echo "Tests failed. Check the output above for details."
        exit 1
    fi
fi
