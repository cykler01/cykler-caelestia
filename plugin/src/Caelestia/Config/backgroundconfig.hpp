#pragma once

#include <qstandardpaths.h>
#include <qstring.h>
#include <qstringlist.h>
#include <qvariantlist.h>

#include "settings/objectnode.hpp"
#include "common.hpp"
#include "enums.hpp"

namespace caelestia::shell::config {

using Qt::StringLiterals::operator""_s;
using settings::vmap;

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
    // Which variant of that widget this entry shows, from utils/WidgetCatalog.qml ("month", "compact",
    // ...); empty falls back to the kind's first variant
    CONFIG_PROPERTY(QString, type, {})
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

class ProgressEntry : public settings::ObjectNode {
    CONFIG_NODE(ProgressEntry, settings::ObjectNode)

    // A name to show; empty falls back to the mode's own name
    CONFIG_PROPERTY(QString, label, {})
    // "day" and "week" run from the current calendar; "date" and "interval" use the fields
    // below (YYYY-MM-DD or YYYY-MM-DD HH:mm, local time)
    CONFIG_PROPERTY(QString, mode, u"date"_s)
    CONFIG_PROPERTY(QString, start, {})
    CONFIG_PROPERTY(QString, end, {})
    CONFIG_PROPERTY(bool, enabled, true)
};
CONFIG_LIST_TYPE(ProgressEntry, ProgressEntryList)

class StockShare : public settings::ObjectNode {
    CONFIG_NODE(StockShare, settings::ObjectNode)

    // Ticker the amount belongs to; a zero amount simply watches the stock
    CONFIG_PROPERTY(QString, symbol, {})
    CONFIG_PROPERTY(qreal, shares, 0.0)
};
CONFIG_LIST_TYPE(StockShare, StockShareList)

class DesktopWidgets : public settings::ObjectNode {
    CONFIG_NODE(DesktopWidgets, settings::ObjectNode)

    CONFIG_PROPERTY(bool, enabled, false)
    CONFIG_PROPERTY(QString, position, u"top-right"_s)
    // Number of columns in the widget grid; the widgets flow into it in the order given below
    CONFIG_PROPERTY(int, columns, 2)
    // Which widgets show and where. Empty by default: widgets are picked one at a time, kind first and then
    // variant, from Settings › Panels › Widgets › Add widget. Kinds are listed in utils/WidgetCatalog.qml
    CONFIG_LIST(DesktopWidgetList, entries, DEFAULT_ARG({}))
    CONFIG_PROPERTY(bool, hideWithWindows, true)
    // GitHub user whose contributions the contributions card shows
    CONFIG_PROPERTY(QString, githubUser, {})
    // Yahoo Finance tickers shown by the stocks card, in display order
    CONFIG_PROPERTY(QStringList, stockSymbols, DEFAULT_ARG({ u"AAPL"_s, u"MSFT"_s, u"NVDA"_s }))
    // How many shares of each ticker are held. Symbols with no entry here are watchlist-only
    CONFIG_LIST(StockShareList, stockShares, DEFAULT_ARG({}))
    // "relative" shows the quote price in the stocks card; "holdings" shows the value of the shares
    CONFIG_PROPERTY(QString, stockValueMode, u"relative"_s)
    // How long the spotlight card keeps one stock on its chart before moving to the next (ms)
    CONFIG_PROPERTY(int, stockSpotlightInterval, 60000)
    // Progress card targets. Day and week are always available out of the box; the settings page
    // adds custom dates and intervals to this list
    CONFIG_LIST(ProgressEntryList, progressEntries,
        DEFAULT_ARG({
            vmap({ { u"mode"_s, u"day"_s } }),
            vmap({ { u"mode"_s, u"week"_s } }),
        }))
    // The folder the photo card picks from; the user's pictures unless told otherwise
    CONFIG_PROPERTY(QString, photoDir, QStandardPaths::writableLocation(QStandardPaths::PicturesLocation))
    CONFIG_PROPERTY(qreal, opacity, 0.7)
    CONFIG_PROPERTY(bool, blur, true)
};

class BackgroundConfig : public settings::ObjectNode {
    CONFIG_NODE(BackgroundConfig, settings::ObjectNode)

    CONFIG_PROPERTY(bool, enabled, true)
    CONFIG_PROPERTY(bool, wallpaperEnabled, true)
    CONFIG_ENUM_PROPERTY(WallpaperTransition, wallpaperTransition, WallpaperTransition::Crossfade)
    // NOTE(fork): wallpaper rotation, both off by default. Global only, since a single timer switches
    // the wallpaper for the whole session rather than per monitor. The interval is in milliseconds to
    // match the other update intervals; the page shows it in minutes.
    CONFIG_GLOBAL_PROPERTY(bool, randomWallpaperOnStart, false)
    CONFIG_GLOBAL_PROPERTY(bool, wallpaperCycle, false)
    CONFIG_GLOBAL_PROPERTY(int, wallpaperCycleInterval, 1800000)
    CONFIG_SUBOBJECT(DesktopClock, desktopClock)
    CONFIG_SUBOBJECT(DesktopIcons, desktopIcons)
    CONFIG_SUBOBJECT(DesktopWidgets, desktopWidgets)
    CONFIG_SUBOBJECT(BackgroundVisualiser, visualiser)
};

} // namespace caelestia::shell::config
