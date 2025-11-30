# Development Setup

This directory contains tools and configurations for development.

## Setup

1. Install Flutter: https://flutter.dev/docs/get-started/install
2. Clone the repo
3. Run `./scripts/e2e.sh` for e2e tests
4. Run `./scripts/test.sh` for unit tests

## Scripts

- `scripts/version.sh`: Bump version
- `scripts/pubspec.sh`: Update pubspec
- `scripts/e2e.sh`: Run e2e tests
- `scripts/test.sh`: Run version tests

## Workflows

- `flutter.yml`: CI for build and tests
- `e2e.yml`: E2E tests
- `auto-label.yml`: Auto-label PRs
- `lint.yml`: Lint YAML files
- `version-bump.yml`: Version bumping