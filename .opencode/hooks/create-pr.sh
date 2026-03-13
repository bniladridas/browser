#!/bin/bash
# Script to create a PR using configuration from .opencode/config.yaml

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPENCODE_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$OPENCODE_DIR/config.yaml"
TEMPLATE_FILE="$OPENCODE_DIR/templates/pr-description.md"

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: $CONFIG_FILE not found."
    exit 1
fi

# Check if template file exists
if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "Error: $TEMPLATE_FILE not found."
    exit 1
fi

# Prompt for PR title interactively
read -p "Enter your PR title: " PR_TITLE

# Validate PR title (check for prohibited words)
if printf "%s\n" "$PR_TITLE" | grep -qiw "add"; then
    echo "ERROR: PR title contains 'add'. Use alternative verbs like integrate, implement, include, etc."
    exit 1
fi

# Validate PR title format (type[scope] :: description)
if ! printf "%s\n" "$PR_TITLE" | grep -E "^(feat|fix|docs|refactor|chore|deps|perf|ci|build|revert)\[[a-zA-Z0-9]+\]\ ::\ .+" > /dev/null; then
    echo "ERROR: PR title must follow format: type[scope] :: description"
    exit 1
fi

# Create the PR using the template
gh pr create \
    --base main \
    --head "$(git branch --show-current)" \
    --title "$PR_TITLE" \
    --body-file "$TEMPLATE_FILE"

echo "PR created successfully!"
