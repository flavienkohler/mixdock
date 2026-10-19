# AppMixer design

A compact Rainmeter skin that changes the volume of individual apps and switches the default audio output on Windows 11, without opening Windows settings.

## Goals

- Lower one app (for example music) without leaving a game.
- Raise one app (for example a call) above everything else.
- Stay out of the way: open on demand, cost nothing while hidden.

**In scope**

- List of apps currently producing audio, each with a slider, mute button and icon
- Master volume of the active output device
- Output switcher for three user-defined devices
- Open and close on demand (hotkey or small button), plus an optional always-visible mode
- Neutral dark glass look

**Out of scope**

- Equalizer, audio effects, per-app output routing
- Microphone controls

## Layout

A single narrow panel (320 px design width), top to bottom:

1. Header: title, close button
2. Master row: output device name, master slider, mute
3. App rows, one per audio session: icon, name, slider, percent, mute
4. Footer: three output buttons, the active one highlighted

**Behavior**

- Sliders: drag or click to set, mouse wheel over a row changes by 5%. Writes are throttled so dragging stays smooth.
- An app is listed while it plays and for a grace period after it stops (60 s by default), or always while it runs if it is pinned in the config. A pinned app that has no audio session yet (Windows only creates one once the app makes sound) is shown as a dimmed row without a slider. Sessions of every active output device are merged by process name, so an app playing on a non-default device is listed too. An `exclude` list hides apps for good.
- Fixed order: pinned apps first, then alphabetical. Rows do not jump while dragging.
- At most 6 rows are visible, then the list scrolls. Empty state: "No app is playing audio".
- Output buttons switch the Windows default playback device and the list refreshes.
- Toggle with a global hotkey and an optional button. The panel closes on Esc or click outside, with a pinned mode.

**Size.** All sizes derive from one `Scale` variable in `Theme.inc`. Rainmeter already scales skins per monitor DPI; `Scale` only corrects what still looks off.

## Architecture

Rainmeter cannot read or set per-app volume on its own, so the skin only draws the panel and sends commands, while a small helper does the audio work and reports back through a state file.

```text
hotkey ──> Rainmeter skin ──commands──> helper ──> Windows Core Audio
               ^                          │
               └────── state.json ────────┘
```

**Helper.** An original C# program on the Windows Core Audio API, built with the `csc.exe` compiler that ships with Windows (.NET Framework 4.8, present on every Windows 11), so no SDK or runtime install is needed. Default-device switching uses the undocumented `IPolicyConfig` interface, declared in our own code and isolated in one file because a Windows update could change it.

**Helper commands**

```text
helper dump                       write the state file once
helper watch                      rewrite the state file about once per second until stopped
helper stop                       ask a running watcher to exit
helper set-volume <app> <0-100>   one app, matched by process name
helper mute <app> toggle
helper set-master <0-100>
helper set-output <alias>         switch the default playback device
```

Apps are matched by process name, not process id, because one app such as a browser can own several audio sessions. A change applies to all of them.

**Config.** A user config file maps aliases to devices by a name substring, and lists the pinned and excluded apps and the grace period, so each user defines their own setup. An example config is committed; the personal one is not. The grace period needs the watcher: a one-shot `dump` has no memory and lists only apps playing at that moment, plus pinned ones.

**State file (JSON, one writer, UTF-8)**

```json
{
  "output": { "alias": "headset", "name": "Headset", "volume": 62, "muted": false },
  "devices": [ { "alias": "headset", "name": "Headset", "available": true, "active": true } ],
  "apps": [ { "process": "Spotify", "name": "Spotify", "volume": 40, "muted": false, "icon": "Icons/spotify.png" } ]
}
```

`apps[].process` is the key used by commands, `name` is the display name, and `icon` is a path relative to the skin's `@Resources` folder (null when none could be extracted). `devices` lists the configured aliases, `available` means a matching active device exists. The helper writes a temporary file and renames it, so the skin never reads a half-written file, and it rewrites the file only when the content changed. Icons are extracted from each executable once and cached as 64 px PNGs.

**Watch mode.** The skin starts `helper watch` when it loads and runs `helper stop` when it closes, so nothing runs while the panel is hidden. One watcher runs at a time, and it also exits when Rainmeter ends. A one-shot `helper dump` costs about 130 ms, mostly .NET startup, which is why the skin does not spawn it every second.

**Skin internals**

- One Lua script parses the state file and updates a fixed pool of row slots, hiding unused ones (Rainmeter meters cannot be created at runtime).
- Sliders send throttled commands during a drag, not one per pixel.
- Rainmeter has no global hotkey: PowerToys Keyboard Manager or AutoHotkey runs `Rainmeter.exe !ToggleConfig "AppMixer" "AppMixer.ini"`.
- The state refreshes only while the panel is visible.

## Styling and performance

- Dark semi-transparent rounded rectangle with a 1 px light border. Rainmeter's `Blur` option has no visible effect on Windows 11 (tested), so the panel uses an opaque tint. Real acrylic would need the helper to apply it to the window through an undocumented Windows call, which is a later option.
- Text in Segoe UI Variable, icons in Segoe Fluent Icons, one accent color for slider fill and the active output.
- All colors, radius, fonts and sizes live in `Theme.inc`.
- Hidden: no skin updates, no helper polling. Visible: state refresh about once per second, throttled writes, no animation loops. Rainmeter stays under about 1% CPU with the panel open.

## Build plan

Six milestones, each testable on its own.

1. **Investigate.** Choose the helper. Result: an original helper on Core Audio, with no third-party audio tool or plugin (the NirSoft command line tool and the AppVolume plugin were evaluated and worked, but their licenses do not suit an open repository).
2. **Static panel.** Theme and three fake rows with output buttons. Done.
3. **Read path.** The helper writes the state file; the skin shows real apps, icons, volumes and the active output. Done, including the watch mode (the list shows the first 6 apps, scrolling comes with the polish milestone).
4. **Write path.** Sliders, mute, mouse wheel and master volume change the real volumes.
5. **Output switching.** The three buttons change the default device through the configured aliases.
6. **Polish.** Hotkey toggle, close on Esc or outside click, empty state, pinned apps, performance check, optional watch mode.

**Acceptance tests**

- [ ] Lowering one app does not change another app's volume
- [ ] An app with several audio sessions (a browser with several tabs) changes as one app
- [ ] Each output button switches the default device and highlights correctly
- [ ] An app opened after the panel appears shows up without a restart
- [ ] Dragging a slider is smooth, with no flicker of other rows
- [ ] Sharp and correctly sized on screens with different scaling
- [ ] Panel hidden: no measurable CPU use from the skin or helper
- [ ] Rainmeter stays under about 1% CPU with the panel open during a game
