#pragma once

#include "settings/objectnode.hpp"
#include "common.hpp"

namespace caelestia::config {

class OverviewConfig : public settings::ObjectNode {
    CONFIG_NODE(OverviewConfig, settings::ObjectNode)

    // Whether the overview can be opened on this screen
    CONFIG_PROPERTY(bool, enabled, true)
    // Whether the shell registers the trackpad swipes with Hyprland itself
    CONFIG_GLOBAL_PROPERTY(bool, gestures, true)
    // Finger count for the swipe: up opens the overview, down closes it
    CONFIG_GLOBAL_PROPERTY(int, gestureFingers, 4)
    // Open the overview by moving the pointer into the top-left screen corner
    CONFIG_PROPERTY(bool, hotCorner, true)
    // Size of the top-left hot corner, in pixels
    CONFIG_GLOBAL_PROPERTY(int, hotCornerSize, 10)
};

} // namespace caelestia::config
