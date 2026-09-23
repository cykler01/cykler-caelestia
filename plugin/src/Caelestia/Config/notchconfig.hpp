#pragma once

#include "settings/objectnode.hpp"
#include "common.hpp"

namespace caelestia::config {

class NotchConfig : public settings::ObjectNode {
    CONFIG_NODE(NotchConfig, settings::ObjectNode)

    CONFIG_PROPERTY(bool, enabled, true)
    CONFIG_PROPERTY(int, showDuration, 4000)
    CONFIG_PROPERTY(int, hoverExpandDelay, 200)
    CONFIG_PROPERTY(int, collapseDelay, 400)
    CONFIG_PROPERTY(int, maxTitleWidth, 320)
    CONFIG_PROPERTY(bool, showArtist, true)
};

} // namespace caelestia::config
