import AppKit

/// sound-menu-backdrop <seconds> [grey 0-1 or r,g,b 0-1]: covers the main display below the menu bar with one plain grey, under menus and above other windows, so a capture of a menu's glass reads the same over any desktop. Run with `swift scripts/sound-menu-backdrop.swift 60`.
let args = CommandLine.arguments
guard args.count > 1, let seconds = Double(args[1]) else {
    FileHandle.standardError.write(Data("usage: sound-menu-backdrop <seconds> [grey 0-1 or r,g,b 0-1]\n".utf8))
    exit(1)
}

let parts = (args.count > 2 ? args[2] : "0.5").split(separator: ",").compactMap { Double($0) }
let rgb = parts.count == 3 ? parts : [parts.first ?? 0.5, parts.first ?? 0.5, parts.first ?? 0.5]
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
// The screen with the menu bar, where the Sound menu and a status item menu open; `NSScreen.main` is the screen with the key window, which can be another display.
let screen = NSScreen.screens[0]
let window = NSWindow(contentRect: screen.visibleFrame, styleMask: .borderless, backing: .buffered, defer: false)
window.backgroundColor = NSColor(srgbRed: rgb[0], green: rgb[1], blue: rgb[2], alpha: 1)
window.level = .floating
window.ignoresMouseEvents = true
window.collectionBehavior = [.canJoinAllSpaces, .stationary]
window.orderFrontRegardless()
DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { app.terminate(nil) }
app.run()
