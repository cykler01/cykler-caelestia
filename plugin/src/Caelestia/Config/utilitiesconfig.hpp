#pragma once

#include <qstring.h>
#include <qstringlist.h>
#include <qvariantlist.h>
#include <qvariantmap.h>

#include "settings/objectnode.hpp"
#include "common.hpp"
#include "enums.hpp"

namespace caelestia::shell::config {

using Qt::StringLiterals::operator""_s;

class UtilitiesToasts : public settings::ObjectNode {
    CONFIG_NODE(UtilitiesToasts, settings::ObjectNode)

    // Which side edge the toasts appear on (bottom)
    CONFIG_GLOBAL_ENUM_PROPERTY(PanelSide, side, PanelSide::Right)
    CONFIG_GLOBAL_ENUM_PROPERTY(PanelEdge, edge, PanelEdge::Bottom)
    CONFIG_PROPERTY(QString, fullscreen, u"off"_s)
    CONFIG_GLOBAL_PROPERTY(bool, configLoaded, true)
    CONFIG_GLOBAL_PROPERTY(bool, chargingChanged, true)
    CONFIG_GLOBAL_PROPERTY(bool, gameModeChanged, true)
    CONFIG_GLOBAL_PROPERTY(bool, lowPowerModeChanged, true)
    CONFIG_GLOBAL_PROPERTY(bool, dndChanged, true)
    CONFIG_GLOBAL_PROPERTY(bool, audioOutputChanged, true)
    CONFIG_GLOBAL_PROPERTY(bool, audioInputChanged, true)
    CONFIG_GLOBAL_PROPERTY(bool, capsLockChanged, true)
    CONFIG_GLOBAL_PROPERTY(bool, numLockChanged, true)
    CONFIG_GLOBAL_PROPERTY(bool, kbLayoutChanged, true)
    CONFIG_GLOBAL_PROPERTY(bool, kbLimit, true)
    CONFIG_GLOBAL_PROPERTY(bool, vpnChanged, true)
    CONFIG_GLOBAL_PROPERTY(bool, repoUpdateAvailable, false)
};

// NOTE(fork): one configured VPN. A list node rather than a bare QVariantList, since the add,
// edit and delete paths in services/VPN.qml reach for insert(), at(), remove() and resetOption()
// on the list and its entries, none of which a plain variant list has
class UtilitiesVpnProvider : public settings::ObjectNode {
    CONFIG_NODE(UtilitiesVpnProvider, settings::ObjectNode)

    // Stable internal id, so a selection survives the provider being renamed
    CONFIG_PROPERTY(QString, id, {})
    CONFIG_PROPERTY(QString, name, {})
    CONFIG_PROPERTY(QString, displayName, {})
    // Watched to tell whether the tunnel is actually up
    CONFIG_PROPERTY(QString, interface, {})
    // Left empty for the built-in names, which fill in their own
    CONFIG_PROPERTY(QStringList, connectCmd, {})
    CONFIG_PROPERTY(QStringList, disconnectCmd, {})
};
CONFIG_LIST_TYPE(UtilitiesVpnProvider, UtilitiesVpnProviderList)

class UtilitiesVpn : public settings::ObjectNode {
    CONFIG_NODE(UtilitiesVpn, settings::ObjectNode)

    CONFIG_GLOBAL_PROPERTY(bool, enabled, false)
    CONFIG_LIST(UtilitiesVpnProviderList, provider, DEFAULT_ARG({}))
    CONFIG_GLOBAL_PROPERTY(QString, selectedProvider, QString())
};

// NOTE(fork): a random line of text along the bottom of the screen, picked from assets/bottom-texts.txt
class UtilitiesBottomText : public settings::ObjectNode {
    CONFIG_NODE(UtilitiesBottomText, settings::ObjectNode)

    CONFIG_GLOBAL_PROPERTY(bool, enabled, true)
    // How long one line stays before the next is picked (ms)
    CONFIG_GLOBAL_PROPERTY(int, cycleInterval, 60000)
};

// NOTE(fork): one quick toggle. Where it sits in the list is where it sits in the card
class UtilitiesToggleEntry : public settings::ObjectNode {
    CONFIG_NODE(UtilitiesToggleEntry, settings::ObjectNode)

    CONFIG_PROPERTY(QString, id, {})
    CONFIG_PROPERTY(bool, enabled, true)
    // How many of the card's columns the toggle takes up, 1 to the number of columns
    CONFIG_PROPERTY(int, span, 1)
};
CONFIG_LIST_TYPE(UtilitiesToggleEntry, UtilitiesToggleList)

// NOTE(fork): one card of the utilities panel. Whether it shows is still the bool of the same name in
// UtilitiesCards, the list gives the order the cards stack in and how big each one is
class UtilitiesCardEntry : public settings::ObjectNode {
    CONFIG_NODE(UtilitiesCardEntry, settings::ObjectNode)

    // "keepAwake", "recorder", "phoneShare", "quickToggles" or "appVolumes"
    CONFIG_PROPERTY(QString, id, {})
    // "normal", "compact" or "vertical", what the latter two drop or rearrange is up to the card
    CONFIG_PROPERTY(QString, size, u"normal"_s)
};
CONFIG_LIST_TYPE(UtilitiesCardEntry, UtilitiesCardList)

class UtilitiesCards : public settings::ObjectNode {
    CONFIG_NODE(UtilitiesCards, settings::ObjectNode)

    // Top to bottom
    CONFIG_LIST(UtilitiesCardList, order,
        DEFAULT_ARG({
            vmap({ { u"id"_s, u"keepAwake"_s } }),
            vmap({ { u"id"_s, u"recorder"_s } }),
            vmap({ { u"id"_s, u"phoneShare"_s } }),
            vmap({ { u"id"_s, u"quickToggles"_s } }),
            vmap({ { u"id"_s, u"appVolumes"_s } }),
        }))
    // How many columns the quick toggles are laid out in
    CONFIG_PROPERTY(int, toggleColumns, 4)
    CONFIG_PROPERTY(bool, keepAwake, true)
    CONFIG_PROPERTY(bool, recorder, true)
    CONFIG_PROPERTY(bool, quickToggles, true)
    CONFIG_PROPERTY(bool, phoneShare, false)
    CONFIG_PROPERTY(bool, appVolumes, false)
};

class UtilitiesGameMode : public settings::ObjectNode {
    CONFIG_NODE(UtilitiesGameMode, settings::ObjectNode)

    CONFIG_PROPERTY(QVariantMap, options,
        vmap({
            { u"animations:enabled"_s, 0 },
            { u"decoration:shadow:enabled"_s, 0 },
            { u"decoration:blur:enabled"_s, 0 },
            { u"general:gaps_in"_s, 0 },
            { u"general:gaps_out"_s, 0 },
            { u"general:border_size"_s, 1 },
            { u"decoration:rounding"_s, 0 },
            { u"general:allow_tearing"_s, 1 },
            { u"input:accel_profile"_s, u"flat"_s },
        }))
};

class UtilitiesConfig : public settings::ObjectNode {
    CONFIG_NODE(UtilitiesConfig, settings::ObjectNode)

    CONFIG_PROPERTY(bool, enabled, true)
    CONFIG_PROPERTY(int, maxToasts, 4)
    CONFIG_SUBOBJECT(UtilitiesCards, cards)
    CONFIG_GLOBAL_SUBOBJECT(UtilitiesToasts, toasts)
    CONFIG_GLOBAL_SUBOBJECT(UtilitiesVpn, vpn)
    CONFIG_GLOBAL_SUBOBJECT(UtilitiesGameMode, gameMode)
    CONFIG_GLOBAL_SUBOBJECT(UtilitiesBottomText, bottomText)
    CONFIG_LIST(UtilitiesToggleList, quickToggles,
        DEFAULT_ARG({
            LIST_ENTRY(wifi, true),
            LIST_ENTRY(bluetooth, true),
            LIST_ENTRY(mic, true),
            LIST_ENTRY(timer, true),
            LIST_ENTRY(settings, true),
            LIST_ENTRY(lock, true),
            LIST_ENTRY(gameMode, true),
            LIST_ENTRY(wallpaperPlaying, true),
            LIST_ENTRY(dnd, true),
            LIST_ENTRY(vpn, false),
        }))
};

} // namespace caelestia::shell::config
