# io

A macOS menu bar app that keeps a priority order of audio devices and switches to the highest connected one.

## Language

**Device**:
An audio output or input that macOS reports, such as AirPods Pro D1 or MacBook Pro Microphone.
_Avoid_: source, endpoint

**Remembered device**:
A device the app has seen at least once. It stays in its list, connected or not, until it is forgotten.
_Avoid_: known device, stored device

**Output list**:
The ordered list of remembered output devices. Its order is the priority.
_Avoid_: speaker list, priority list

**Input list**:
The ordered list of remembered input devices. Its order is the priority.
_Avoid_: microphone list, priority list

**Priority**:
A device's place in its list. The app uses the highest connected device.
_Avoid_: rank, number

**Hand pick**:
A click on a device in the panel. The device stays in use until the next device connects or disconnects.
_Avoid_: override, manual mode

**Forget**:
Removing a disconnected remembered device from its list.
_Avoid_: delete, hide

**Listening mode**:
The AirPods setting with the values Off, Transparency, Adaptive, and Noise Cancellation.
_Avoid_: noise control, ANC mode

**Panel**:
What opens when you click the app's menu bar icon.
_Avoid_: popup, popover, menu
