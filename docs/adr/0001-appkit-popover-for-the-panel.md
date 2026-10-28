# The panel is an AppKit popover, not SwiftUI's MenuBarExtra

The panel opens from an `NSStatusItem` as an `NSPopover` that hosts the SwiftUI content, and takes its height from that content (`NSHostingController` with its preferred content size). SwiftUI's `MenuBarExtra` with `.window` style is the shorter path, but in tobi/AudioPriorityBar its popup opened empty, collapsed, kept empty bands above and below the content, and dragged rows slowly on macOS 26, judging by that repo's fix pull requests (#22, #23, #30, #33, #35, #37). The panel's main feature is drag-to-reorder, and its height changes when the AirPods row folds open, so it rests on the AppKit popover, whose size the app controls.

## Considered options

- `MenuBarExtra` with `.window` style: about 50 fewer lines of glue, rejected for the sizing and drag problems above.
