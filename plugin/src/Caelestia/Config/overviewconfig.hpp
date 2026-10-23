#pragma once

#include "settings/objectnode.hpp"
#include "common.hpp"

namespace caelestia::shell::config {

class OverviewConfig : public settings::ObjectNode {
    CONFIG_NODE(OverviewConfig, settings::ObjectNode)

    // Whether the overview can be opened on this screen. A screen corner can be pointed at it as well,
    // which lives in HotCornersConfig with the other corners
    CONFIG_PROPERTY(bool, enabled, true)
    // Whether the shell registers the trackpad swipes with Hyprland itself
    CONFIG_GLOBAL_PROPERTY(bool, gestures, true)
    // Finger count for the swipe: up opens the overview, down closes it
    CONFIG_GLOBAL_PROPERTY(int, gestureFingers, 4)
    // Only list workspaces that have windows (plus the focused one and the next free one)
    // instead of every workspace in groups of ten. Still shown ten to a page
    CONFIG_GLOBAL_PROPERTY(bool, onlyInUse, false)
};

} // namespace caelestia::shell::config
