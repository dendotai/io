#!/bin/bash
# Lint every Swift file with the pinned SwiftLint and the repo's .swiftlint.yml. --strict makes a warning fail, on the Mac as in CI.
#
#   maintenance/code-style/lint-swift.sh
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$root"

if [ ! -x .tools/bin/swiftlint ] || ! cmp -s tools.toml .tools/tools.toml; then
    maintenance/tools/install-tools.sh
fi

exec .tools/bin/swiftlint lint --strict --quiet
