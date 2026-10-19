# Builds the helper and packages the skin for distribution.
#
# Output (in dist\, which git ignores):
#   Mixdock\              the clean skin folder: tracked files only plus the compiled helper. Nothing personal
#                          (settings, config, icons, state) is ever included. Use it as the root config folder of
#                          Rainmeter's "Create .rmskin package..." (see the README).
#   Mixdock-<version>.zip the same folder zipped, to extract into Rainmeter's Skins folder.
#
# Usage: tools\package.ps1 [-Version 0.1.0]

param([string]$Version = '0.1.0')

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$dist = Join-Path $root 'dist'
$stage = Join-Path $dist 'Mixdock'

& (Join-Path $root 'helper\build.ps1')

if (Test-Path $dist) { Remove-Item $dist -Recurse -Force }
New-Item -ItemType Directory -Force $stage | Out-Null

# Only files that are tracked by git, so local files can never leak into a release.
Push-Location $root
try {
    $tracked = git ls-files -- 'Skins/Mixdock'
    if ($LASTEXITCODE -ne 0) { throw 'git ls-files failed' }
    foreach ($file in $tracked) {
        $relative = $file.Substring('Skins/Mixdock/'.Length)
        $target = Join-Path $stage $relative
        New-Item -ItemType Directory -Force (Split-Path $target) | Out-Null
        Copy-Item (Join-Path $root $file) $target
    }
} finally { Pop-Location }

# The compiled helper and the example config it copies on first run.
$helper = Join-Path $root 'Skins\Mixdock\Helper'
New-Item -ItemType Directory -Force (Join-Path $stage 'Helper') | Out-Null
Copy-Item (Join-Path $helper 'MixdockHelper.exe') (Join-Path $stage 'Helper')
Copy-Item (Join-Path $helper 'config.example.json') (Join-Path $stage 'Helper')
Copy-Item (Join-Path $root 'LICENSE') (Join-Path $stage 'LICENSE.txt')

$zip = Join-Path $dist "Mixdock-$Version.zip"
Compress-Archive -Path $stage -DestinationPath $zip -CompressionLevel Optimal

Write-Host "Skin folder: $stage"
Write-Host "Zip:         $zip"
