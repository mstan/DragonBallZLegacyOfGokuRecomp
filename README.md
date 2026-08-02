# DragonBallZLegacyOfGokuRecomp

> This recompilation is a byproduct of developing
> [gbarecomp](https://github.com/mstan/gbarecomp). It is an in-development
> preservation and research project, not an official port.

Static recompilation of **Dragon Ball Z: The Legacy of Goku** for Game Boy
Advance to a native PC executable.

## Status

The USA release boots through its attract sequence and into gameplay using
statically generated native code. The project includes:

- the shared `recomp-ui` pre-boot launcher;
- strict ROM identity checking;
- a game-owned, optional adaptive-widescreen mod;
- authored 60×40-tile overworld continuation rather than repeated hardware
  tilemap rings;
- edge-anchored HUD placement; and
- widened actor/prop clipping with correct left- and right-margin OAM
  coordinates.

The adaptive view has been validated at native 240-pixel width and representative
320-, 390-, and 480-pixel widths. This remains an early bring-up and has not been
exhaustively tested across the entire game.

## ROM

| Target | Region | Game code | SHA-1 | Debug port |
|---|---|---|---|---|
| `DragonBallZLegacyOfGokuRecomp` | USA | `ALGE` | `a3c8c76742f11fc6a3f6e3fcca20992458cac0b5` | 19887 |

The ROM is never distributed. Supply your own legally dumped copy at
`roms/dragon_ball_z_the_legacy_of_goku_usa.gba`. The runtime refuses an
unrecognized image. Full CRC and SHA-256 identities are recorded in
[`baserom.md`](baserom.md).

## Quick start

1. Initialize the `gbarecomp` and `recomp-ui` submodules.
2. Supply the verified ROM above and a real GBA BIOS at
   `gbarecomp/bios/gba_bios.bin`.
3. Regenerate and build:

```powershell
git submodule update --init --recursive
.\tools\regen.ps1
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build --target DragonBallZLegacyOfGokuRecomp
```

Run `build/DragonBallZLegacyOfGokuRecomp.exe`. The launcher remembers selected
ROM and presentation settings locally.

## Controls

| GBA button | Keyboard |
|---|---|
| D-Pad | Arrow keys |
| A | Z |
| B | X |
| Start | Enter |
| Select | Backspace |

Save states use **Shift+F1–F9** to save and **F1–F9** to load.

## Adaptive widescreen

Enable **Legacy of Goku Adaptive Widescreen** in the launcher's Mods catalog.
The mod expands both the HUD and overworld as the normal window is resized, up
to a 480×160 logical view. It does not alter gameplay coordinates or the native
240×160 presentation when disabled.

## Legal

This repository contains no game ROM, GBA BIOS, generated code derived from the
ROM, or third-party decompilation source. You must supply legally obtained
copies. Dragon Ball and Dragon Ball Z are trademarks of their respective
owners. This is an unaffiliated, non-commercial preservation and research
effort.
