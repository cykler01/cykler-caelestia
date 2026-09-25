#pragma once

#include <qstringlist.h>

#include "settings/objectnode.hpp"
#include "common.hpp"
#include "enums.hpp"

namespace caelestia::config {

using Qt::StringLiterals::operator""_s;

class NotifsConfig : public settings::ObjectNode {
    CONFIG_NODE(NotifsConfig, settings::ObjectNode)

    // Which side edge the notification popups stack from
    CONFIG_ENUM_PROPERTY(PanelSide, side, PanelSide::Right)
    // Top or bottom of that side (together with side: one of the four corners)
    CONFIG_ENUM_PROPERTY(PanelEdge, edge, PanelEdge::Top)
    CONFIG_GLOBAL_PROPERTY(bool, expire, true)
    CONFIG_GLOBAL_ENUM_PROPERTY(NotifsFullscreen, fullscreen, NotifsFullscreen::On)
    CONFIG_GLOBAL_PROPERTY(int, defaultExpireTimeout, 5000)
    CONFIG_GLOBAL_PROPERTY(int, fullscreenExpireTimeout, 2000)
    CONFIG_PROPERTY(qreal, clearThreshold, 0.3)
    CONFIG_PROPERTY(int, expandThreshold, 20)
    CONFIG_GLOBAL_PROPERTY(bool, actionOnClick, false)
    CONFIG_PROPERTY(int, groupPreviewNum, 3)
    CONFIG_PROPERTY(bool, openExpanded, false)
    // Chat apps reuse one notification per conversation and replace it with each new message;
    // for these apps the replaced messages are kept as their own notifications
    CONFIG_GLOBAL_PROPERTY(bool, keepChatHistory, true)
    CONFIG_GLOBAL_PROPERTY(QStringList, chatApps,
        DEFAULT_ARG({
            u"vesktop"_s,
            u"discord"_s,
            u"vencord"_s,
            u"legcord"_s,
            u"webcord"_s,
            u"equibop"_s,
            u"slack"_s,
            u"signal"_s,
            u"telegram"_s,
            u"whatsapp"_s,
            u"firefox"_s,
        }))
};

} // namespace caelestia::config
