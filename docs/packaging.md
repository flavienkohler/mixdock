# Building and releasing

## Repository layout

- `Skins/Mixdock/`: the Rainmeter skin. `Mixdock.ini` holds the meters, `Theme.inc` the colors, fonts and icons, `Layout-full.inc` and `Layout-compact.inc` every position and size, `Rows.inc` the app row slots, `Scripts/` the Lua.
- `helper/`: the C# helper. `build.ps1` compiles it with the compiler that ships with Windows into `Skins/Mixdock/Helper/`.
- `tools/`: `generate-rows.ps1` regenerates `Rows.inc` (run it after changing the row structure), `package.ps1` builds a release.
- `docs/`: the design (`spec.md`), this guide, and the screenshots used by the README.

Files that are specific to one installation are not tracked: `Helper/config.json`, `Settings.inc`, `@Resources/State`, `@Resources/Icons`, `@Resources/Commands`, and the compiled helper.

## Build and try

1. Point Rainmeter's skin path at the repository's `Skins` folder (`SkinPath` in `%APPDATA%\Rainmeter\Rainmeter.ini`, with Rainmeter closed).
2. Run `helper\build.ps1`. Stop a running helper first (`Skins\Mixdock\Helper\MixdockHelper.exe stop`), or the build cannot replace the exe.
3. Load `Mixdock\Mixdock.ini`. Rainmeter refreshes the skin on its own when its files change; use *Refresh skin* if it does not.

`Theme.inc` is stored as UTF-16 in the working tree because Rainmeter needs that for the icon characters it contains. `.gitattributes` keeps it as readable UTF-8 inside git.

## Making a release

1. Update the version where it is shown and commit.
2. Run `tools\package.ps1 -Version <version>`. It builds the helper and writes, in the ignored `dist\` folder, `Mixdock\` (a clean copy of the skin built only from tracked files plus the compiled helper) and `Mixdock-<version>.zip` (the same folder zipped, to be extracted into Rainmeter's skins folder).
3. Tag the commit (`git tag v<version>`) and attach the zip to a release.

### An installable `.rmskin` (optional)

Rainmeter only installs `.rmskin` files made by its own Skin Packager, which has no command line, and it refuses a plain zip renamed to `.rmskin`. To offer one, copy the `dist\Mixdock` folder into Rainmeter's skins folder and then, in the Rainmeter *Manage* window, choose *Create .rmskin package...*:

1. Name `Mixdock`, your name as author, the version.
2. Add the `Mixdock` skin folder as the root config folder.
3. Load `Mixdock\Mixdock.ini` after install, minimum Rainmeter 4.5.
4. In *Advanced*, consider *Merge skins* so an update does not remove a user's `Settings.inc` and `Helper\config.json`.

Attach the resulting `.rmskin` to the release next to the zip. The packaging steps above were taken from Rainmeter's documentation and have not been run for this project.
