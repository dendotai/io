#if DEBUG
    import AppKit
    import SwiftUI

    enum PanelSnapshot {
        /// Draws the content on the Sound menu's measured light background, (252, 252, 252).
        static func write(_ view: some View, to url: URL) {
            let hosting = NSHostingView(rootView: view.background(Color(white: 252 / 255)))
            hosting.appearance = NSAppearance(named: .aqua)
            hosting.setFrameSize(hosting.fittingSize)
            let window = NSWindow(contentRect: hosting.frame, styleMask: .borderless, backing: .buffered, defer: false)
            window.contentView = hosting
            hosting.layoutSubtreeIfNeeded()
            guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else { return }
            hosting.cacheDisplay(in: hosting.bounds, to: rep)
            try? rep.representation(using: .png, properties: [:])?.write(to: url)
        }
    }
#endif
