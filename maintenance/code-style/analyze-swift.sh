#!/bin/bash
# Run SwiftLint's analyzer rules (`analyzer_rules` in .swiftlint.yml) over a full build log, with --strict, so a finding fails it. With no argument, it does a Debug `clean build` into .scratch/analyze-swift first; CI's `build` job passes the log of its Release build instead.
#
#   maintenance/code-style/analyze-swift.sh [<xcodebuild log>]
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$root"

if [ ! -x .tools/bin/swiftlint ] || ! cmp -s tools.toml .tools/tools.toml; then
    maintenance/tools/install-tools.sh
fi

case $# in
    0)
        out="$root/.scratch/analyze-swift"
        mkdir -p "$out"
        log="$out/xcodebuild.log"
        # A run reuses packages it already fetched, because a fetch into an empty folder can open a login keychain dialog.
        package_flags=(-disableAutomaticPackageResolution -clonedSourcePackagesDirPath "${SOURCE_PACKAGES_DIR:-$out/packages}")
        if [ -n "${SOURCE_PACKAGES_DIR:-}" ]; then
            package_flags+=(-skipPackageUpdates)
        fi
        # `clean`, because a build with nothing to recompile logs no compiler calls, and `unused_declaration` needs every file.
        if ! xcodebuild -project io.xcodeproj -scheme io -configuration Debug -derivedDataPath "$out/DerivedData" \
            "${package_flags[@]}" CODE_SIGNING_ALLOWED=NO clean build >"$log" 2>&1; then
            grep -E '^/.*: error: ' "$log" | sort -u >&2 || tail -n 40 "$log" >&2
            exit 1
        fi
        ;;
    1) log=$1 ;;
    *)
        echo "usage: $0 [<xcodebuild log>]" >&2
        exit 2
        ;;
esac

# A log with no compiler call (an incremental build, or `xcodebuild -quiet`) makes `analyze` pass with no finding.
if ! grep -q 'swiftc .*-module-name io ' "$log"; then
    echo "$log holds no swiftc call for the io module, so analyze would check nothing" >&2
    exit 1
fi

# Findings go to stdout. `analyze` re-runs each compiler call and repeats its warnings on stderr, so stderr is shown only when a failure printed no finding.
analyze_stderr="$log.analyze-stderr"
findings=$(.tools/bin/swiftlint analyze --strict --quiet --compiler-log-path "$log" 2>"$analyze_stderr") && status=0 || status=$?
if [ "$status" -ne 0 ]; then
    if [ -n "$findings" ]; then
        echo "$findings"
    else
        cat "$analyze_stderr" >&2
    fi
fi
rm -f "$analyze_stderr"
exit "$status"
