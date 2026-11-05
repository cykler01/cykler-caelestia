#pragma once

#include "settings/objectnode.hpp"
#include "common.hpp"
#include "enums.hpp"

namespace caelestia::shell::config {

class SidebarConfig : public settings::ObjectNode {
    CONFIG_NODE(SidebarConfig, settings::ObjectNode)

    CONFIG_PROPERTY(bool, enabled, true)
    // Also the side of the notifications, utilities and toasts that stack with the sidebar
    CONFIG_ENUM_PROPERTY(PanelSide, side, PanelSide::Right)
    // Leaves the utilities panel closed while the sidebar is open, so the sidebar takes the full height
    CONFIG_PROPERTY(bool, fullHeight, false)
    CONFIG_PROPERTY(bool, showOnHover, false)
    CONFIG_PROPERTY(int, minHoverThreshold, 200)
    CONFIG_PROPERTY(int, dragThreshold, 80)
    // The Chrome dino game in the notifications tab, started with space while the tab has nothing
    // to show (modules/notifpopout/Content.qml)
    CONFIG_PROPERTY(bool, dinoGame, false)
    // The AI chat tab, with conversations saved between sessions
    // (modules/aichatpopout/Content.qml)
    CONFIG_PROPERTY(bool, aiChat, false)
};

} // namespace caelestia::shell::config
