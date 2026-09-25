#pragma once

#include "settings/objectnode.hpp"
#include "common.hpp"
#include "enums.hpp"

namespace caelestia::config {

class NotifPopoutConfig : public settings::ObjectNode {
    CONFIG_NODE(NotifPopoutConfig, settings::ObjectNode)

    // Which side edge the popout window opens from
    CONFIG_GLOBAL_ENUM_PROPERTY(PanelSide, side, PanelSide::Right)
    // Whether the shell registers the trackpad gestures with Hyprland itself
    CONFIG_GLOBAL_PROPERTY(bool, gestures, true)
    // Finger count for the swipe: left opens the popout, right closes it
    CONFIG_GLOBAL_PROPERTY(int, gestureFingers, 4)
};

} // namespace caelestia::config
