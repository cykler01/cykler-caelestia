#pragma once

#include <qstring.h>
#include <qstringlist.h>
#include <qvariantlist.h>

#include "settings/objectnode.hpp"
#include "util/i18n.hpp"
#include "common.hpp"

namespace caelestia::config {

using Qt::StringLiterals::operator""_s;
using settings::vmap;
using util::i18n::mark;
using util::i18n::markCtx;

class LauncherUseFuzzy : public settings::ObjectNode {
    CONFIG_NODE(LauncherUseFuzzy, settings::ObjectNode)

    CONFIG_GLOBAL_PROPERTY(bool, apps, false)
    CONFIG_GLOBAL_PROPERTY(bool, actions, false)
    CONFIG_GLOBAL_PROPERTY(bool, wallpapers, false)
};

class LauncherConfig : public settings::ObjectNode {
    CONFIG_NODE(LauncherConfig, settings::ObjectNode)

    CONFIG_PROPERTY(bool, enabled, true)
    CONFIG_PROPERTY(bool, showOnHover, false)
    CONFIG_PROPERTY(int, maxShown, 7)
    CONFIG_PROPERTY(int, maxWallpapers, 9)
    CONFIG_GLOBAL_PROPERTY(QString, specialPrefix, u"@"_s)
    CONFIG_GLOBAL_PROPERTY(QString, actionPrefix, u">"_s)
    CONFIG_GLOBAL_PROPERTY(bool, enableDangerousActions, false)
    CONFIG_GLOBAL_PROPERTY(bool, enableSupergfxctl, false)
    CONFIG_PROPERTY(int, dragThreshold, 50)
    CONFIG_GLOBAL_PROPERTY(bool, vimKeybinds, false)
    CONFIG_GLOBAL_PROPERTY(QStringList, favouriteApps, {})
    CONFIG_GLOBAL_PROPERTY(QStringList, hiddenApps, {})
    CONFIG_SUBOBJECT(LauncherUseFuzzy, useFuzzy)
    CONFIG_GLOBAL_PROPERTY(QVariantList, actions,
        DEFAULT_ARG({
            vmap({
                { u"name"_s, markCtx(u"Calculator"_s, u"launcher action"_s) },
                { u"icon"_s, u"calculate"_s },
                { u"description"_s, mark(u"Do simple maths equations (powered by Qalc)"_s) },
                { u"command"_s, QStringList{ u"autocomplete"_s, u"calc"_s } },
            }),
            vmap({
                { u"name"_s, markCtx(u"SSH"_s, u"launcher action"_s) },
                { u"icon"_s, u"terminal"_s },
                { u"description"_s, mark(u"Connect to a configured SSH host"_s) },
                { u"command"_s, QStringList{ u"autocomplete"_s, u"ssh"_s } },
            }),
            vmap({
                { u"name"_s, markCtx(u"GPU mode"_s, u"launcher action"_s) },
                { u"icon"_s, u"developer_board"_s },
                { u"description"_s, mark(u"Switch the graphics mode with Supergfxctl"_s) },
                { u"command"_s, QStringList{ u"autocomplete"_s, u"gpu"_s } },
            }),
            vmap({
                { u"name"_s, markCtx(u"OCR"_s, u"launcher action"_s) },
                { u"icon"_s, u"text_fields"_s },
                { u"description"_s, mark(u"Capture a region and copy detected text"_s) },
                { u"command"_s, QStringList{ u"ocr"_s } },
            }),
            vmap({
                { u"name"_s, markCtx(u"Google Lens"_s, u"launcher action"_s) },
                { u"icon"_s, u"image_search"_s },
                { u"description"_s, mark(u"Search a captured region with Google Lens"_s) },
                { u"command"_s, QStringList{ u"lens"_s } },
            }),
            vmap({
                { u"name"_s, markCtx(u"Wallpaper"_s, u"launcher action"_s) },
                { u"icon"_s, u"image"_s },
                { u"description"_s, mark(u"Change the current wallpaper"_s) },
                { u"command"_s, QStringList{ u"autocomplete"_s, u"wallpaper"_s } },
            }),
            vmap({
                { u"name"_s, markCtx(u"Random"_s, u"launcher action"_s) },
                { u"icon"_s, u"casino"_s },
                { u"description"_s, mark(u"Switch to a random wallpaper"_s) },
                { u"command"_s, QStringList{ u"caelestia"_s, u"wallpaper"_s, u"-r"_s } },
            }),
            vmap({
                { u"name"_s, markCtx(u"Shutdown"_s, u"launcher action"_s) },
                { u"icon"_s, u"power_settings_new"_s },
                { u"description"_s, mark(u"Shutdown the system"_s) },
                { u"command"_s, QStringList{ u"poweroff"_s } },
                { u"dangerous"_s, true },
            }),
            vmap({
                { u"name"_s, markCtx(u"Reboot"_s, u"launcher action"_s) },
                { u"icon"_s, u"cached"_s },
                { u"description"_s, mark(u"Reboot the system"_s) },
                { u"command"_s, QStringList{ u"reboot"_s } },
                { u"dangerous"_s, true },
            }),
            vmap({
                { u"name"_s, markCtx(u"Logout"_s, u"launcher action"_s) },
                { u"icon"_s, u"exit_to_app"_s },
                { u"description"_s, mark(u"Log out of the current session"_s) },
                { u"command"_s, QStringList{ u"logout"_s } },
                { u"dangerous"_s, true },
            }),
            vmap({
                { u"name"_s, markCtx(u"Lock"_s, u"launcher action"_s) },
                { u"icon"_s, u"lock"_s },
                { u"description"_s, mark(u"Lock the current session"_s) },
                { u"command"_s, QStringList{ u"loginctl"_s, u"lock-session"_s } },
            }),
            vmap({
                { u"name"_s, markCtx(u"Sleep"_s, u"launcher action"_s) },
                { u"icon"_s, u"bedtime"_s },
                { u"description"_s, mark(u"Suspend then hibernate"_s) },
                { u"command"_s, QStringList{ u"suspendThenHibernate"_s } },
            }),
            vmap({
                { u"name"_s, markCtx(u"Settings"_s, u"launcher action"_s) },
                { u"icon"_s, u"settings"_s },
                { u"description"_s, mark(u"Configure the shell"_s) },
                { u"command"_s, QStringList{ u"caelestia"_s, u"shell"_s, u"nexus"_s, u"open"_s } },
            }),
        }))
};

} // namespace caelestia::config
