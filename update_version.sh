#!/bin/bash
# Script to update pubspec.yaml version from VERSION file

if [ ! -f VERSION ]; then
  echo "VERSION file not found"
  exit 1
fi

VERSION=$(cat VERSION)
sed -i '' "s/^version: .*/version: $VERSION/" pubspec.yaml
echo "Updated pubspec.yaml version to $VERSION"
