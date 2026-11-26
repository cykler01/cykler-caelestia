#pragma once

#include <qstring.h>
#include <qvariantlist.h>

#include "settings/objectnode.hpp"
#include "common.hpp"
#include "enums.hpp"

namespace caelestia::shell::config {

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

// NOTE(fork): one thing on the lock screen (modules/lock/canvas). The screen is nothing but a list
// of these, arranged in Nexus > Lock screen > Edit layout; only the password field is required. What
// each kind is and which options it takes are listed in modules/lock/canvas/ElementCatalog.qml
class LockElement : public settings::ObjectNode {
    CONFIG_NODE(LockElement, settings::ObjectNode)

    // Which kind of element: "password", "clock", "date", "avatar", "panel", "widgets", ...
    CONFIG_PROPERTY(QString, id, {})
    CONFIG_PROPERTY(bool, enabled, true)
    // Where its anchor point sits, as a fraction of the screen's width and height
    CONFIG_PROPERTY(qreal, x, 0.5)
    CONFIG_PROPERTY(qreal, y, 0.5)
    // Which point of the element that is: "tl", "t", "tr", "l", "c", "r", "bl", "b" or "br". So an
    // element pinned by its right edge stays on the right of a wider screen
    CONFIG_PROPERTY(QString, anchor, u"c"_s)
    // Size as a fraction of the screen, for the kinds that fill a box (panels, widget columns).
    // 0 leaves the element at its natural size
    CONFIG_PROPERTY(qreal, w, 0)
    CONFIG_PROPERTY(qreal, h, 0)
    // Multiplier on the element's natural size
    CONFIG_PROPERTY(qreal, scale, 1.0)
    CONFIG_PROPERTY(qreal, opacity, 1.0)
    // Quarter turns: 0, 90 or -90
    CONFIG_PROPERTY(int, rotation, 0)
    // When it shows: "always", "rest" (until a key or click starts the sign-in) or "active" (once
    // it has). Elements on rest and active together make a curtain that lifts on the first key
    CONFIG_PROPERTY(QString, showOn, u"always"_s)
    // Options of the element's own kind (clock face, text, colour, ...)
    CONFIG_PROPERTY(QVariantMap, options, {})
};
CONFIG_LIST_TYPE(LockElement, LockElementList)

class LockConfig : public settings::ObjectNode {
    CONFIG_NODE(LockConfig, settings::ObjectNode)

    CONFIG_PROPERTY(bool, enabled, true)
    // NOTE(fork): what's on the lock screen and where (modules/lock/canvas). Empty until the layout
    // is first edited, and until then the screen is built from the preset that layout names below
    CONFIG_LIST(LockElementList, elements, DEFAULT_ARG({}))
    // The lock screen layouts from before elements, kept only so a config still naming one opens
    // on the same look: "card", "split", "sidebar", "curtain", "band", "console", "shelf", "profile",
    // "bento", "minimal", "stage", "watch", "fuzzy", "glance", "vertical", "flip" or "dotmatrix"
    // (modules/lock/canvas/LockPresets.qml)
    CONFIG_PROPERTY(QString, layout, u"card"_s)
    // Which side the split, sidebar and band layouts above had their login on ("left" or "right"),
    // likewise kept only for that
    CONFIG_PROPERTY(QString, panelSide, u"right"_s)
    // No longer read: whether there are status pills is whether there's a status element. Kept so
    // configs that still set it load without complaint
    CONFIG_PROPERTY(bool, statusChips, true)
    // Which pills the status element shows and in what order, outermost first (modules/lock/layouts/StatusChips.qml).
    // ids: battery, network, bluetooth, volume, mic, vpn, keyboard, notifs, media, power, uptime -
    // everything past bluetooth is opt-in from the settings page's add button
    CONFIG_LIST(EntryList, statusEntries,
        DEFAULT_ARG({
            LIST_ENTRY(battery, true),
            LIST_ENTRY(network, true),
            LIST_ENTRY(bluetooth, true),
        }))
    CONFIG_PROPERTY(bool, useWallpaper, false)
    // NOTE(fork): how strongly the background is blurred behind the lock UI, 0 (sharp) to 1 (the
    // original full blur) - modules/lock/LockSurface.qml
    CONFIG_PROPERTY(qreal, blur, 1.0)
    // NOTE(fork): an image (or video) shown only on the lock screen, in place of both the desktop
    // wallpaper and the session capture. Empty keeps those as they were. Set from Nexus, which
    // copies the chosen file into the shell's data directory so it outlives the original
    CONFIG_PROPERTY(QString, wallpaper, {})
    CONFIG_PROPERTY(bool, recolourLogo, true)
    CONFIG_GLOBAL_PROPERTY(bool, enableFprint, true)
    CONFIG_GLOBAL_PROPERTY(int, maxFprintTries, 3)
    CONFIG_GLOBAL_PROPERTY(bool, enableFaceAuth, true)
    CONFIG_GLOBAL_ENUM_PROPERTY(FaceAuthProvider, faceAuthProvider, FaceAuthProvider::Howdy)
    CONFIG_GLOBAL_PROPERTY(int, maxFaceAuthTries, 3)
    CONFIG_GLOBAL_PROPERTY(bool, triggerFaceAuthOnWake, true)
    CONFIG_PROPERTY(bool, hideNotifs, false)
    // NOTE(fork): the lock UI fades out after hideIdleDelay seconds with no pointer movement or
    // keystroke, leaving only the background behind it (modules/lock/LockSurface.qml). Worth
    // pairing with useWallpaper, since the background is otherwise a capture of the session
    CONFIG_PROPERTY(bool, hideIdle, false)
    CONFIG_PROPERTY(int, hideIdleDelay, 30)
    // The same dino game, played in the notification dock from its empty state
    // (modules/lock/NotifDock.qml)
    CONFIG_PROPERTY(bool, dinoGame, false)
    // Whether the classic card had an analogue dial, kept only to carry over into its preset
    CONFIG_PROPERTY(bool, analogueClock, false)
    // MaterialShape name (M3Shapes) the profile picture is clipped to - resolved against the
    // enum in modules/lock/center/ProfilePic.qml
    CONFIG_PROPERTY(QString, profileShape, u"ClamShell"_s)
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
    // The lock screen widgets from before widget columns named their own (the "widgets" option of
    // a widget column element). Still read for the weight a widget was given here, and for the
    // widgets of a column saved before then (ids: weather, fetch, media, resources, battery,
    // notifs, network, audio, events, day)
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

} // namespace caelestia::shell::config
