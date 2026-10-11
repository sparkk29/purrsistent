#!/usr/bin/env bash
# Runs the test suite. With only the Command Line Tools installed, Swift Testing lives outside
# the compiler's default search paths, so point the compiler and linker at it.
set -euo pipefail

cd "$(dirname "$0")/.."
FRAMEWORKS="$(xcode-select -p)/Library/Developer/Frameworks"
if [ -d "$FRAMEWORKS/Testing.framework" ]; then
    exec swift test -Xswiftc -F -Xswiftc "$FRAMEWORKS" -Xlinker -rpath -Xlinker "$FRAMEWORKS" "$@"
fi
exec swift test "$@"
