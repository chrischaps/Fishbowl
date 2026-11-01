# Wraps dist/fishbowl.love in a Windows build a stranger can double-click, as
# dist/fishbowl-<version>-windows-x64.zip, for the download on chaps.dev:
#
#   sh scripts/package.sh                               (makes the .love)
#   pwsh scripts/package-windows.ps1                    (fishbowl-dev-...)
#   pwsh scripts/package-windows.ps1 -Version 0.1.0
#
# Nothing here touches the tank: CI hands this the same .love it has already
# checked, so the exe holds exactly what the frame gets. The exe is LÖVE's own
# with the .love appended, which is how LÖVE fuses a game. The icon and name go
# on first, because rcedit rewrites the file and would drop anything appended.
#
# A fused game saves to %APPDATA%\Fishbowl rather than %APPDATA%\LOVE\Fishbowl,
# so the download and a checkout each keep their own tank.

param(
    [string]$Version = "dev",
    [string]$Love = "dist/fishbowl.love"
)

$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

$LoveVersion = "11.5" # keep with t.version in conf.lua
$LoveUrl = "https://github.com/love2d/love/releases/download/$LoveVersion/love-$LoveVersion-win64.zip"
$LoveSha = "ba6e56be2685e53c817749c4a5007f51137136fe5a3ab64920508babc2e74369"
$RceditUrl = "https://github.com/electron/rcedit/releases/download/v2.0.0/rcedit-x64.exe"
$RceditSha = "3e7801db1a5edbec91b49a24a094aad776cb4515488ea5a4ca2289c400eade2a"

# What LÖVE's runtime needs. Left out: love.exe and lovec.exe, its icons, and
# its changelog and readme, which are about LÖVE rather than the tank.
$Runtime = "love.dll", "lua51.dll", "mpg123.dll", "msvcp120.dll", "msvcr120.dll",
           "OpenAL32.dll", "SDL2.dll", "license.txt"

if (-not (Test-Path $Love)) { throw "$Love is missing: run scripts/package.sh first" }

# Fetched once, and refused unless it's the exact file this script was tested with.
function Get-Pinned([string]$Url, [string]$Sha, [string]$Path) {
    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Force (Split-Path $Path) | Out-Null
        Invoke-WebRequest -Uri $Url -OutFile $Path
    }
    $got = (Get-FileHash -Algorithm SHA256 $Path).Hash
    if ($got -ne $Sha) {
        Remove-Item $Path
        throw "$Url has changed: expected $Sha, got $got"
    }
}

$cache = "dist/windows-cache"
$loveZip = "$cache/love-$LoveVersion-win64.zip"
$rcedit = "$cache/rcedit-x64.exe"
Get-Pinned $LoveUrl $LoveSha $loveZip
Get-Pinned $RceditUrl $RceditSha $rcedit

$work = "dist/windows-work"
$stage = "$work/Fishbowl"
if (Test-Path $work) { Remove-Item -Recurse -Force $work }
New-Item -ItemType Directory -Force $stage | Out-Null
Expand-Archive -Path $loveZip -DestinationPath $work
$unpacked = "$work/love-$LoveVersion-win64"

# Windows reads file versions as numbers, so a prerelease or dev build is
# stamped with only the part it can read.
$numeric = if ($Version -match '^\d+\.\d+\.\d+') { $Matches[0] } else { "0.0.0" }
$base = "$work/Fishbowl-base.exe"
Copy-Item "$unpacked/love.exe" $base
& $rcedit $base `
    --set-icon "scripts/windows/fishbowl.ico" `
    --set-file-version $numeric `
    --set-product-version $numeric `
    --set-version-string "ProductVersion" $Version `
    --set-version-string "FileDescription" "Fishbowl" `
    --set-version-string "ProductName" "Fishbowl" `
    --set-version-string "InternalName" "Fishbowl" `
    --set-version-string "OriginalFilename" "Fishbowl.exe" `
    --set-version-string "CompanyName" "chaps.dev"
if ($LASTEXITCODE -ne 0) { throw "rcedit failed with exit $LASTEXITCODE" }

# exe + .love = a fused game
$exe = [IO.File]::Create((Join-Path $PWD "$stage/Fishbowl.exe"))
try {
    foreach ($part in $base, $Love) {
        $in = [IO.File]::OpenRead((Join-Path $PWD $part))
        try { $in.CopyTo($exe) } finally { $in.Dispose() }
    }
} finally { $exe.Dispose() }

foreach ($file in $Runtime) { Copy-Item "$unpacked/$file" "$stage/$file" }

# CRLF whatever the checkout did: a stranger meets this in Notepad
$readme = (Get-Content -Raw "scripts/windows/README.txt") -replace "`r?`n", "`r`n"
[IO.File]::WriteAllText((Join-Path $PWD "$stage/README.txt"), $readme)

$zip = "dist/fishbowl-$Version-windows-x64.zip"
if (Test-Path $zip) { Remove-Item $zip }
Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::CreateFromDirectory(
    (Join-Path $PWD $stage), (Join-Path $PWD $zip),
    [IO.Compression.CompressionLevel]::Optimal, $true)

$size = [math]::Round((Get-Item $zip).Length / 1MB, 1)
Write-Output "packed $zip ($size MB)"
(Get-FileHash -Algorithm SHA256 $zip).Hash.ToLower()
