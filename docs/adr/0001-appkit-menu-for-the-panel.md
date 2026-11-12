# The panel is an AppKit NSMenu with SwiftUI content

The panel opens from an `NSStatusItem` as an `NSMenu` with one `NSMenuItem` per section header, device row, and separator, each with an `NSHostingView` of its SwiftUI content as its view. The panel copies the system Sound menu, which the ControlCenter process draws with private code; an `NSMenu` is the public way to get the same corners, glass, shadow, gap below the menu bar, closing on a click outside, and the move to the next menu when the pointer hovers another menu bar icon. An item's view is cut off at its own frame, so a drag swaps the section's row items for one item that holds the whole section, and the dragged row slides over its neighbours in it. The dragged row's gesture keeps reporting after its item leaves the menu, with a wrong distance, so the drag reads the pointer position instead, on macOS 27. Inside an open `NSMenu`, a right-click reaches only `hitTest`, and the pointer stays an arrow (`pointerStyle`, `NSCursor.set`, and a cursor rect tried).

The panel stays set as `statusItem.menu`, so that move reaches it. A local event monitor for `.rightMouseDown` sets `statusItem.menu` to the right-click menu just before the native click opens it, and `menuDidClose` sets the panel back.

The menu grows while open when an item's frame changes, so a fold is one item whose height a timer drives; like a drag, it stands in for the rows below it, because they overlap the group.

## Rejected

- One `NSMenuItem` whose view holds every row: rows slide during a drag, but a context menu cannot open inside the open menu.
- Moving the dragged row's item to the slot under the pointer as the drag goes: works, but the row jumps one slot at a time instead of sliding.
- SwiftUI `MenuBarExtra` with `.window` style: in tobi/AudioPriorityBar its popup opened empty, collapsed, kept empty bands above and below the content, and dragged rows slowly on macOS 26, judging by that repo's fix pull requests (#22, #23, #30, #33, #35, #37).
- `NSPopover`: draws an arrow the Sound menu lacks, and stays open on a click in another app while io is a background app. Hiding the arrow needs the private `shouldHideAnchor` setting, which can break in any macOS update.
- A borderless `NSPanel` with an `NSGlassEffectView` background: its corners, shadow, and closing behaviour differ from the Sound menu, and each needs its own code to come close.
- The action route for the right-click menu (an empty `statusItem.menu`, `sendAction(on:)`, and a menu attached per click, the common pattern): a hover from another menu onto the icon opened nothing with no click since launch and nothing after a right-click, and this ADR chose `NSMenu` partly for that move.
