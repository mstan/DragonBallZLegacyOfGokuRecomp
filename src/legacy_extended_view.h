#pragma once

#include <cstdint>

namespace legacy {

bool has_authored_view();

void install_extended_view(std::uint32_t extra_left,
                           std::uint32_t extra_right);

}  // namespace legacy
