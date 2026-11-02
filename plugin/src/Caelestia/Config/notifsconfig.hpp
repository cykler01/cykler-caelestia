#pragma once

#include <qstringlist.h>

#include "settings/objectnode.hpp"
#include "common.hpp"
#include "enums.hpp"

namespace caelestia::shell::config {

using Qt::StringLiterals::operator""_s;

class NotifSourceRule : public settings::ObjectNode {
    CONFIG_NODE(NotifSourceRule, settings::ObjectNode)

    // Matched case-insensitively as a substring of the name an app puts on its notifications. It
    // does not have to be an installed app, so a script or a notify-send caller can be named too
    CONFIG_PROPERTY(QString, match, {})
    CONFIG_ENUM_PROPERTY(NotifSourceAction, action, NotifSourceAction::Silence)
};
CONFIG_LIST_TYPE(NotifSourceRule, NotifSourceRuleList)

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
    // Apps matched here (case-insensitively, by substring of their notification app name) never
    // popup - they go straight to the notification centre, the same as every app does under
    // do not disturb, but regardless of whether do not disturb is on
    CONFIG_GLOBAL_PROPERTY(QStringList, silencedApps, DEFAULT_ARG({}))
    // Per-source rules, from Settings › Services › Notifications › Sources: Allow shows a
    // notification and keeps it in the history, Discard shows the popup and keeps nothing, and
    // Silence drops it entirely. The first rule matching the app name wins; anything unmatched is
    // allowed
    CONFIG_LIST(NotifSourceRuleList, sourceRules, DEFAULT_ARG({}))
};

} // namespace caelestia::shell::config
