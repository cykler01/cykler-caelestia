#pragma once

#include <qstring.h>

#include "settings/objectnode.hpp"
#include "common.hpp"
#include "enums.hpp"

namespace caelestia::config {

using Qt::StringLiterals::operator""_s;

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
    CONFIG_PROPERTY(bool, showOnHover, true)
    CONFIG_PROPERTY(bool, showDashboard, true)
    CONFIG_PROPERTY(bool, showMedia, true)
    CONFIG_PROPERTY(bool, showPerformance, true)
    CONFIG_PROPERTY(bool, showWeather, true)
    CONFIG_PROPERTY(bool, showClockSeconds, false)
    CONFIG_GLOBAL_PROPERTY(int, mediaUpdateInterval, 500)
    CONFIG_GLOBAL_PROPERTY(int, resourceUpdateInterval, 1000)
    CONFIG_PROPERTY(int, dragThreshold, 50)
    CONFIG_SUBOBJECT(DashboardPerformance, performance)
};

} // namespace caelestia::config
