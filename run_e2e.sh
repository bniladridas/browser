#!/bin/bash

echo "Running integration tests..."

if flutter test integration_test/; then
    echo "All tests passed!"
else
    echo "Tests failed. Check the output above for details."
    exit 1
fi
