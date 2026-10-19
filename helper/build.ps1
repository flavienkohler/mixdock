# Builds the helper with the C# compiler that ships with Windows (no SDK needed).
# Output: Skins\Mixdock\Helper\MixdockHelper.exe, plus config.example.json next to it.

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$outDir = Join-Path $root 'Skins\Mixdock\Helper'
$csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path $csc)) { throw "csc.exe not found at $csc" }

New-Item -ItemType Directory -Force $outDir | Out-Null
$sources = Get-ChildItem (Join-Path $PSScriptRoot 'src') -Filter *.cs | ForEach-Object FullName

& $csc /nologo /optimize+ /target:winexe /platform:anycpu `
    /out:"$outDir\MixdockHelper.exe" `
    /r:System.Web.Extensions.dll /r:System.Drawing.dll `
    $sources
if ($LASTEXITCODE -ne 0) { throw "Build failed" }

# The helper creates config.json from this example the first time it runs.
Copy-Item (Join-Path $PSScriptRoot 'config.example.json') (Join-Path $outDir 'config.example.json') -Force
Write-Host "Built $outDir\MixdockHelper.exe"
Write-Host "On first run it creates $outDir\config.json from config.example.json: edit that file so each alias matches one of your playback devices."
