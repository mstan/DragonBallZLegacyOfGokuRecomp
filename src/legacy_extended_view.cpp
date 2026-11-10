#include "legacy_extended_view.h"

#include <cstdint>
#include <cstdio>

#include "gba_bus.h"
#include "gba_ppu.h"
#include "runtime_bus_bridge.h"

extern "C" unsigned g_ws_active;
extern "C" unsigned g_ws_extra_left;
extern "C" unsigned g_ws_extra_right;

namespace legacy {
namespace {

// Each overworld plane retains four authored 30x20 screens in EWRAM. The
// game's renderer stitches a camera-sized window from these 2x2 sources into
// the 32x32 hardware rings at 0x0202A5DC/AE00/B624. Sampling these sources
// avoids the 256px alias seam that merely accepting the wrapped ring creates.
constexpr std::uint32_t kFieldSources[4] = {
    0u, 0x02000000u, 0x020012C0u, 0x02002580u,
};
constexpr int kScreenTilesWide = 30;
constexpr int kScreenTilesHigh = 20;
constexpr int kFieldTilesWide = 60;
constexpr int kFieldTilesHigh = 40;
constexpr std::uint32_t kScreenBytes = 0x4B0u;

struct FieldFrame {
    gba::GbaBus* bus = nullptr;
    int last_y = -1;
    int camera_x = 0;
    int camera_y = 0;
    bool valid = false;
};

FieldFrame g_field;

gba::GbaBus* active_bus() {
    return gbarecomp::active_bus();
}

std::uint16_t ewram16(gba::GbaBus* bus, std::uint32_t address) {
    if (!bus || address < 0x02000000u || address + 1u >= 0x02040000u)
        return 0;
    const std::uint8_t* p = bus->ewram_ptr() + address - 0x02000000u;
    return static_cast<std::uint16_t>(p[0]) |
        static_cast<std::uint16_t>(p[1] << 8);
}

bool is_overworld(gba::GbaBus* bus) {
    if (!bus) return false;
    const std::uint16_t dispcnt = bus->io().read16(0x000u);
    if ((dispcnt & 0x1FC7u) != 0x1F40u)
        return false;

    // The standalone game assigns the HUD to BG0/screen block 28 and the
    // three scrolling world planes to consecutive blocks 29..31.
    for (int bg = 0; bg < 4; ++bg) {
        const std::uint16_t cnt =
            bus->io().read16(0x008u + static_cast<std::uint32_t>(bg * 2));
        if (((cnt >> 8) & 0x1Fu) != static_cast<unsigned>(28 + bg) ||
            ((cnt >> 14) & 3u) != 0u) {
            return false;
        }
    }
    return true;
}

std::uint16_t field_entry(gba::GbaBus* bus, int bg, int tile_x, int tile_y) {
    if (!bus || bg < 1 || bg > 3 || tile_x < 0 ||
        tile_x >= kFieldTilesWide || tile_y < 0 ||
        tile_y >= kFieldTilesHigh) {
        return 0;
    }
    const int screen_x = tile_x / kScreenTilesWide;
    const int screen_y = tile_y / kScreenTilesHigh;
    const int screen = screen_y * 2 + screen_x;
    const int local_x = tile_x % kScreenTilesWide;
    const int local_y = tile_y % kScreenTilesHigh;
    return ewram16(
        bus, kFieldSources[bg] + static_cast<std::uint32_t>(screen) *
            kScreenBytes +
            static_cast<std::uint32_t>(
                (local_y * kScreenTilesWide + local_x) * 2));
}

std::uint16_t hardware_entry(
    gba::GbaBus* bus, int bg, int hardware_x, int screen_y) {
    const std::uint16_t cnt =
        bus->io().read16(0x008u + static_cast<std::uint32_t>(bg * 2));
    const std::uint32_t vram_base =
        static_cast<std::uint32_t>((cnt >> 8) & 0x1Fu) * 0x800u;
    const int hofs = bus->io().read16(
        0x010u + static_cast<std::uint32_t>(bg * 4)) & 0xFF;
    const int vofs = bus->io().read16(
        0x012u + static_cast<std::uint32_t>(bg * 4)) & 0xFF;
    const int tile_x = ((hardware_x + hofs) & 0xFF) >> 3;
    const int tile_y = ((screen_y + vofs) & 0xFF) >> 3;
    const std::uint32_t offset =
        static_cast<std::uint32_t>((tile_y * 32 + tile_x) * 2);
    const std::uint8_t* vram = bus->vram_ptr();
    return static_cast<std::uint16_t>(vram[vram_base + offset]) |
        static_cast<std::uint16_t>(vram[vram_base + offset + 1u] << 8);
}

void resolve_field_camera(gba::GbaBus* bus, int screen_y) {
    const bool new_frame =
        g_field.bus != bus || screen_y < g_field.last_y;
    g_field.bus = bus;
    g_field.last_y = screen_y;
    if (!new_frame) return;

    g_field.valid = false;
    if (!g_ws_active || !is_overworld(bus)) return;

    const int phase_x = bus->io().read16(0x014u) & 7;
    const int phase_y = bus->io().read16(0x016u) & 7;
    constexpr int probes_x[] = {4, 44, 84, 124, 164, 204, 236};
    constexpr int probes_y[] = {4, 36, 68, 100, 132, 156};
    int best_score = -1;
    int best_x = 0;
    int best_y = 0;

    // Resolve the absolute 2x2-map window from the live center. Repeated blank
    // tiles are made harmless by scoring all three planes at distributed
    // points and requiring a substantial multi-layer match.
    for (int tile_origin_y = 0;
         tile_origin_y <= kFieldTilesHigh - kScreenTilesHigh;
         ++tile_origin_y) {
        for (int tile_origin_x = 0;
             tile_origin_x <= kFieldTilesWide - kScreenTilesWide;
             ++tile_origin_x) {
            const int camera_x = tile_origin_x * 8 + phase_x;
            const int camera_y = tile_origin_y * 8 + phase_y;
            int score = 0;
            for (int y : probes_y) {
                for (int x : probes_x) {
                    const int tx = (camera_x + x) >> 3;
                    const int ty = (camera_y + y) >> 3;
                    for (int bg = 1; bg <= 3; ++bg) {
                        if (field_entry(bus, bg, tx, ty) ==
                            hardware_entry(bus, bg, x, y)) {
                            ++score;
                        }
                    }
                }
            }
            if (score > best_score) {
                best_score = score;
                best_x = camera_x;
                best_y = camera_y;
            }
        }
    }
    constexpr int kProbeCount =
        static_cast<int>(sizeof(probes_x) / sizeof(probes_x[0])) *
        static_cast<int>(sizeof(probes_y) / sizeof(probes_y[0])) * 3;
    if (best_score >= kProbeCount * 3 / 4) {
        g_field.camera_x = best_x;
        g_field.camera_y = best_y;
        g_field.valid = true;
    }
}

extern "C" int legacy_tilemap_provider(
    int bg, int hardware_x, int screen_y, std::uint16_t* out_entry) {
    gba::GbaBus* bus = active_bus();
    if (!out_entry || !g_ws_active || bg < 1 || bg > 3 || !is_overworld(bus)) {
        return gba::kWsTilemapUnavailable;
    }
    resolve_field_camera(bus, screen_y);
    if (!g_field.valid) return gba::kWsTilemapUnavailable;

    const int world_x = g_field.camera_x + hardware_x;
    const int world_y = g_field.camera_y + screen_y;
    if (world_x < 0 || world_y < 0 ||
        world_x >= kFieldTilesWide * 8 ||
        world_y >= kFieldTilesHigh * 8) {
        return gba::kWsTilemapUnavailable;
    }
    *out_entry = field_entry(bus, bg, world_x >> 3, world_y >> 3);
    return gba::kWsTilemapReplace;
}

extern "C" int legacy_hud_obj_x_provider(
    int oam_index, std::uint16_t attr0, std::uint16_t attr1,
    std::uint16_t, int* out_x) {
    gba::GbaBus* bus = active_bus();
    if (!out_x || !g_ws_active || !is_overworld(bus)) return 0;

    const int x = attr1 & 0x1FFu;
    const int y = attr0 & 0xFFu;

    // Gameplay reserves OAM 0..3 for the health/energy group at top-left.
    // Other slots belong to world actors and props; in particular Bulma uses
    // the high-numbered slots near native X=216 and must remain camera-relative.
    // Position guards make the rule fail closed if a cutscene reuses 0..3.
    if (oam_index >= 0 && oam_index <= 3 && x < 96 && y < 32) {
        *out_x = x - static_cast<int>(g_ws_extra_left);
        return 1;
    }

    // The guest emitter preserves all nine OAM X bits, but native hardware
    // interprets 256..511 as a signed off-left coordinate. Widening the
    // clipping rectangle makes 256..(240 + extra_right) valid authored
    // positions in the right margin, so keep those values unsigned. Values
    // above the widened right edge are the ordinary wrapped representation of
    // negative left-margin coordinates and remain signed.
    //
    // The widened clip guarantees that no submitted world OBJ lies in the
    // unused gap between the right and left ranges, making this unambiguous
    // without depending on actor types, OAM slots, or scene-specific tables.
    const int widened_right = 240 + static_cast<int>(g_ws_extra_right);
    *out_x = x <= widened_right ? x : x - 512;
    return 1;
}

// The standalone engine has two immutable clipping rectangles, both encoded
// as signed halfwords (left, top, right, bottom) = (0, 0, 240, 160):
//
//   0x08011E14: single-piece world sprites (tested by 0x0800AEFC)
//   0x08011E1C: animated/multi-piece sprites (tested by 0x0800AF80)
//
// Keep their vertical bounds faithful. In adaptive view, widen the horizontal
// coordinate space symmetrically; the PPU subsequently adds extra_left when it
// places world OBJ pixels in the extended framebuffer.
extern "C" int legacy_view_rom_read16(
    std::uint32_t address, std::uint16_t original,
    std::uint16_t* out_value) {
    if (!out_value || !g_ws_active) return 0;

    switch (address) {
        case 0x08011E14u:
        case 0x08011E1Cu:
            if (original != 0u) return 0;
            *out_value = static_cast<std::uint16_t>(
                -static_cast<std::int32_t>(g_ws_extra_left));
            return 1;
        case 0x08011E18u:
        case 0x08011E20u:
            if (original != 240u) return 0;
            *out_value = static_cast<std::uint16_t>(
                240u + g_ws_extra_right);
            return 1;
        default:
            return 0;
    }
}

}  // namespace

bool has_authored_view() {
    return is_overworld(active_bus());
}

void install_extended_view(std::uint32_t, std::uint32_t) {
    g_field = {};
    gba::g_ws_tilemap_provider = &legacy_tilemap_provider;
    gba::g_ws_authored_margin_layers = 1;
    gba::g_ws_bg_x_provider = nullptr;
    gba::g_ws_bg_x_provider_layers = 0;
    gba::g_ws_obj_attr_x_provider = &legacy_hud_obj_x_provider;
    gba::g_rom_read16_override = &legacy_view_rom_read16;
    std::fprintf(stderr,
        "[legacy:view] authored 60x40-tile field maps + edge HUD + adaptive "
        "world OBJ clipping enabled\n");
}

}  // namespace legacy
