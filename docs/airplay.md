# AirPlay as the system output

A route that makes an AirPlay device the system output, the way a pick in the Sound menu does, is tested here before it is tried again. Every result below comes from macOS 27.2.1 with SIP on, unless a line says otherwise.

## What a pick in the Sound menu does

- ControlCenter sends the pick, and `audiomxd` sets the output: `SetData:kAudioHardwarePropertyDefaultOutputDevice transient to <context UUID>-<n>-Audio`, then `Core audio route changed to [AirPlay, …]`.
- Core Audio lists the AirPlay device only from that moment: transport type `airp` (`kAudioDeviceTransportTypeAirPlay`), name "AirPlay", not hidden. Its UID ends in `-Audio`, the number changes on each pick, and the device is gone once the output moves away. Core Audio gives no receiver name.
- A pick of a second AirPlay device replaces the first. Between the two, the output is MacBook Pro Speakers for 0.2 to 0.4 s.
- A pick of several outputs sets an aggregate device, `~:AMS2_StackedOutput:0`, named "Full".
- io leaves an output with the transport type `airp` in use, as an AirPlay pick (`GLOSSARY.md`).

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

## How other apps do it

- **SoundSource 6** (Rogue Amoeba, macOS 15 and later) sends all system sound to an "output group" of AirPlay devices set as its System Output. Rogue Amoeba does not say how; its manual asks for the Accessibility and Local Network permissions.
- **Keyboard Maestro** ("Set Sound Output" macro) and AppleScripts on Stack Overflow click Control Center through Accessibility, as in the route that works above; one such script broke on macOS 26.
- **Raycast** `audio-device` clicked the Sound settings pane through Accessibility; it broke on macOS 13 and the setting was removed in 2025.
- **eqMac** processes sound that already goes to AirPlay; you pick AirPlay in the Sound menu.
- **BetterTouchTool** picks Core Audio devices only, so AirPlay works only after a pick in the Sound menu; its forum scripts reach the Music app's AirPlay devices only.

## Apple's documentation

- No public API, Shortcuts action, or entitlement sets the system output to AirPlay.
- `AVRoutePickerView` and `AVPlayer.audioOutputDeviceUniqueID` route only the app's own player. `AVAudioSession` and `MPVolumeView` do not exist on macOS. `AVRouting`, `AVRouteDetector`, and `MPRemoteCommandCenter` do not choose an output.
- On the developer forums, Apple staff asked a poster to file a feedback request (thread 698988).

## Not tested

- The Shortcuts "Set Playback Destination" action on macOS.
- A spoofed entitlement answer through `DYLD_INSERT_LIBRARIES`, as in lingyired/status-trio, which only reads the route. A notarized io with the hardened runtime cannot load such a library.
