# The panel is an AppKit NSMenu with SwiftUI content

The panel opens from an `NSStatusItem` as an `NSMenu` with one `NSMenuItem` per section header, device row, separator, and footer, each with an `NSHostingView` of its SwiftUI content as its view. The panel copies the system Sound menu, which the ControlCenter process draws with private code; an `NSMenu` is the public way to get the same corners, glass, shadow, gap below the menu bar, closing on a click outside, and the move to the next menu when the pointer hovers another menu bar icon. One item per row gives a row its own native submenu ("Hide"), which AppKit opens on hover for an item with a custom view. An item's view is cut off at its own frame, so a drag swaps the section's row items for one item that holds the whole section, and the dragged row slides over its neighbours in it. The dragged row's gesture keeps reporting after its item leaves the menu, with a wrong distance, so the drag reads the pointer position instead, on macOS 27. A release that reaches the menu over a row with a submenu keeps that submenu closed until the pointer moves, so the drag swaps the row items back only after the menu has handled the release. Inside an open `NSMenu`, a right-click reaches only `hitTest`, and the pointer stays an arrow (`pointerStyle`, `NSCursor.set`, and a cursor rect tried).

Open: whether the menu grows while open when the AirPods row folds open. The ticket that adds the fold checks it.

## Considered options

- One `NSMenuItem` whose view holds every row: rows slide during a drag, but a row cannot have its own submenu, and a context menu cannot open inside the open menu.
- Moving the dragged row's item to the slot under the pointer as the drag goes: works, but the row jumps one slot at a time instead of sliding.
- SwiftUI `MenuBarExtra` with `.window` style: in tobi/AudioPriorityBar its popup opened empty, collapsed, kept empty bands above and below the content, and dragged rows slowly on macOS 26, judging by that repo's fix pull requests (#22, #23, #30, #33, #35, #37).
- `NSPopover`: draws an arrow the Sound menu lacks, and stays open on a click in another app while io is a background app. Hiding the arrow needs the private `shouldHideAnchor` setting, which can break in any macOS update.
- A borderless `NSPanel` with an `NSGlassEffectView` background: its corners, shadow, and closing behaviour differ from the Sound menu, and each needs its own code to come close.
