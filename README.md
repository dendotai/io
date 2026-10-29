# io

A macOS menu bar app that remembers the priority order of your audio devices and switches to the highest one that is connected. Its panel repeats the system Sound menu, so the system Sound icon can be hidden.

## How it works

- Drag a device up or down to set its place. io uses the highest connected device in each list. Dragging never switches the device in use: it stays until it disconnects or a device above it connects.
- A new output goes to the top, so headphones you connect for the first time play at once. A new input goes to the bottom, so a new microphone never takes over.
- Click a device to use it for now. Your choice holds until that device disconnects or a device higher in the list connects. A choice in the system Sound menu works the same way.
- To hide a disconnected device, hover the row with › and choose Hide. If it connects again, it counts as new. Built-in devices, such as MacBook Pro Speakers, stay in the list.

Requires macOS 27 or later.

## License

MIT, see [LICENSE](LICENSE).
