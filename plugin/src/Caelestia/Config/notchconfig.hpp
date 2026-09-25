#pragma once

#include "settings/objectnode.hpp"
#include "common.hpp"
#include "enums.hpp"

namespace caelestia::config {

class NotchConfig : public settings::ObjectNode {
    CONFIG_NODE(NotchConfig, settings::ObjectNode)

    CONFIG_PROPERTY(bool, enabled, true)
    CONFIG_ENUM_PROPERTY(PanelAlign, align, PanelAlign::Center)
    CONFIG_PROPERTY(int, showDuration, 4000)
    CONFIG_PROPERTY(int, hoverExpandDelay, 200)
    CONFIG_PROPERTY(int, collapseDelay, 400)
    CONFIG_PROPERTY(int, maxTitleWidth, 320)
    CONFIG_PROPERTY(bool, showArtist, true)
    // Keep the notch up while the workspace has no (tiled) windows, showing the clock and what is playing
    CONFIG_PROPERTY(bool, showOnEmptyWorkspace, true)
    CONFIG_PROPERTY(bool, showClock, true)
};

} // namespace caelestia::config
