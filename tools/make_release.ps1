<#
Build the DragonBallZLegacyOfGokuRecomp Windows x64 release archive.

The archive contains the stripped executable, launcher box art and shared UI
assets, the built-in mod catalog, MinGW/SDL runtime DLLs, the toolchain-less
overlay compiler, and a short player README. It never contains a ROM, retail
GBA BIOS, save data, generated source, or developer configuration.

Usage:
  pwsh tools\make_release.ps1 -Version 0.0.2
#>
param(
    [Parameter(Mandatory = $true)][string]$Version,
    [string]$BuildDir = 'build-release',
    [string]$GbarecompRoot = '',
    [string]$RecompUiRoot = '',
    [ValidateRange(1, 32)][int]$Jobs = 4
)

$ErrorActionPreference = 'Stop'

if ($Version -notmatch '^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$') {
    throw "Version must look like 0.0.1 (received '$Version')."
}

$mingwBin = 'C:\msys64\mingw64\bin'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = (Resolve-Path (Join-Path $scriptDir '..')).Path
if (-not $GbarecompRoot) { $GbarecompRoot = Join-Path $root 'gbarecomp' }
$engine = (Resolve-Path $GbarecompRoot).Path
if (-not $RecompUiRoot) { $RecompUiRoot = Join-Path $root 'recomp-ui' }
$ui = (Resolve-Path $RecompUiRoot).Path
$build = Join-Path $root $BuildDir
$out = Join-Path $root 'release-stage'
$target = 'DragonBallZLegacyOfGokuRecomp'
$gameTitle = 'Dragon Ball Z: The Legacy of Goku'
$expectedSha1 = 'a3c8c76742f11fc6a3f6e3fcca20992458cac0b5'
$stageName = "$target-windows-x64-v$Version"
$stage = Join-Path $out $stageName
$zip = Join-Path $out "$stageName.zip"
$dlls = @('SDL2.dll', 'libgcc_s_seh-1.dll', 'libstdc++-6.dll', 'libwinpthread-1.dll')

foreach ($required in @(
    (Join-Path $mingwBin 'cc.exe'),
    (Join-Path $mingwBin 'c++.exe'),
    (Join-Path $mingwBin 'ninja.exe'),
    (Join-Path $mingwBin 'strip.exe'),
    (Join-Path $engine 'CMakeLists.txt'),
    (Join-Path $engine 'tools\fetch_tcc.ps1'),
    (Join-Path $engine 'src\runtime\generated_bios\bios_recompiled.cpp'),
    (Join-Path $engine 'src\runtime\generated_bios\bios_recompiled.h'),
    (Join-Path $root 'recomp\launcher\boxart.tga')
)) {
    if (-not (Test-Path -LiteralPath $required)) {
        throw "Required release dependency is missing: $required"
    }
}

$generated = @(Get-ChildItem -LiteralPath (Join-Path $root 'generated') `
    -Filter 'recompiled_*.cpp' -File -ErrorAction SilentlyContinue)
if ($generated.Count -eq 0) {
    throw 'Generated guest shards are missing. Supply the verified ROM and run tools\regen.ps1 first.'
}

$env:PATH = "$mingwBin;$env:PATH"
New-Item -ItemType Directory -Force -Path $out | Out-Null

& cmake -S $root -B $build -G Ninja `
    -DCMAKE_C_COMPILER="$mingwBin/cc.exe" `
    -DCMAKE_CXX_COMPILER="$mingwBin/c++.exe" `
    -DCMAKE_MAKE_PROGRAM="$mingwBin/ninja.exe" `
    -DCMAKE_BUILD_TYPE=Release `
    "-DCMAKE_CXX_FLAGS_RELEASE=-O1 -DNDEBUG" `
    -DGBARECOMP_ROOT="$engine" `
    -DRECOMP_UI_ROOT="$ui" `
    -DGBARECOMP_RUNTIME_UI_ROOT="$ui" `
    -DGBARECOMP_BUILD_ORACLE=OFF `
    -DGBARECOMP_MINGW_PREFIX_UNIX='/c/msys64/mingw64' `
    -DSDL2_INCLUDE_DIR='C:/msys64/mingw64/include/SDL2' `
    -DSDL2_LIBRARY='C:/msys64/mingw64/lib/libSDL2.dll.a'
if ($LASTEXITCODE -ne 0) { throw "Release configure failed ($LASTEXITCODE)." }

& cmake --build $build --target $target --parallel $Jobs
if ($LASTEXITCODE -ne 0) { throw "Release build failed ($LASTEXITCODE)." }

$exe = Join-Path $build "$target.exe"
if (-not (Test-Path -LiteralPath $exe)) { throw "Expected executable is missing: $exe" }
& (Join-Path $mingwBin 'strip.exe') $exe
if ($LASTEXITCODE -ne 0) { throw "strip failed ($LASTEXITCODE)." }

if (Test-Path -LiteralPath $stage) {
    $resolvedStage = (Resolve-Path -LiteralPath $stage).Path
    $resolvedOut = (Resolve-Path -LiteralPath $out).Path
    if (-not $resolvedStage.StartsWith("$resolvedOut\", [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove stage outside release output: $resolvedStage"
    }
    Remove-Item -LiteralPath $resolvedStage -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $stage | Out-Null
Copy-Item -LiteralPath $exe -Destination $stage
foreach ($dll in $dlls) {
    $source = Join-Path $mingwBin $dll
    if (-not (Test-Path -LiteralPath $source)) { throw "Runtime DLL is missing: $source" }
    Copy-Item -LiteralPath $source -Destination $stage
}

$assets = Join-Path $build 'assets'
if (-not (Test-Path -LiteralPath (Join-Path $assets 'img\boxart.tga'))) {
    throw "Launcher box art was not staged by the build: $assets"
}
Copy-Item -LiteralPath $assets -Destination $stage -Recurse

$mods = Join-Path $build 'mods'
if (-not (Test-Path -LiteralPath (Join-Path $mods 'packages'))) {
    throw "Preloaded mod catalog is missing: $mods"
}
# Package the immutable shipped catalog. A developer/QA run can create a
# state.toml beside the build's packages; player selections never ship.
Copy-Item -LiteralPath (Join-Path $root 'mods/preloaded') `
    -Destination (Join-Path $stage 'mods') -Recurse

Copy-Item -LiteralPath (Join-Path $root 'LICENSE') -Destination $stage
$notices = Join-Path $stage 'licenses'
New-Item -ItemType Directory -Path $notices | Out-Null
foreach ($notice in @(
    @((Join-Path $engine 'LICENSE'), 'gbarecomp-LICENSE.txt'),
    @((Join-Path $engine 'external/arm-recomp-core/LICENSE'), 'arm-recomp-core-LICENSE.txt'),
    @((Join-Path $ui 'LICENSE'), 'recomp-ui-LICENSE.txt'),
    @((Join-Path $ui 'src/third_party/imgui/LICENSE.txt'), 'imgui-LICENSE.txt'),
    @((Join-Path $mingwBin '../share/licenses/SDL2/LICENSE.txt'), 'SDL2-LICENSE.txt'),
    @((Join-Path $mingwBin '../share/licenses/gcc-libs/COPYING.RUNTIME'), 'GCC-COPYING.RUNTIME.txt'),
    @((Join-Path $mingwBin '../share/licenses/gcc-libs/COPYING3'), 'GCC-COPYING3.txt'),
    @((Join-Path $mingwBin '../share/licenses/gcc-libs/COPYING.LIB'), 'GCC-COPYING.LIB.txt')
)) {
    Copy-Item -LiteralPath $notice[0] -Destination (Join-Path $notices $notice[1])
}
$titleRevision = (& git -C $root rev-parse HEAD).Trim()
$engineRevision = (& git -C $engine rev-parse HEAD).Trim()
$uiRevision = (& git -C $ui rev-parse HEAD).Trim()
@"
Dragon Ball Z: The Legacy of Goku Recomp v$Version
Title: https://github.com/mstan/DragonBallZLegacyOfGokuRecomp at $titleRevision
Engine: https://github.com/mstan/gbarecomp at $engineRevision
Shared UI: https://github.com/RetroPortingToolKit/recomp-ui at $uiRevision
Windows x64 Release, MinGW-w64, SDL2; generated game sources use -O1 -g0.
Use the pinned submodules, tools/regen.ps1 and tools/make_release.ps1.
The retail BIOS must be generated with the engine's bios/gba_bios.toml config.
ROMs, BIOS dumps, generated guest source and saves are not distributed.
Native game saves and explicit player settings are preserved when updating.
Execution save states are build-specific.
"@ | Out-File -LiteralPath (Join-Path $stage 'SOURCE.txt') -Encoding utf8

& (Join-Path $engine 'tools\fetch_tcc.ps1') `
    -Toolchain (Join-Path $stage 'overlay_toolchain') -EngineRoot $engine
if ($LASTEXITCODE -ne 0) { throw "Overlay toolchain staging failed ($LASTEXITCODE)." }

@"
# $gameTitle - GBA static recompilation (Windows x64)

This v$Version preview runs the USA retail game through gbarecomp with a
recomp-ui launcher and an Adaptive Widescreen mod enabled for fresh setups.

This experimental build is a byproduct of developing and testing gbarecomp.
It has no affiliation with or endorsement from the game publisher.

## How to run

1. Extract this entire folder and keep its DLLs, assets, mods, and
   overlay_toolchain beside $target.exe.
2. Run $target.exe.
3. Select your legally obtained $gameTitle (USA) ROM.
   Expected SHA-1: $expectedSha1
4. Select your legally obtained retail gba_bios.bin under Settings > System.
5. Select PLAY. Adaptive Widescreen follows the window; use Mods to disable it.

The in-game settings menu scales its panel, text and controls with larger
windows. Existing explicit aspect/mod choices are preserved when updating.

Display, audio, input, and enhancement settings persist locally. Keyboard
defaults: arrows = D-pad, Z = A, X = B, Enter = Start, Backspace = Select,
and Tab = fast-forward. Shift+F1-F9 saves a state; F1-F9 loads one.

To report a gameplay bug, reproduce it in a short session and quit normally.
The game records diagnostic replays in ``diagnostics/replays`` beside the
executable. Keep the files with that session's prefix together, including
the save and settings sidecars. For display bugs, also record the starting
window size and the resize or fullscreen steps.

The ROM and retail GBA BIOS are not included. Supply your own dumps.
Interactive play has no implicit runtime step limit; only an explicit
``--steps`` option applies a deterministic upper bound.

Project: https://github.com/mstan/$target
Engine: https://github.com/mstan/gbarecomp
"@ | Out-File -LiteralPath (Join-Path $stage 'README.md') -Encoding utf8

$forbidden = Get-ChildItem -LiteralPath $stage -Recurse -File | Where-Object {
    $relative = $_.FullName.Substring($stage.Length + 1)
    $_.Extension -in @('.gba', '.bin', '.bios', '.sav', '.srm', '.fla',
        '.flash', '.state', '.json', '.log', '.apk') -or
    $relative -match '(^|\\)(generated|recomp_cache)(\\|$)' -or
    ($_.Extension -in @('.cpp', '.c', '.h') -and
        $relative -notmatch '^overlay_toolchain\\' -and
        $relative -ne 'external\arm-recomp-core\profiles\armv4t_gba\runtime_arm_types.h') -or
    $_.Name -ieq 'gba_bios.bin' -or
    $_.Name -in @('game.toml', 'rom.cfg', 'bios.cfg', 'config.ini',
        'keybinds.ini', 'mods.ini', 'state.toml')
}
if ($forbidden) {
    throw "Forbidden release content detected: $($forbidden.FullName -join ', ')"
}

if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force }
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

# ZIP entry names must always use '/', regardless of the host OS.
# Compress-Archive preserves Windows backslashes, which POSIX extractors
# treat as literal filename characters rather than directory separators -- so
# a Linux / Steam Deck / Proton user gets files literally named
# "assets\fonts\LatoLatin-Regular.ttf" (and "mods\packages\..." where the
# game ships a mod catalog), the nested trees are never created, and the
# ImGui launcher finds neither its fonts nor its mods. Write portably here,
# then verify before anyone can publish it.
# (Convention ported from snesrecomp/SuperMarioWorldRecomp.)
$rzStageFull = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $stage).Path)
$rzZipFull = [IO.Path]::GetFullPath($zip)
$rzPrefix = $rzStageFull.TrimEnd('\') + '\'
$rzFiles = @(Get-ChildItem -LiteralPath $stage -File -Recurse |
    Sort-Object FullName)
$rzArchive = [IO.Compression.ZipFile]::Open(
    $rzZipFull, [IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($rzFile in $rzFiles) {
        $rzFull = [IO.Path]::GetFullPath($rzFile.FullName)
        if (-not $rzFull.StartsWith(
                $rzPrefix, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Refusing to archive a file outside the release stage: $rzFull"
        }
        $rzName = $rzFull.Substring($rzPrefix.Length).Replace('\', '/')
        if ($rzName.StartsWith('/') -or $rzName -match '(^|/)..(/|$)') {
            throw "Unsafe ZIP entry name: $rzName"
        }
        [IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
            $rzArchive, $rzFull, $rzName,
            [IO.Compression.CompressionLevel]::Optimal) | Out-Null
    }
} finally {
    $rzArchive.Dispose()
}

# Read the archive back and reject non-portable entry names outright, so a
# regression in the writer cannot ship a Windows-only zip again.
$rzArchive = [IO.Compression.ZipFile]::OpenRead($rzZipFull)
try {
    $rzBad = @($rzArchive.Entries | Where-Object {
        $_.FullName.Contains('\') -or
        $_.FullName.StartsWith('/') -or
        $_.FullName -match '(^|/)..(/|$)'
    })
    if ($rzBad.Count -ne 0) {
        throw "ZIP contains non-portable entry names: $(
            ($rzBad | ForEach-Object FullName) -join ', ')"
    }
    if ($rzArchive.Entries.Count -ne $rzFiles.Count) {
        throw "ZIP entry count mismatch: expected $($rzFiles.Count), got $(
            $rzArchive.Entries.Count)"
    }
} finally {
    $rzArchive.Dispose()
}
Write-Host "--- $stageName ---"
Get-ChildItem -LiteralPath $stage | Select-Object Name, Length | Out-Host
Get-Item -LiteralPath $zip | Select-Object Name, Length | Out-Host
Get-FileHash -LiteralPath $zip -Algorithm SHA256 |
    Select-Object Algorithm, Hash, Path | Out-Host
