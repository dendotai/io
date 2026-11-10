#!/bin/sh
# Builds the harness beside this script, with the Priority package sources as a library and the real icon view.
cd "$(dirname "$0")"
repo="$(git rev-parse --show-toplevel)"
swiftc -O -parse-as-library -module-name Priority -emit-module -emit-library -o libPriority.dylib "$repo"/Packages/Priority/Sources/Priority/*.swift
swiftc -O -I . -L . -lPriority -Xlinker -rpath -Xlinker . -o harness "$repo"/io/MenuBarIcon/MenuBarIconView.swift "$repo"/io/MenuBarIcon/MenuBarIconPieceView.swift "$repo"/io/MenuBarIcon/MenuBarIconPieces.swift main.swift
