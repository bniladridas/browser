#!/bin/bash
# SPDX-License-Identifier: MIT
#
# Copyright 2026 bniladridas. All rights reserved.
# Use of this source code is governed by a MIT license that can be
# found in the LICENSE file.

echo "Running integration tests..."

test_target="integration_test/"
artifact_dir="${E2E_ARTIFACT_DIR:-build/e2e-artifacts}"
mkdir -p "$artifact_dir"

persist_e2e_log() {
    local src="$1"
    local name="$2"
    if [[ -f "$src" ]]; then
        cp "$src" "$artifact_dir/$name"
    fi
}

if [[ "$OSTYPE" == "darwin"* ]]; then
    if [[ -z "${DISPLAY:-}" ]] && ! /usr/bin/pgrep -x "WindowServer" >/dev/null 2>&1; then
        if [[ "${CI:-}" == "true" || "${GITHUB_ACTIONS:-}" == "true" ]]; then
            echo "No interactive macOS GUI session detected in CI. Continuing anyway."
        else
            echo "No interactive macOS GUI session detected. Failing e2e tests."
            exit 1
        fi
    fi
    echo "Running integration tests on macOS device..."
    log_contains_foreground_failure() {
        grep -q "Failed to foreground app; open returned 1" "$1"
    }
    run_e2e() {
        local attempt_label="$1"
        shift
        # Try to activate GUI session for local interactive runs.
        if [[ "${CI:-}" != "true" && "${GITHUB_ACTIONS:-}" != "true" ]]; then
            /usr/bin/open -a Finder || true
            sleep 1
        fi
        E2E_LOG_FILE="$(mktemp -t flutter-e2e.XXXXXX.log)"
        flutter test -d macos --dart-define=INTEGRATION_TEST=true $test_target "$@" 2>&1 | tee "$E2E_LOG_FILE"
        local status=${PIPESTATUS[0]}
        persist_e2e_log "$E2E_LOG_FILE" "integration-${attempt_label}.log"
        if [[ $status -eq 0 ]]; then
            echo "$test_target passed!"
        else
            echo "$test_target failed. Check the output above for details."
        fi
        return $status
    }

    run_e2e "initial"
    test_status=$?
    log_file="$E2E_LOG_FILE"
    if [[ $test_status -eq 0 ]]; then
        rm -f "$log_file"
        exit 0
    fi
    if log_contains_foreground_failure "$log_file"; then
        echo "Foreground failed. Attempting to clear quarantine and retry once..."
        app_path="build/macos/Build/Products/Debug/browser.app"
        if [[ -d "$app_path" ]]; then
            xattr -dr com.apple.quarantine "$app_path" || true
        fi
        rm -f "$log_file"
        run_e2e "retry" -v
        retry_status=$?
        log_file="$E2E_LOG_FILE"
        if [[ $retry_status -eq 0 ]]; then
            rm -f "$log_file"
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
else
    echo "Integration tests are only supported on macOS. Skipping on $OSTYPE."
    exit 0
fi
