#pragma once

#include "settings/objectnode.hpp"
#include "common.hpp"
#include "enums.hpp"

namespace caelestia::shell::config {

class HotCornersConfig : public settings::ObjectNode {
    CONFIG_NODE(HotCornersConfig, settings::ObjectNode)

    // Size of a hot corner, in pixels
    CONFIG_GLOBAL_PROPERTY(int, size, 10)
    // What resting the pointer in each corner of the screen opens. The overview used to live in the
    // top left corner on its own, so that is where it starts, with the sidebar in the top right
    CONFIG_ENUM_PROPERTY(HotCornerAction, topLeft, HotCornerAction::Overview)
    CONFIG_ENUM_PROPERTY(HotCornerAction, topRight, HotCornerAction::Sidebar)
    CONFIG_ENUM_PROPERTY(HotCornerAction, bottomLeft, HotCornerAction::None)
    CONFIG_ENUM_PROPERTY(HotCornerAction, bottomRight, HotCornerAction::None)
};

} // namespace caelestia::shell::config
