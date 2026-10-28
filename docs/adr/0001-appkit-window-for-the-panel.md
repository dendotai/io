# The panel is an AppKit borderless window, not SwiftUI's MenuBarExtra

The panel opens from an `NSStatusItem` as a borderless `NSPanel` with an `NSGlassEffectView` background that hosts the SwiftUI content, and takes its height from that content. SwiftUI's `MenuBarExtra` with `.window` style is the shorter path, but in tobi/AudioPriorityBar its popup opened empty, collapsed, kept empty bands above and below the content, and dragged rows slowly on macOS 26, judging by that repo's fix pull requests (#22, #23, #30, #33, #35, #37). The panel's main feature is drag-to-reorder, and its height changes when the AirPods row folds open, so it rests on an AppKit window whose size the app controls. The panel copies the system Sound menu, which opens under the menu bar with no arrow and closes on any click outside it, so the window is borderless and a global mouse monitor closes it.

## Considered options

- `MenuBarExtra` with `.window` style: about 50 fewer lines of glue, rejected for the sizing and drag problems above.
- `NSPopover`: draws an arrow the Sound menu lacks, and stays open on a click in another app while io is a background app. Hiding the arrow needs the private `shouldHideAnchor` setting, which can break in any macOS update.
