# Builds the helper with the C# compiler that ships with Windows (no SDK needed).
# Output: Skins\AppMixer\Helper\AppMixerHelper.exe, plus config.json copied from the example if missing.

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$outDir = Join-Path $root 'Skins\AppMixer\Helper'
$csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path $csc)) { throw "csc.exe not found at $csc" }

New-Item -ItemType Directory -Force $outDir | Out-Null
$sources = Get-ChildItem (Join-Path $PSScriptRoot 'src') -Filter *.cs | ForEach-Object FullName

& $csc /nologo /optimize+ /target:winexe /platform:anycpu `
    /out:"$outDir\AppMixerHelper.exe" `
    /r:System.Web.Extensions.dll /r:System.Drawing.dll `
    $sources
if ($LASTEXITCODE -ne 0) { throw "Build failed" }

$config = Join-Path $outDir 'config.json'
if (-not (Test-Path $config)) {
    Copy-Item (Join-Path $PSScriptRoot 'config.example.json') $config
    Write-Host "Created $config from the example. Edit it to match your output devices."
}
Write-Host "Built $outDir\AppMixerHelper.exe"
