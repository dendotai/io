# io

A macOS menu bar app that keeps a priority order of audio devices and switches to the highest connected one.

## Language

**Device**:
An audio output or input that macOS reports, such as AirPods Pro or MacBook Pro Microphone.
_Avoid_: source, endpoint

**Remembered device**:
A device the app has seen at least once. It stays in its list, connected or not, until it is hidden.
_Avoid_: known device, stored device

**Built-in device**:
A device that is part of the Mac, such as MacBook Pro Speakers or MacBook Pro Microphone. It can never be hidden.

**Output list**:
The ordered list of remembered output devices. Its order is the priority.
_Avoid_: speaker list, priority list

**Input list**:
The ordered list of remembered input devices. Its order is the priority.
_Avoid_: microphone list, priority list

**Device list**:
The Output list or the Input list.
_Avoid_: priority list

**Priority**:
A device's place in its list. The app uses the highest connected device.
_Avoid_: rank, number

**Reorder**:
Dragging a row in the panel to change its priority. It never switches the device in use.
_Avoid_: sort, rearrange

**Hand pick**:
A click on a device in the panel or in the system Sound menu. The device stays in use until it disconnects, a device above it connects, or Back to Auto is clicked.
_Avoid_: override, manual mode

**Back to Auto**:
The clickable text in the header of a device list's section, shown while the device in use is not the highest connected device there. A click ends the hand pick, so the highest connected device is in use again.

**Hide**:
Removing a disconnected remembered device from its list.
_Avoid_: delete, forget

**Listening mode**:
The AirPods setting with the values Off, Transparency, Adaptive, and Noise Cancellation.
_Avoid_: noise control, ANC mode

**Fold open**:
A click on the ⌄ of a connected AirPods row, which shows its listening mode inside the panel.
_Avoid_: unfold, expand

**Battery levels**:
The charge of a connected pair's buds and of its case, in percent, shown under the pair's name as in the Sound menu.
_Avoid_: battery status, charge

**Update**:
A newer released version of the app, which the app installs in one click.
_Avoid_: upgrade

**Panel**:
What opens when you left-click the app's menu bar icon.
_Avoid_: popup, popover, menu

**Right-click menu**:
What opens when you right-click the app's menu bar icon. It holds the app's own items, "Open at Login" and "Quit io".
