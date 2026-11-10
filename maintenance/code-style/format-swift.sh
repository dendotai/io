#!/bin/bash
# Format every Swift file in place with the pinned SwiftFormat and the repo's .swiftformat. With --check, list the files that need formatting and change none.
#
#   maintenance/code-style/format-swift.sh [--check]
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$root"

if [ ! -x .tools/bin/swiftformat ] || ! cmp -s tools.toml .tools/tools.toml; then
    maintenance/tools/install-tools.sh
fi

case "${1:-}" in
    "") exec .tools/bin/swiftformat io Packages scripts ;;
    --check) exec .tools/bin/swiftformat io Packages scripts --lint ;;
    *)
        echo "usage: $0 [--check]" >&2
        exit 2
        ;;
esac
