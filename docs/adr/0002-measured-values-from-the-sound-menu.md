# A value copied from the Sound menu comes from an Accessibility frame or one crop

The panel copies the system Sound menu's look (ADR 0001). A size (an element's width, height, position, or pitch) comes from the Accessibility frames of the open Sound menu, read once into `docs/sound-menu.md` with the element, the output in use, the mode, and the macOS version; an element the tree does not list, such as the text and glyphs inside a row, takes its size from one 2x crop. A colour, a radius, or an opacity comes from one crop of a screenshot that shows io's panel beside the open Sound menu, only where the screenshot shows a difference, and lands in the same doc. An animation comes from a recording, by the ticket that animates. A constant in the code that holds such a value names its element in the doc.

Why: macOS draws both menus from the same parts (the menu font, the label and accent colours, the SF Symbols, the menu glass), so a colour measured from pixels only says which system part it was, and the Accessibility tree gives a size in points in one command, where a pixel read guesses an edge.

The check of a ticket is one screenshot of io's panel beside the open Sound menu, in Light and Dark Mode, read by eye. A difference the eye sees but cannot size gets one number from the doc or from one crop. The whole panel is in every screenshot, so a change to an earlier element shows in the next ticket's check.

## Rejected

- A script and run that measure every element of both menus in every output, mode, and state: ten minutes a run on one Mac, with the pointer and the AirPods dialog in it; one fault anywhere costs the whole run; its last result was 261 differences in 264 values, none acted on. The routes that run itself rejected: System Events on Control Center, the icon found by pixels, posted clicks, Control-arrow Spaces.
- A store of every measured value (269 keys): no code read it, and a value with no element and method named beside it leads the next ticket to match a wrong number.
- A snapshot test of io's offscreen render as the regression check: the render has no menu glass, corners, or system highlight and draws shadows upside down, and a mismatch across macOS versions or machines invites tolerance thresholds, a measuring tool again. It returns only if a regression slips past the whole-panel screenshot, with the rule that a mismatch is re-recorded after a look at both images, never tolerated.
