Scripts that record io's menu bar icon beside the Sound icon and measure both, frame by frame (issue #86). Compile each with `swiftc -O <file>.swift -o <name>`; run from a scratch folder, because they write PNG frames.

- `recdisplay X Y W H SECONDS OUTDIR`: records a region of one display (points, top-left origin; `DISPLAY_ID=2` picks a display other than the main one) at the display's refresh rate; writes `f<ms>.png` per distinct frame and `frames.txt`. A recording of a display whose content does not change can hang at the end: run it under `perl -e 'alarm 60; exec @ARGV' …`.
- `iconrun <recdisplay path> <outdir> [dry|-] <io.app path>`: opens the Sound menu with an Accessibility press (its open menu shows a menu bar a full-screen app hides), records, changes volume and mute through Core Audio and the output through io's Debug `pickOutput` default (the AirPods by the names in `AIRPODS_PRO` and `AIRPODS_MAX`), closes the menu, and restores volume and mute. `dry` only opens the menu and lists its rows. The region, the display and which Sound item it presses (`.first` is the built-in display's, `.last` the Studio Display's) are constants near the top and the recorder lines.
- `centres <dir> <from ms> <to ms> <x0> <x1>`: per frame, one icon's total ink and ink-weighted centre (brightness above 0.35, so the Sound item's open-menu capsule is left out).
- `glyph <png> <x0> <x1>`: the ink box at half the brightest ink, two rows through it as `#/+/.`, the brightest value and the total ink: compares size, stroke and colour.
- `inkbox <dir> [runs]`: per frame, the ink boxes of both icons at fixed columns; `runs` lists the ink column runs of the first frame, to find where each icon sits.
- `ink <pointSize|default>`: renders each Menu bar icon symbol at 2x off screen and prints its ink box, to pick a symbol configuration.
- `devs`: lists the audio outputs, the one in use marked with `*`.
- `sounditems`: lists the Sound item on each display with its frame.
