#!/usr/bin/env bash
# Builds the app the way a release does, and leaves <out-dir>/io.app, <out-dir>/sparkle-bin and <out-dir>/xcodebuild.log. A pull request's `build` job and scripts/build-release.sh both run it, so a flag cannot reach one and miss the other. <out-dir> and SOURCE_PACKAGES_DIR are absolute paths, because the symlink's target resolves from <out-dir>, and <out-dir> holds no earlier build, because `mv` would nest the new app in the old one. See RELEASING.md.
set -euo pipefail

version=$1
out=$2

root=$(git rev-parse --show-toplevel)

# A local run reuses packages it already fetched, because a fetch into an empty folder can open a login keychain dialog.
packages=${SOURCE_PACKAGES_DIR:-$out/packages}
package_flags=(-disableAutomaticPackageResolution)
if [ -n "${SOURCE_PACKAGES_DIR:-}" ]; then
  package_flags+=(-skipPackageUpdates)
fi

mkdir -p "$out"
# The full output goes to <out-dir>/xcodebuild.log, because the `build` job runs maintenance/code-style/analyze-swift.sh on the compiler calls it holds, which `-quiet` leaves out.
if ! xcodebuild -project "$root/io.xcodeproj" -scheme io -configuration Release \
  -derivedDataPath "$out/build" -clonedSourcePackagesDirPath "$packages" "${package_flags[@]}" \
  MARKETING_VERSION="$version" CURRENT_PROJECT_VERSION="$version" \
  SWIFT_ACTIVE_COMPILATION_CONDITIONS=PUBLISHED_RELEASE \
  build >"$out/xcodebuild.log" 2>&1; then
  grep -E '^/.*: error: ' "$out/xcodebuild.log" | sort -u >&2 || tail -n 40 "$out/xcodebuild.log" >&2
  exit 1
fi
# Warnings stay visible in the job's output, while the log holds the rest.
grep -E '^/.*: warning: ' "$out/xcodebuild.log" | sort -u >&2 || true

mv "$out/build/Build/Products/Release/io.app" "$out/io.app"
ln -s "$packages/artifacts/sparkle/Sparkle/bin" "$out/sparkle-bin"
# `ln -s` succeeds on a missing target, and a pull request runs nothing else that reads this path.
test -x "$out/sparkle-bin/generate_appcast"
