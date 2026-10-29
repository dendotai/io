import AppKit
import OSLog

/// Diagnosis for rows that stay highlighted (https://github.com/dendotai/io/issues/25); the fix deletes it. Read with `/usr/bin/log show --predicate 'subsystem == "ai.den.io"' --last 30m` (zsh has a `log` builtin). `.notice`, because macOS keeps only notice and above on disk.
let panelLog = Logger(subsystem: "ai.den.io", category: "panel")

final class MenuLog: NSObject, NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        panelLog.notice("menu open")
    }

    func menuDidClose(_ menu: NSMenu) {
        panelLog.notice("menu close")
    }
}
