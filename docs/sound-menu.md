# The Sound menu's measured values

A ticket that copies a value takes it from here; how a value is read, and why not with a script, is ADR 0002. Every frame below comes from the Accessibility tree of the open Sound menu on macOS 27.0.1 on the built-in display, in points, with the top-left corner of the menu's window as the origin. The frames are the same in Light and Dark Mode and for every output in use, except where a cell says otherwise. Each look comes from one 2x screenshot crop in Light Mode.

## Frames

| Element                                                                                 | Size (pt)                                     | Position (pt)                                                                                         | Pitch (pt) | Notes                                                                                                        |
| --------------------------------------------------------------------------------------- | --------------------------------------------- | ----------------------------------------------------------------------------------------------------- | ---------- | ------------------------------------------------------------------------------------------------------------ |
| Sound item in the menu bar                                                              | 22 × 22                                       | 16, 6 inside its 54 × 33 menu bar item                                                                |            | `AXMenuBarItem` with identifier `com.apple.menuextra.sound`, hosted by MenuBarAgent, listed once per display |
| Window                                                                                  | 522 × 1050                                    |                                                                                                       |            | Control Center's transparent window at window layer 101; the visible body is smaller                         |
| Visible body                                                                            | 378 wide, height by output (table below)      | x 147                                                                                                 |            | From the pixel edges of a capture, the one value here not from Accessibility                                 |
| "Volume Lower" button                                                                   | 10 × 14                                       | 199, 41                                                                                               |            |                                                                                                              |
| Slider                                                                                  | 230 × 16                                      | 216, 40                                                                                               |            | Value 0 to 1; no knob while the output in use has no volume control (an aggregate device)                    |
| Knob                                                                                    | 20 × 16                                       | x = 216 + value × 210, y 40                                                                           |            |                                                                                                              |
| "Volume Higher" button                                                                  | 21 × 16                                       | 453, 40                                                                                               |            |                                                                                                              |
| Scroll area                                                                             | 308 wide, height by output                    | 182, 72                                                                                               |            | 35 inside each side of the body                                                                              |
| Heading text ("Output", "Listening Mode", "Spatial Audio", "Conversation Awareness")    | text width × 15                               | x 196, 14 in from the scroll area's left; y 3 below the scroll area's top, 19 below a device row, 13 below a listening mode row |  |                                                                                                   |
| Device row                                                                              | 298 × 32                                      | x 187, 5 in from the scroll area's left; the first 4 below its heading's bottom, or 10 below a listening mode row | 32 | `AXCheckBox` with identifier `sound-device-<name>`; a hovered row keeps the same frame; two rows in every capture carry no identifier |
| Listening mode row                                                                      | 298 × 26                                      | x 187; the first 3 below its heading's bottom                                                         | 24         | Rows overlap by 2; the group follows the row of the AirPods in use, and the other device rows follow the group |
| Settings text ("<AirPods name> Settings…", "Sound Settings…")                           | text width × 16; 121 wide for "Sound Settings…" | x 187; the first 9 below the scroll area's bottom                                                   | 22         | The AirPods row sits above the Sound row, only while AirPods are connected                                   |

## Rows and heights by output in use

| Output in use                                     | Device rows | Listening mode groups                                                                                                               | Scroll area height | Body height |
| ------------------------------------------------- | ----------- | ----------------------------------------------------------------------------------------------------------------------------------- | ------------------ | ----------- |
| Mac speakers, external headphones, aggregate      | 8           | none                                                                                                                                | 283                | 422         |
| Studio Display, both AirPods disconnected         | 6           | none                                                                                                                                | 219                | 358         |
| AirPods Max                                       | 8           | "Listening Mode": Off, Transparency, Noise Cancellation; "Spatial Audio": Not Available                                             | 461                | 622         |
| AirPods Pro                                       | 8           | "Listening Mode": Off, Transparency, Adaptive, Noise Cancellation; "Spatial Audio": Not Available; "Conversation Awareness": Off, On | 566                | 727         |

The body height is 72 + the scroll area height + 45 + 22 per settings row.

## Looks

| Element, Light Mode at 2x       | Sound menu      | io when measured | Source                                         |
| ------------------------------- | --------------- | ---------------- | ---------------------------------------------- |
| Device name text                | (36, 37, 37)    | (39, 39, 39)     | comment on #6, against the PR #16 render       |
| Icon circle                     | grey about 228  | about 233        | comment on #6                                  |
| Icon glyph                      | (125, 125, 127) | (36, 36, 36)     | comment on #6                                  |
| In-use circle, accent blue      | (59, 134, 247)  | (52, 120, 246)   | #11, measured during #2                        |
| Menu bar icon, headphones       | 29 × 30 px      | 27 × 28 px       | comment on #11                                 |

## Reading a value again

`AXPress` on the Sound item in MenuBarAgent's Accessibility tree opens the menu with any app in front, and a second press closes it; the open menu's elements report their frames in the same tree. A look is one `screencapture -R` crop at the element's frame, read at 2x. A value read on another macOS version gets its own row with that version.
