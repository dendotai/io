# io

A macOS menu bar app that remembers the priority order of your audio devices and switches to the highest one that is connected. Its panel repeats the system Sound menu, so the system Sound icon can be hidden.

## How it works

- Drag a device up or down to set its place. io uses the highest connected device in each list. Dragging never switches the device in use: it stays until it disconnects, a device above it connects, or you click "Back to Auto".
- A new output goes to the top, so headphones you connect for the first time play at once. A new input goes to the bottom, so a new microphone never takes over.
- Click a device to use it for now. Your choice holds until that device disconnects, a device higher in the list connects, or you click "Back to Auto".
- While the device in use is not the highest connected one in its list, that section's header shows "Back to Auto". Click it to go back to the order: io uses the highest connected device again.
- To hide a disconnected device, hover the row with › and choose Hide. If it connects again, it counts as new. Built-in devices, such as MacBook Pro Speakers, stay in the list.

Right-click the io icon for "Open at Login" and "Quit io".

When a newer version exists, "Update to <version>" appears at the bottom of the panel and at the top of the right-click menu. One click installs it and relaunches io.

Requires macOS 27 or later.

Out of scope:

- The format label and the playing app's icon from the Sound menu's header, because macOS gives no public or reliable way to read them.
- Changing the device outside io while io runs, such as in the Sound menu or from another app: io moves it back to the device it chose. macOS also moves the output on its own, and it gives no public or reliable way to tell those moves from a click.
- AirPlay speakers, because macOS gives no public or reliable way to list them or send system sound to them.

## Install

```bash
curl -fsSL https://github.com/dendotai/io/releases/latest/download/io.zip -o /tmp/io.zip && ditto -x -k /tmp/io.zip /Applications && open /Applications/io.app
```

## Development

Run `bun install` once after a clone or in a new worktree. It installs commitlint and turns on the commit message check in `.githooks/commit-msg`.

## License

MIT, see [LICENSE](LICENSE).
