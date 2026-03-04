#!/bin/bash
# SPDX-License-Identifier: MIT
#
# Copyright 2026 bniladridas. All rights reserved.
# Use of this source code is governed by a MIT license that can be
# found in the LICENSE file.

echo "Running integration tests..."

test_target="integration_test/"
artifact_dir="${E2E_ARTIFACT_DIR:-build/e2e-artifacts}"
app_bundle_id="${E2E_APP_BUNDLE_ID:-com.example.browser}"
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
    log_contains_startup_attach_failure() {
        grep -q "Error waiting for a debug connection" "$1" || \
            grep -q "Unable to start the app on the device" "$1" || \
            grep -q "The log reader stopped unexpectedly, or never started" "$1"
    }
    prepare_retry_environment() {
        # Best-effort cleanup for flaky macOS startup/attach failures in CI.
        /usr/bin/pkill -x browser >/dev/null 2>&1 || true
        /usr/bin/pkill -f "FlutterTester" >/dev/null 2>&1 || true
        /usr/bin/pkill -f "xcodebuild" >/dev/null 2>&1 || true
        rm -rf "$HOME/Library/Saved Application State/${app_bundle_id}.savedState" || true
        rm -rf build/macos/Build/Intermediates.noindex/XCBuildData || true
        sleep 2
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
        rm -rf "$HOME/Library/Saved Application State/${app_bundle_id}.savedState" || true
        # Prevent macOS state-restoration modal from blocking app startup after crashes.
        ApplePersistenceIgnoreState=YES \
            flutter test -d macos --dart-define=INTEGRATION_TEST=true $test_target "$@" \
            2>&1 | tee "$E2E_LOG_FILE"
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
    if log_contains_foreground_failure "$log_file" || log_contains_startup_attach_failure "$log_file"; then
        echo "Detected app startup/attach instability. Attempting one retry..."
        prepare_retry_environment
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
