# AirPlay as the system output

A route that makes an AirPlay device the system output, the way a pick in the Sound menu does, is tested here before it is tried again. Every result below comes from macOS 27.2.1 with SIP on, unless a line says otherwise.

## What a pick in the Sound menu does

- ControlCenter sends the pick, and `audiomxd` sets the output: `SetData:kAudioHardwarePropertyDefaultOutputDevice transient to <context UUID>-<n>-Audio`, then `Core audio route changed to [AirPlay, …]`.
- Core Audio lists the AirPlay device only from that moment. Its UID ends in `-Audio`, the number changes on each pick, and the device is gone once the output moves away.
- A pick of several outputs sets an aggregate device, `~:AMS2_StackedOutput:0`, named "Full".
- io moves the output back 2 to 55 ms after each pick, because it leaves out the AirPlay transport type.

## Route that works

- **Accessibility click on the Sound menu.** `AXPress` on the menu bar item with id `com.apple.menuextra.sound`, then `AXPress` on the device's row, an `AXCheckBox` with id `sound-device-<name>`, then `AXPress` on the menu bar item again to close the menu. Two clean runs moved the output to an AirPlay receiver.
  - The app needs the Accessibility permission.
  - The menu must be open on screen for about 1 s: with it closed, Control Center lists no `sound-device` rows.
  - The ids are not documented, so a macOS update can change them.
  - Other projects use the same route, for example `ControlCenterSound.swift` in Robschke/clamshell and `airplay.service.ts` in Avivbens/alfredo.

## Routes that fail

- **Core Audio:** lists no AirPlay device before a pick. switchaudio-osx issue 9, Background Music issues 204 and 370, and Hammerspoon issue 584 report the same.
- **`dns-sd -B _airplay._tcp`:** names only, no way to route to them.
- **`AVRouteDetector`:** reports that devices exist, with no names.
- **`AVRoutePickerView`:** a pick routes only the sound of the app that holds the view; the log shows no system output move.
- **`MPAVRoutingController`:** `availableRoutes` is empty.
- **`AVOutputDeviceDiscoverySession`** (features 1, 2, 4, 8, discovery mode 2): 0 devices. `audiomxd` logs `There are no available routes for clientName=, discovererType=Audio`.
- **`+[AVOutputContext sharedSystemAudioContext]`:** returns nil, err -12029. A hand-built `AVOutputDevice` set on `outputContextForID:` or `defaultSharedOutputContext` ends with status 3 and no route change.
- **MediaRemote:** `MRAVOutputContextGetSharedSystemAudioContext` returns nil; `MRAVRoutingDiscoverySession` lists 0 devices, with `Missing entitlement com.apple.mediaremote.remote-control-discovery`; `MRMediaRemoteFindAndPickRoute` fails with `ClientNotEntitled` (code 130).
- **Control Center's entitlements on an ad hoc signed probe:** `com.apple.avfoundation.allow-system-wide-context`, `com.apple.avfoundation.allows-access-to-device-list`, `com.apple.avfoundation.allows-set-output-device` and `com.apple.mediaremote.send-commands` are each restricted. AMFI kills the probe at launch: `The file is adhoc signed but contains restricted entitlements`. A Developer ID build cannot hold them without a profile from Apple.

## Not tested

- A spoofed entitlement answer through `DYLD_INSERT_LIBRARIES`, as in lingyired/status-trio, which only reads the route. A notarized io with the hardened runtime cannot load such a library.
- SoundSource, eqMac, BetterTouchTool, Raycast extensions, and the Shortcuts "Set Playback Destination" action.
- Apple's documentation and developer forums.
