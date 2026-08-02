# Dragon Ball Z: The Legacy of Goku Recomp

> **Experimental preview.** This recompilation is a byproduct of developing
> [gbarecomp](https://github.com/mstan/gbarecomp): the games are the proving
> ground, while the reusable framework is the larger goal. This is not a
> finished commercial port, so expect rough edges and please report problems.
> For more context, read
> [Recomp + AI: 5 Months Later »](https://1379.tech/recomp-ai-5-months-later/).

Static recompilation of **Dragon Ball Z: The Legacy of Goku** for Windows,
with an optional Adaptive Widescreen mod.

The game ROM and Nintendo GBA BIOS are **not included**. You must provide your
own legally obtained dumps.

## Status

The USA release boots through its attract sequence and into gameplay. Adaptive
view has been validated at native 240-pixel width and representative 320-,
390-, and 480-pixel widths. The initial `v0.0.1` build is an experimental
preview and has not been exhaustively tested through the entire game, so back
up important saves.

## Quick start

1. Download the Windows zip from [Releases](../../releases) and extract it.
2. Run `DragonBallZLegacyOfGokuRecomp.exe`.
3. In the launcher, select your **Dragon Ball Z: The Legacy of Goku (USA)**
   ROM and retail GBA BIOS.
4. Configure display, audio, controls, and mods, then select **Play**.

The launcher remembers valid files after the first setup. Enable **Skip
launcher on boot** if you want later launches to go directly into the game.

## Included mod

**Legacy of Goku Adaptive Widescreen** is optional and disabled by default. It
expands the HUD and overworld as the window is resized, up to a 480×160 logical
view, using authored overworld continuation and widened actor and prop
clipping. It does not stretch the original image or change gameplay
coordinates.

The faithful 240×160 presentation remains available unchanged. Open the
launcher's **Mods** page to enable the enhancement.

## Features

- Native Windows x64 application
- ROM and BIOS setup through the shared
  [recomp-ui](https://github.com/mstan/recomp-ui) launcher
- Optional Adaptive Widescreen mod with edge-anchored HUD placement
- Keyboard and modern game-controller support
- Windowed and fullscreen play with sharp scaling and optional affine
  filtering
- In-game settings menu
- Cartridge saves and save states

## Controls

| GBA control | Keyboard |
|---|---|
| D-Pad | Arrow keys |
| A / B | Z / X |
| Start | Enter |
| Select | Backspace |

Use **Shift+F1-F9** to save a state and **F1-F9** to load one. Controls can be
changed from the launcher.

## Building from source

Windows development requires CMake, Ninja, MSYS2 MinGW64, and SDL2:

```powershell
git clone --recurse-submodules `
  https://github.com/mstan/DragonBallZLegacyOfGokuRecomp.git
cd DragonBallZLegacyOfGokuRecomp

cmake -S gbarecomp -B gbarecomp/build -G Ninja
cmake --build gbarecomp/build --target gba_recompile
pwsh tools/regen.ps1
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build --target DragonBallZLegacyOfGokuRecomp
```

Generation requires the supported ROM revision and a retail GBA BIOS. Their
identities and local development paths are documented in
[`baserom.md`](baserom.md) and [`game.toml`](game.toml). ROM-derived generated
code, copyrighted inputs, saves, and build output remain local and are never
committed.

Contributors can run the validation scripts under [`tools/`](tools/) and
`pwsh tools/make_release.ps1 -Version 0.0.1` to build a sanitized Windows
package.

## Legal

This is an unofficial, non-commercial preservation and research project. It
is not affiliated with or endorsed by Nintendo, Infogrames, Webfoot
Technologies, Shueisha, Toei Animation, or any Dragon Ball rights holder.
Dragon Ball and related names, characters, artwork, and game data are
trademarks or copyrights of their respective owners.

No game ROM, Nintendo GBA BIOS, save data, or extracted game data is
distributed by this project. Launcher box art is included for identification.

---

Part of the **R.A.I.D. — Retro AI Development** static-recompilation
community.
