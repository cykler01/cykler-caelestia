#pragma once

#include <qstring.h>
#include <qvariantlist.h>

#include "settings/objectnode.hpp"
#include "common.hpp"
#include "enums.hpp"

namespace caelestia::shell::config {

using Qt::StringLiterals::operator""_s;
using settings::vmap;

// One card on the dashboard's home (Dash) page. The page keeps the two-row shape it has always
// had - a top row and a bottom row side by side, with full-height columns either side of them -
// and a card says which of those four places it sits in; its position in the list is its order
// within that place. Mirrors LockWidgetEntry (lockconfig.hpp), which does the same for the lock
// screen's side columns
class DashWidgetEntry : public settings::ObjectNode {
    CONFIG_NODE(DashWidgetEntry, settings::ObjectNode)

    CONFIG_PROPERTY(QString, id, {})
    CONFIG_PROPERTY(bool, enabled, true)
    // "top" or "bottom" for the two rows, "left" or "right" for a full-height column beside them
    CONFIG_PROPERTY(QString, zone, u"top"_s)
};
CONFIG_LIST_TYPE(DashWidgetEntry, DashWidgetList)

class DashboardPerformance : public settings::ObjectNode {
    CONFIG_NODE(DashboardPerformance, settings::ObjectNode)

    CONFIG_PROPERTY(bool, showBattery, true)
    CONFIG_PROPERTY(bool, showGpu, true)
    CONFIG_PROPERTY(bool, showCpu, true)
    CONFIG_PROPERTY(bool, showMemory, true)
    CONFIG_PROPERTY(bool, showStorage, true)
    CONFIG_PROPERTY(bool, showNetwork, true)
    CONFIG_PROPERTY(bool, graphView, true)
    CONFIG_ENUM_PROPERTY(PerfGraphColours, graphColours, PerfGraphColours::Scheme)
    // Colours used by the Custom graph scheme: a palette role (e.g. "primary", "term1") or a #rrggbb hex
    CONFIG_PROPERTY(QString, cpuColour, u"primary"_s)
    CONFIG_PROPERTY(QString, gpuColour, u"secondary"_s)
    CONFIG_PROPERTY(QString, memoryColour, u"tertiary"_s)
    CONFIG_PROPERTY(QString, networkColour, u"success"_s)
    CONFIG_PROPERTY(QString, storageColour, u"onSurfaceVariant"_s)
};

class DashboardConfig : public settings::ObjectNode {
    CONFIG_NODE(DashboardConfig, settings::ObjectNode)

    CONFIG_PROPERTY(bool, enabled, true)
    CONFIG_ENUM_PROPERTY(PanelEdge, edge, PanelEdge::Top)
    CONFIG_ENUM_PROPERTY(PanelAlign, align, PanelAlign::Center)
    CONFIG_PROPERTY(bool, showOnHover, true)
    CONFIG_PROPERTY(bool, showDashboard, true)
    CONFIG_PROPERTY(bool, showMedia, true)
    CONFIG_PROPERTY(bool, showPerformance, true)
    CONFIG_PROPERTY(bool, showWeather, true)
    CONFIG_PROPERTY(bool, showClockSeconds, false)
    // MaterialShape name (M3Shapes) the dashboard's profile picture is clipped to - resolved against
    // the enum in modules/dashboard/dash/User.qml, the same way Config.lock.profileShape is on the
    // lock screen
    CONFIG_PROPERTY(QString, profileShape, u"Pill"_s)
    // Analogue dial instead of the digital readout in the home page's clock card
    // (modules/dashboard/dash/DateTime.qml)
    CONFIG_PROPERTY(bool, analogueClock, false)

    CONFIG_GLOBAL_PROPERTY(int, mediaUpdateInterval, 500)
    CONFIG_GLOBAL_PROPERTY(int, resourceUpdateInterval, 1000)
    CONFIG_PROPERTY(int, dragThreshold, 50)
    // Which cards the home page shows, where, and in what order (ids: weather, clock, profile,
    // calendar, resources, media). The defaults are the fixed layout this page had before it
    // became arrangeable. Settings > Panels > Dashboard > Widgets writes it
    // (modules/nexus/pages/panels/DashWidgetsPanel.qml)
    CONFIG_LIST(DashWidgetList, widgets,
        DEFAULT_ARG({
            vmap({ { u"id"_s, u"weather"_s }, { u"zone"_s, u"top"_s } }),
            vmap({ { u"id"_s, u"profile"_s }, { u"zone"_s, u"top"_s } }),
            vmap({ { u"id"_s, u"clock"_s }, { u"zone"_s, u"bottom"_s } }),
            vmap({ { u"id"_s, u"calendar"_s }, { u"zone"_s, u"bottom"_s } }),
            vmap({ { u"id"_s, u"resources"_s }, { u"zone"_s, u"bottom"_s } }),
            vmap({ { u"id"_s, u"media"_s }, { u"zone"_s, u"right"_s } }),
        }))
    CONFIG_SUBOBJECT(DashboardPerformance, performance)
};

} // namespace caelestia::shell::config
