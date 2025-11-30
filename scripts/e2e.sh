#!/bin/bash
# SPDX-License-Identifier: MIT
#
# Copyright 2025 bniladridas. All rights reserved.
# Use of this source code is governed by a MIT license that can be
# found in the LICENSE file.

echo "Running integration tests..."

if flutter test integration_test/app_test.dart; then
    echo "All tests passed!"
else
    echo "Tests failed. Check the output above for details."
    exit 1
fi
