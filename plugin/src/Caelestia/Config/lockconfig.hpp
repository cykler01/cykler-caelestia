#pragma once

#include <qstring.h>
#include <qvariantlist.h>

#include "settings/objectnode.hpp"
#include "common.hpp"

namespace caelestia::config {

using Qt::StringLiterals::operator""_s;
using settings::vmap;

class LockWidgetEntry : public settings::ObjectNode {
    CONFIG_NODE(LockWidgetEntry, settings::ObjectNode)

    CONFIG_PROPERTY(QString, id, {})
    CONFIG_PROPERTY(bool, enabled, true)
    CONFIG_PROPERTY(QString, column, u"left"_s)
    // Share of its column's height relative to the other visible widgets in it - a drag
    // handle in the editor adjusts this directly against its neighbour's
    CONFIG_PROPERTY(qreal, weight, 1.0)
};
CONFIG_LIST_TYPE(LockWidgetEntry, LockWidgetList)

class LockConfig : public settings::ObjectNode {
    CONFIG_NODE(LockConfig, settings::ObjectNode)

    CONFIG_PROPERTY(bool, enabled, true)
    CONFIG_PROPERTY(bool, useWallpaper, false)
    CONFIG_PROPERTY(bool, recolourLogo, true)
    CONFIG_GLOBAL_PROPERTY(bool, enableFprint, true)
    CONFIG_GLOBAL_PROPERTY(int, maxFprintTries, 3)
    CONFIG_GLOBAL_PROPERTY(bool, enableHowdy, true)
    CONFIG_GLOBAL_PROPERTY(int, maxHowdyTries, 3)
    CONFIG_GLOBAL_PROPERTY(bool, triggerHowdyOnWake, true)
    CONFIG_PROPERTY(bool, hideNotifs, false)
    CONFIG_GLOBAL_PROPERTY(bool, enableSessionControls, false)
    // Which actions show while the session controls are revealed, and in what order
    // (ids: logout, shutdown, sleep, reboot)
    CONFIG_LIST(EntryList, entries,
        DEFAULT_ARG({
            LIST_ENTRY(logout, true),
            LIST_ENTRY(shutdown, true),
            LIST_ENTRY(sleep, true),
            LIST_ENTRY(reboot, true),
        }))
    // Which widgets show in the side columns, in what order, which column, and how much
    // vertical room each gets (ids: weather, fetch, media, resources, battery, notifs)
    CONFIG_LIST(LockWidgetList, widgets,
        DEFAULT_ARG({
            vmap({ { u"id"_s, u"weather"_s }, { u"column"_s, u"left"_s }, { u"weight"_s, 1.0 } }),
            vmap({ { u"id"_s, u"fetch"_s }, { u"column"_s, u"left"_s }, { u"weight"_s, 0.8 } }),
            vmap({ { u"id"_s, u"media"_s }, { u"column"_s, u"left"_s }, { u"weight"_s, 1.3 } }),
            vmap({ { u"id"_s, u"resources"_s }, { u"column"_s, u"right"_s }, { u"weight"_s, 1.0 } }),
            vmap({ { u"id"_s, u"battery"_s }, { u"column"_s, u"right"_s }, { u"weight"_s, 0.6 } }),
            vmap({ { u"id"_s, u"notifs"_s }, { u"column"_s, u"right"_s }, { u"weight"_s, 1.6 } }),
        }))
};

} // namespace caelestia::config
