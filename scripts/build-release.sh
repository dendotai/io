#!/usr/bin/env bash
# Builds, signs, and notarizes the app, and writes dist/io.zip and dist/appcast.xml. semantic-release runs it in its prepare step, so a failure here publishes nothing. See RELEASING.md.
set -euo pipefail

version=$1
: "${DEVELOPER_ID_APPLICATION_CERTIFICATE:?base64 of the .p12 file}"
: "${DEVELOPER_ID_APPLICATION_PASSWORD:?}"
: "${ASC_KEY:?text of the .p8 file}"
: "${ASC_KEY_ID:?}"
: "${ASC_ISSUER_ID:?}"
: "${SPARKLE_EDDSA_PRIVATE_KEY:?}"

root=$(git rev-parse --show-toplevel)
dist=$root/dist
work=$(mktemp -d)
keychain=$work/signing.keychain-db
cleanup() {
  security delete-keychain "$keychain" 2>/dev/null || true
  rm -rf "$work"
}
trap cleanup EXIT

# A local run reuses packages it already fetched, because a fetch into an empty folder can open a login keychain dialog.
packages=${SOURCE_PACKAGES_DIR:-$work/packages}
package_flags=(-disableAutomaticPackageResolution)
if [ -n "${SOURCE_PACKAGES_DIR:-}" ]; then
  package_flags+=(-skipPackageUpdates)
fi

xcodebuild -quiet -project "$root/io.xcodeproj" -scheme io -configuration Release \
  -derivedDataPath "$work/build" -clonedSourcePackagesDirPath "$packages" "${package_flags[@]}" \
  MARKETING_VERSION="$version" CURRENT_PROJECT_VERSION="$version" \
  SWIFT_ACTIVE_COMPILATION_CONDITIONS=PUBLISHED_RELEASE \
  build

app=$work/build/Build/Products/Release/io.app
sparkle=$app/Contents/Frameworks/Sparkle.framework
sparkle_bin=$packages/artifacts/sparkle/Sparkle/bin

keychain_password=$(uuidgen)
security create-keychain -p "$keychain_password" "$keychain"
security unlock-keychain -p "$keychain_password" "$keychain"
base64 -d <<<"$DEVELOPER_ID_APPLICATION_CERTIFICATE" >"$work/certificate.p12"
security import "$work/certificate.p12" -k "$keychain" -P "$DEVELOPER_ID_APPLICATION_PASSWORD" -T /usr/bin/codesign >/dev/null
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$keychain_password" "$keychain" >/dev/null

sign() {
  codesign --force --timestamp --options runtime --keychain "$keychain" --sign "Developer ID Application" "$@"
}
# Inside out, in the order Sparkle's documentation gives for a re-sign. xcodebuild leaves ad-hoc signatures with no hardened runtime, and notarization requires a Developer ID signature with it.
sign "$sparkle/Versions/B/XPCServices/Installer.xpc"
sign --preserve-metadata=entitlements "$sparkle/Versions/B/XPCServices/Downloader.xpc"
sign "$sparkle/Versions/B/Autoupdate"
sign "$sparkle/Versions/B/Updater.app"
sign "$sparkle"
sign "$app"
codesign --verify --deep --strict "$app"

printf '%s' "$ASC_KEY" >"$work/asc-key.p8"
notary_key=(--key "$work/asc-key.p8" --key-id "$ASC_KEY_ID" --issuer "$ASC_ISSUER_ID")
ditto -c -k --sequesterRsrc --keepParent "$app" "$work/notarize.zip"
# `notarytool --wait` exits 0 on a rejected build too, so the status is read from its output.
submission=$(xcrun notarytool submit "$work/notarize.zip" "${notary_key[@]}" --wait --output-format json)
status=$(jq -r .status <<<"$submission")
if [ "$status" != Accepted ]; then
  xcrun notarytool log "$(jq -r .id <<<"$submission")" "${notary_key[@]}"
  echo "notarization status: $status" >&2
  exit 1
fi
xcrun stapler staple "$app"
spctl --assess --type execute --verbose "$app"

rm -rf "$dist"
mkdir -p "$dist"
ditto -c -k --sequesterRsrc --keepParent "$app" "$dist/io.zip"
"$sparkle_bin/generate_appcast" --ed-key-file - \
  --download-url-prefix "https://github.com/dendotai/io/releases/download/v$version/" \
  --maximum-deltas 0 "$dist" <<<"$SPARKLE_EDDSA_PRIVATE_KEY"
# semantic-release skips a missing asset and publishes without it, and the feed must never lack its update.
test -s "$dist/io.zip"
test -s "$dist/appcast.xml"
