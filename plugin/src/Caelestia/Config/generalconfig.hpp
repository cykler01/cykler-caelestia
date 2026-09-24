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

class GeneralApps : public settings::ObjectNode {
    CONFIG_NODE(GeneralApps, settings::ObjectNode)

    CONFIG_GLOBAL_PROPERTY(QStringList, terminal, { u"foot"_s })
    CONFIG_GLOBAL_PROPERTY(QStringList, audio, { u"pwvucontrol"_s })
    CONFIG_GLOBAL_PROPERTY(QStringList, playback, { u"mpv"_s })
    CONFIG_GLOBAL_PROPERTY(QStringList, explorer, { u"thunar"_s })
};

class GeneralIdle : public settings::ObjectNode {
    CONFIG_NODE(GeneralIdle, settings::ObjectNode)

    CONFIG_GLOBAL_PROPERTY(bool, lockBeforeSleep, true)
    CONFIG_GLOBAL_PROPERTY(bool, inhibitWhenAudio, true)
    CONFIG_GLOBAL_PROPERTY(bool, inhibitWhenCharging, false)
    CONFIG_GLOBAL_PROPERTY(QVariantList, timeouts,
        DEFAULT_ARG({
            vmap({
                { u"timeout"_s, 180 },
                { u"idleAction"_s, u"lock"_s },
            }),
            vmap({
                { u"timeout"_s, 300 },
                { u"idleAction"_s, u"dpms off"_s },
                { u"returnAction"_s, u"dpms on"_s },
            }),
            vmap({
                { u"timeout"_s, 600 },
                { u"idleAction"_s, QStringList{ u"suspendThenHibernate"_s } },
            }),
        }))
};

// NOTE(fork): Battery power management (ported from feat/low-battery-optimization).
// The behavior classes intentionally do NOT share a base class: the settings
// schema only registers properties declared directly on each class, so
// inherited properties would be unknown keys when written.
class GeneralChargingBehavior : public settings::ObjectNode {
    CONFIG_NODE(GeneralChargingBehavior, settings::ObjectNode)

    CONFIG_GLOBAL_PROPERTY(QString, setPowerProfile, u"restore"_s)
    CONFIG_GLOBAL_PROPERTY(QString, setRefreshRate, u"restore"_s)
    CONFIG_GLOBAL_PROPERTY(QString, disableAnimations, QString())
    CONFIG_GLOBAL_PROPERTY(QString, disableBlur, QString())
    CONFIG_GLOBAL_PROPERTY(QString, disableRounding, QString())
    CONFIG_GLOBAL_PROPERTY(QString, disableShadows, QString())
};

class GeneralUnpluggedBehavior : public settings::ObjectNode {
    CONFIG_NODE(GeneralUnpluggedBehavior, settings::ObjectNode)

    CONFIG_GLOBAL_PROPERTY(QString, setPowerProfile, u"restore"_s)
    CONFIG_GLOBAL_PROPERTY(QString, setRefreshRate, u"restore"_s)
    CONFIG_GLOBAL_PROPERTY(QString, disableAnimations, QString())
    CONFIG_GLOBAL_PROPERTY(QString, disableBlur, QString())
    CONFIG_GLOBAL_PROPERTY(QString, disableRounding, QString())
    CONFIG_GLOBAL_PROPERTY(QString, disableShadows, QString())
    CONFIG_GLOBAL_PROPERTY(bool, evaluateThresholds, true)
};

class GeneralProfileBehavior : public settings::ObjectNode {
    CONFIG_NODE(GeneralProfileBehavior, settings::ObjectNode)

    CONFIG_GLOBAL_PROPERTY(QString, setPowerProfile, QString())
    CONFIG_GLOBAL_PROPERTY(QString, setRefreshRate, QString())
    CONFIG_GLOBAL_PROPERTY(QString, disableAnimations, QString())
    CONFIG_GLOBAL_PROPERTY(QString, disableBlur, QString())
    CONFIG_GLOBAL_PROPERTY(QString, disableRounding, QString())
    CONFIG_GLOBAL_PROPERTY(QString, disableShadows, QString())
};

class GeneralProfileBehaviors : public settings::ObjectNode {
    CONFIG_NODE(GeneralProfileBehaviors, settings::ObjectNode)

    CONFIG_GLOBAL_SUBOBJECT(GeneralProfileBehavior, powerSaver)
    CONFIG_GLOBAL_SUBOBJECT(GeneralProfileBehavior, balanced)
    CONFIG_GLOBAL_SUBOBJECT(GeneralProfileBehavior, performance)
};

class GeneralPowerManagement : public settings::ObjectNode {
    CONFIG_NODE(GeneralPowerManagement, settings::ObjectNode)

    CONFIG_GLOBAL_PROPERTY(bool, enabled, false)
    // Shell features paused while the Power Saver profile is active
    CONFIG_GLOBAL_PROPERTY(bool, pauseGraphInPowerSaver, true)
    CONFIG_GLOBAL_PROPERTY(bool, pauseVisualisersInPowerSaver, true)
    CONFIG_GLOBAL_PROPERTY(QVariantList, thresholds, {})
    CONFIG_GLOBAL_SUBOBJECT(GeneralChargingBehavior, onCharging)
    CONFIG_GLOBAL_SUBOBJECT(GeneralUnpluggedBehavior, onUnplugged)
    CONFIG_GLOBAL_SUBOBJECT(GeneralProfileBehaviors, profileBehaviors)
};

class GeneralBattery : public settings::ObjectNode {
    CONFIG_NODE(GeneralBattery, settings::ObjectNode)

    CONFIG_GLOBAL_PROPERTY(QVariantList, warnLevels,
        DEFAULT_ARG({
            vmap({
                { u"level"_s, 20 },
                { u"title"_s, mark(u"Low battery"_s) },
                { u"message"_s, mark(u"You might want to plug in a charger"_s) },
                { u"icon"_s, u"battery_android_frame_2"_s },
            }),
            vmap({
                { u"level"_s, 10 },
                { u"title"_s, mark(u"Did you see the previous message?"_s) },
                { u"message"_s, mark(u"You should probably plug in a charger <b>now</b>"_s) },
                { u"icon"_s, u"battery_android_frame_1"_s },
            }),
            vmap({
                { u"level"_s, 5 },
                { u"title"_s, mark(u"Critical battery level"_s) },
                { u"message"_s, mark(u"PLUG THE CHARGER RIGHT NOW!!"_s) },
                { u"icon"_s, u"battery_android_alert"_s },
                { u"critical"_s, true },
            }),
        }))
    CONFIG_GLOBAL_PROPERTY(int, criticalLevel, 3)

    CONFIG_GLOBAL_SUBOBJECT(GeneralPowerManagement, powerManagement)
};

class GeneralConfig : public settings::ObjectNode {
    CONFIG_NODE(GeneralConfig, settings::ObjectNode)

    CONFIG_GLOBAL_PROPERTY(QString, logo, QString())
    CONFIG_GLOBAL_PROPERTY(QString, language, QString())
    CONFIG_PROPERTY(bool, showOverFullscreen, false)
    CONFIG_PROPERTY(qreal, mediaGifSpeedAdjustment, 300)
    CONFIG_PROPERTY(qreal, sessionGifSpeed, 0.7)
    CONFIG_SUBOBJECT(GeneralApps, apps)
    CONFIG_SUBOBJECT(GeneralIdle, idle)
    CONFIG_SUBOBJECT(GeneralBattery, battery)
};

} // namespace caelestia::config
