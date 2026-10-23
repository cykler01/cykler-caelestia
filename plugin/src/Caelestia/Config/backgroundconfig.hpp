#pragma once

#include <qstring.h>
#include <qstringlist.h>

#include "settings/objectnode.hpp"
#include "common.hpp"
#include "enums.hpp"

namespace caelestia::shell::config {

using Qt::StringLiterals::operator""_s;

class DesktopClockBackground : public settings::ObjectNode {
    CONFIG_NODE(DesktopClockBackground, settings::ObjectNode)

    CONFIG_PROPERTY(bool, enabled, false)
    CONFIG_PROPERTY(qreal, opacity, 0.7)
    CONFIG_PROPERTY(bool, blur, true)
};

class DesktopClockShadow : public settings::ObjectNode {
    CONFIG_NODE(DesktopClockShadow, settings::ObjectNode)

    CONFIG_PROPERTY(bool, enabled, true)
    CONFIG_PROPERTY(qreal, opacity, 0.7)
    CONFIG_PROPERTY(qreal, blur, 0.4)
};

class DesktopClock : public settings::ObjectNode {
    CONFIG_NODE(DesktopClock, settings::ObjectNode)

    CONFIG_PROPERTY(bool, enabled, false)
    CONFIG_PROPERTY(qreal, scale, 1.0)
    CONFIG_PROPERTY(QString, position, u"bottom-right"_s)
    CONFIG_PROPERTY(bool, invertColors, false)
    CONFIG_SUBOBJECT(DesktopClockBackground, background)
    CONFIG_SUBOBJECT(DesktopClockShadow, shadow)
};

class BackgroundVisualiser : public settings::ObjectNode {
    CONFIG_NODE(BackgroundVisualiser, settings::ObjectNode)

    CONFIG_PROPERTY(bool, enabled, false)
    CONFIG_PROPERTY(bool, autoHide, true)
    CONFIG_PROPERTY(bool, blur, false)
    CONFIG_PROPERTY(qreal, rounding, 1)
    CONFIG_PROPERTY(qreal, spacing, 1)
};

class DesktopIcons : public settings::ObjectNode {
    CONFIG_NODE(DesktopIcons, settings::ObjectNode)

    CONFIG_PROPERTY(bool, enabled, false)
    // Desktop entry ids (e.g. "firefox", "org.kde.dolphin") shown in order
    CONFIG_PROPERTY(QStringList, apps, {})
    CONFIG_PROPERTY(QString, position, u"top-left"_s)
    CONFIG_PROPERTY(int, iconSize, 48)
    CONFIG_PROPERTY(bool, showLabels, true)
    // Fade out while the active workspace has windows on it
    CONFIG_PROPERTY(bool, hideWithWindows, true)
};

class DesktopWidgetEntry : public settings::ObjectNode {
    CONFIG_NODE(DesktopWidgetEntry, settings::ObjectNode)

    CONFIG_PROPERTY(QString, id, {})
    CONFIG_PROPERTY(bool, enabled, true)
    // Cell on the desktop grid, counted from the top. -1 until the widget is placed by hand, when it flows into the
    // default layout
    CONFIG_PROPERTY(int, col, -1)
    CONFIG_PROPERTY(int, row, -1)
    // Whether col counts from the right edge (to the widget's right side) rather than the left, so a widget placed on
    // the right of one screen stays on the right of a wider one
    CONFIG_PROPERTY(bool, right, false)
};
CONFIG_LIST_TYPE(DesktopWidgetEntry, DesktopWidgetList)

class DesktopWidgets : public settings::ObjectNode {
    CONFIG_NODE(DesktopWidgets, settings::ObjectNode)

    CONFIG_PROPERTY(bool, enabled, false)
    CONFIG_PROPERTY(QString, position, u"top-right"_s)
    // Number of columns in the widget grid; the widgets flow into it in the order given below
    CONFIG_PROPERTY(int, columns, 2)
    // Which widgets show and where (ids: calendar, weather, pomodoro, resources, media, battery)
    CONFIG_LIST(DesktopWidgetList, entries,
        DEFAULT_ARG({
            LIST_ENTRY(calendar, true),
            LIST_ENTRY(weather, true),
            LIST_ENTRY(pomodoro, true),
            LIST_ENTRY(resources, true),
            LIST_ENTRY(media, true),
            LIST_ENTRY(battery, true),
        }))
    CONFIG_PROPERTY(bool, hideWithWindows, true)
    CONFIG_PROPERTY(qreal, opacity, 0.7)
    CONFIG_PROPERTY(bool, blur, true)
};

class BackgroundConfig : public settings::ObjectNode {
    CONFIG_NODE(BackgroundConfig, settings::ObjectNode)

    CONFIG_PROPERTY(bool, enabled, true)
    CONFIG_PROPERTY(bool, wallpaperEnabled, true)
    CONFIG_ENUM_PROPERTY(WallpaperTransition, wallpaperTransition, WallpaperTransition::Crossfade)
    CONFIG_SUBOBJECT(DesktopClock, desktopClock)
    CONFIG_SUBOBJECT(DesktopIcons, desktopIcons)
    CONFIG_SUBOBJECT(DesktopWidgets, desktopWidgets)
    CONFIG_SUBOBJECT(BackgroundVisualiser, visualiser)
};

} // namespace caelestia::shell::config
