#!/bin/bash

echo "Running Flutter analyze..."
flutter analyze
if [ $? -ne 0 ]; then
  echo "Linting failed"
  exit 1
fi

echo "Running Flutter tests..."
flutter test
if [ $? -ne 0 ]; then
  echo "Tests failed"
  exit 1
fi

echo "Building for macOS..."
flutter build macos
if [ $? -ne 0 ]; then
  echo "Build failed"
  exit 1
fi

echo "Checking GitHub Actions workflows..."
curl -L -o actionlint.tar.gz https://github.com/rhysd/actionlint/releases/download/v1.7.1/actionlint_1.7.1_darwin_amd64.tar.gz
tar -xzf actionlint.tar.gz
./actionlint .github/workflows/*.yml
if [ $? -ne 0 ]; then
  echo "Workflow linting failed"
  rm actionlint actionlint.tar.gz
  exit 1
fi
rm actionlint actionlint.tar.gz

echo "All checks passed!"
