#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/tests
xcrun swiftc -O -target "$(uname -m)-apple-macosx14.0" \
    Ice/MenuBar/Search/MenuBarSearchPolicy.swift \
    Tests/MenuBarSearchPolicyTests.swift \
    -o build/tests/search-policy-tests
build/tests/search-policy-tests
