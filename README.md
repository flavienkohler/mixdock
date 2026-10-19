# AppMixer

A compact Rainmeter skin to set the volume of individual apps and switch the default audio output on Windows 11, without opening Windows settings.

Status: early development. See [docs/spec.md](docs/spec.md) for the design.

## Structure

- `Skins/AppMixer/`: the Rainmeter skin (point Rainmeter's skin path at `Skins/`, or copy this folder into your skins folder)
- `helper/`: source of the small audio helper (C#, Windows Core Audio, built with the compiler that ships with Windows)
- `docs/`: specification and design notes

## Build

The helper needs no SDK. From a PowerShell prompt in the repository: `helper\build.ps1`. It compiles `Skins\AppMixer\Helper\AppMixerHelper.exe` with the C# compiler that ships with Windows and creates `config.json` from `helper\config.example.json` if missing. Edit that file so each alias matches part of the name of one of your playback devices.

## License

MIT, see [LICENSE](LICENSE).
