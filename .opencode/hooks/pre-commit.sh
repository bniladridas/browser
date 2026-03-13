#!/bin/bash
# Pre-commit hook that validates commit messages using .opencode/config.yaml

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPENCODE_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$OPENCODE_DIR/config.yaml"

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Warning: $CONFIG_FILE not found. Using default validation."
    exit 0
fi

# Extract validation command from config (using yq or manual parsing)
# For now, use a simple grep to extract the command
VALIDATION_CMD=$(grep -A 1 "validation:" "$CONFIG_FILE" | grep "command:" | cut -d'"' -f2)

if [ -z "$VALIDATION_CMD" ]; then
    echo "Warning: Could not extract validation command from config."
    exit 0
fi

# Get the commit message
COMMIT_MSG_FILE="$1"
COMMIT_MSG=$(head -n 1 "$COMMIT_MSG_FILE")

# Run validation
if eval "$VALIDATION_CMD" <<< "$COMMIT_MSG"; then
    echo "ERROR: Commit validation failed"
    exit 1
fi

exit 0
