# CLAUDE.md — DragonBallZLegacyOfGokuRecomp

This game repository defers platform behavior and debugging rules to:

- `gbarecomp/CLAUDE.md`
- `gbarecomp/PRINCIPLES.md`
- `gbarecomp/DEBUG.md`
- `gbarecomp/TCP.md` (this game uses port 19887)

## Build target

Initialize both submodules before building. Generated cart code is intentionally
not committed and must be recreated with `tools/regen.ps1` from a verified
user-supplied USA ROM. Build with MSYS2 mingw64, CMake, and Ninja. Keep large
generated translation units at modest parallelism.

## Game-specific rules

1. The supported ROM is USA revision 0 (`ALGE`), SHA-1
   `a3c8c76742f11fc6a3f6e3fcca20992458cac0b5`. Do not weaken the identity gate.
2. ROMs, BIOS images, generated C/C++, saves, screenshots, and runtime caches
   are local artifacts and must never be committed.
3. Generated code is never edited. Fix `game.toml`, the recompiler, or the
   runtime and regenerate.
4. Adaptive widescreen is a game-owned optional mod. Native 240×160 rendering
   must remain unchanged when the feature is disabled.
5. Overworld extensions must use authored field data. Do not repeat the
   hardware tilemap ring into expanded margins.
