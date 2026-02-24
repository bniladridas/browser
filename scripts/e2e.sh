#!/bin/bash
# SPDX-License-Identifier: MIT
#
# Copyright 2026 bniladridas. All rights reserved.
# Use of this source code is governed by a MIT license that can be
# found in the LICENSE file.

echo "Running integration tests..."

test_target="integration_test/"

if [[ "$OSTYPE" == "darwin"* ]]; then
    if [[ -z "${DISPLAY:-}" ]] && ! /usr/bin/pgrep -x "WindowServer" >/dev/null 2>&1; then
        echo "No interactive macOS GUI session detected. Failing e2e tests."
        exit 1
    fi
    echo "Running integration tests on macOS device..."
    log_file="$(mktemp -t flutter-e2e.XXXXXX.log)"
    flutter test -d macos $test_target 2>&1 | tee "$log_file"
    test_status=${PIPESTATUS[0]}
    if [[ $test_status -eq 0 ]]; then
        echo "$test_target passed!"
        rm -f "$log_file"
        exit 0
    else
        echo "$test_target failed. Check the output above for details."
        log_contains_foreground_failure() {
            if command -v rg >/dev/null 2>&1; then
                rg -q "Failed to foreground app; open returned 1" "$1"
            else
                grep -q "Failed to foreground app; open returned 1" "$1"
            fi
        }
        if log_contains_foreground_failure "$log_file"; then
            echo "Foreground failed. Attempting to clear quarantine and retry once..."
            app_path="build/macos/Build/Products/Debug/browser.app"
            if [[ -d "$app_path" ]]; then
                xattr -dr com.apple.quarantine "$app_path" || true
            fi
            rm -f "$log_file"
            log_file="$(mktemp -t flutter-e2e.XXXXXX.log)"
            flutter test -d macos $test_target -v 2>&1 | tee "$log_file"
            retry_status=${PIPESTATUS[0]}
            if [[ $retry_status -eq 0 ]]; then
                echo "$test_target passed!"
                exit 0
            fi
            if log_contains_foreground_failure "$log_file"; then
                echo "E2E requires a foregrounded macOS GUI session. Run from a desktop session."
            fi
            rm -f "$log_file"
            exit $retry_status
        fi
        rm -f "$log_file"
        exit $test_status
    fi
else
    echo "Integration tests are only supported on macOS. Skipping on $OSTYPE."
    exit 0
fi
