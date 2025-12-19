#!/bin/bash
# SPDX-License-Identifier: MIT
#
# Copyright 2025 bniladridas. All rights reserved.
# Use of this source code is governed by a MIT license that can be
# found in the LICENSE file.

echo "Running integration tests..."

if [[ "$OSTYPE" == "darwin"* ]]; then
    test_target="integration_test/app_test.dart"
    echo "On macOS, running only app_test.dart due to webview issues."
else
    test_target="integration_test/"
fi

if flutter test $test_target; then
    echo "$test_target passed!"
else
    echo "$test_target failed. Check the output above for details."
    exit 1
fi
