# The panel is an AppKit NSMenu with SwiftUI content

The panel opens from an `NSStatusItem` as an `NSMenu` with one `NSMenuItem` whose view is an `NSHostingView` of the SwiftUI content, sized from that content. The panel copies the system Sound menu, which the ControlCenter process draws with private code; an `NSMenu` is the public way to get the same corners, glass, shadow, gap below the menu bar, closing on a click outside, and the move to the next menu when the pointer hovers another menu bar icon. Drag-to-reorder works in SwiftUI rows inside an `NSMenuItem` view: a test app reordered rows with both `List.onMove` and a `DragGesture`, and the menu stayed open during the drag, on macOS 27.

Open: whether the menu grows while open when the AirPods row folds open. The ticket that adds the fold checks it.

## Considered options

- SwiftUI `MenuBarExtra` with `.window` style: in tobi/AudioPriorityBar its popup opened empty, collapsed, kept empty bands above and below the content, and dragged rows slowly on macOS 26, judging by that repo's fix pull requests (#22, #23, #30, #33, #35, #37).
- `NSPopover`: draws an arrow the Sound menu lacks, and stays open on a click in another app while io is a background app. Hiding the arrow needs the private `shouldHideAnchor` setting, which can break in any macOS update.
- A borderless `NSPanel` with an `NSGlassEffectView` background: its corners, shadow, and closing behaviour differ from the Sound menu, and each needs its own code to come close.
