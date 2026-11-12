#!/bin/bash
# Download every tool in tools.toml into .tools/ and link its executable into .tools/bin/. A tool whose version is already in .tools/ is not downloaded again.
#
#   maintenance/tools/install-tools.sh
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
tools="$root/.tools"
mkdir -p "$tools/bin"

# tools.toml holds only flat tables of quoted strings, so awk reads it and the script needs no TOML library. Each output line: name repo version file.
entries="$(awk '
    /^[[:space:]]*(#|$)/ { next }
    /^\[.+\]$/ { if (name != "") print name, repo, version, file; name = substr($0, 2, length($0) - 2); repo = version = file = ""; next }
    match($0, /^[[:space:]]*(repo|version|file)[[:space:]]*=[[:space:]]*"[^"]*"/) {
        key = $1; sub(/=.*/, "", key)
        value = $0; sub(/^[^"]*"/, "", value); sub(/".*/, "", value)
        if (key == "repo") repo = value; else if (key == "version") version = value; else file = value
        next
    }
    { print "tools.toml: cannot read line " NR ": " $0 > "/dev/stderr"; exit 1 }
    END { if (name != "") print name, repo, version, file }
' "$root/tools.toml")"

while read -r name repo version file; do
    if [ -z "$repo" ] || [ -z "$version" ] || [ -z "$file" ]; then
        echo "tools.toml: [$name] needs repo, version and file" >&2
        exit 1
    fi
    dir="$tools/$name/$version"
    if [ ! -x "$dir/$name" ]; then
        echo "Installing $name $version from $repo"
        rm -rf "$dir"
        mkdir -p "$dir"
        # The authors publish no checksum for every file (SwiftFormat has none), so a download is trusted by its version tag over HTTPS.
        curl --fail --silent --show-error --location --output "$dir/$file" "https://github.com/$repo/releases/download/$version/$file"
        unzip -q -o "$dir/$file" -d "$dir"
        rm "$dir/$file"
        if [ ! -x "$dir/$name" ]; then
            echo "$repo $version: $file holds no executable named $name at its top level" >&2
            exit 1
        fi
    fi
    ln -sfn "../$name/$version/$name" "$tools/bin/$name"
done <<<"$entries"

# The commands in maintenance/code-style/ compare this copy with tools.toml to see that a pin moved since the last install.
cp "$root/tools.toml" "$tools/tools.toml"
