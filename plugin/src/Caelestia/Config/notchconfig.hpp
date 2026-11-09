#pragma once

#include <qstringlist.h>

#include "settings/objectnode.hpp"
#include "common.hpp"
#include "enums.hpp"

namespace caelestia::shell::config {

class NotchConfig : public settings::ObjectNode {
    CONFIG_NODE(NotchConfig, settings::ObjectNode)

    CONFIG_PROPERTY(bool, enabled, true)
    CONFIG_ENUM_PROPERTY(PanelAlign, align, PanelAlign::Center)
    CONFIG_PROPERTY(int, showDuration, 4000)
    CONFIG_PROPERTY(int, hoverExpandDelay, 200)
    CONFIG_PROPERTY(int, collapseDelay, 400)
    CONFIG_PROPERTY(int, maxTitleWidth, 320)
    CONFIG_PROPERTY(bool, showArtist, true)
    // Artist before the title ("Artist - Title") or the other way round
    CONFIG_PROPERTY(bool, artistFirst, true)
    // Keep the notch up while the workspace has no (tiled) windows, showing the clock and what is playing
    CONFIG_PROPERTY(bool, showOnEmptyWorkspace, true)
    CONFIG_PROPERTY(bool, showClock, true)
    // Keep the notch up on workspaces that have windows as well, not just empty ones
    CONFIG_PROPERTY(bool, showWithWindows, true)
    // Show what is playing in the notch alongside the clock (the brief pill on a track change is separate)
    CONFIG_PROPERTY(bool, showMusic, true)
    // NOTE(fork): show a running countdown (the utilities panel's timer) in the notch beside the clock
    CONFIG_PROPERTY(bool, showTimer, true)

    // NOTE(fork): Dynamic Island activities - things that just happened, which the notch stands up
    // to show for a moment wherever it is, in place of the clock and what is playing

    // A lock key (caps lock, num lock) turning on or off
    CONFIG_PROPERTY(bool, showKeyLocks, true)
    CONFIG_PROPERTY(int, keyLockDuration, 1600)
    // Browser and Steam downloads, while any are running (see services/downloads.cpp)
    CONFIG_PROPERTY(bool, showDownloads, true)
    // Notifications as they arrive, for the apps named in notifApps
    CONFIG_PROPERTY(bool, showNotifs, true)
    // Which apps the island is for, matched the way silencedApps is: case-insensitively, against
    // any part of the name a notification carries. Empty - the default - means none: every popup
    // stays in the corner until an app is named here, and then only that app's come to the notch.
    CONFIG_PROPERTY(QStringList, notifApps, DEFAULT_ARG({}))
    CONFIG_PROPERTY(int, notifDuration, 5000)
    // Whether the island stands in for the corner popup rather than doubling it. The notification
    // itself is untouched either way: it waits in the notification centre as usual
    CONFIG_PROPERTY(bool, notifsTakeOver, true)
    // Ask for a password in a panel that drops out of the notch, rather than a card in the middle
    // of the screen (see modules/polkit)
    CONFIG_PROPERTY(bool, showPolkit, true)
};

} // namespace caelestia::shell::config
