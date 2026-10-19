# AppMixer

A compact Rainmeter skin to set the volume of individual apps and switch the default audio output on Windows 11, without opening Windows settings.

Status: early development. See [docs/spec.md](docs/spec.md) for the design.

## Structure

- `Skins/AppMixer/`: the Rainmeter skin (point Rainmeter's skin path at `Skins/`, or copy this folder into your skins folder)
- `helper/`: source of the small audio helper (C#, Windows Core Audio, built with the compiler that ships with Windows)
- `tools/`: `generate-rows.ps1` regenerates `Rows.inc`, the pool of identical app row slots (Rainmeter cannot create meters at runtime)
- `docs/`: specification and design notes

## Build

The helper needs no SDK. From a PowerShell prompt in the repository: `helper\build.ps1`. It compiles `Skins\AppMixer\Helper\AppMixerHelper.exe` with the C# compiler that ships with Windows and creates `config.json` from `helper\config.example.json` if missing. Edit that file so each alias matches part of the name of one of your playback devices. The optional "icon" of an output ("headset", "speakers", "monitor", "jack" or "gamepad") is what the compact layout shows on its button; without it the button shows the output's number.

## Settings

Right-click the panel and open **Custom skin actions**:

- **Layout**: *Full* (names, percentages, labelled output buttons) or *Compact* (icons and sliders only, no names; an app's name shows as a tooltip on its icon, the percentage replaces the mute button while you drag a slider, the pin and the grip show only while the cursor is over the panel, and the output buttons are small icons).
- **Accent**: the highlight color. By default it follows the Windows accent color (and changes with it); pick a preset, or choose *Custom* to type any color in the settings file (`RRGGBB`, for example `3B82F6`, or `r,g,b`).
- **Opacity**: from 100% (solid) down to 50%, with a check mark on the current choice.
- **Open settings file**: opens `Skins/AppMixer/Settings.inc`, which the menu writes and you can also edit by hand. It is created on the first change and is not tracked by git. The built-in defaults live in `Theme.inc` (colors, sizes, fonts).

## License

MIT, see [LICENSE](LICENSE).
