#pragma once

#include <qstring.h>
#include <qvariantlist.h>

#include "settings/objectnode.hpp"
#include "common.hpp"
#include "enums.hpp"

namespace caelestia::config {

using Qt::StringLiterals::operator""_s;
using settings::vmap;

class PlayerAlias : public settings::ObjectNode {
    CONFIG_NODE(PlayerAlias, settings::ObjectNode)

    CONFIG_PROPERTY(QString, from, {})
    CONFIG_PROPERTY(QString, to, {})
};
CONFIG_LIST_TYPE(PlayerAlias, PlayerAliasList)

// NOTE(fork): Discord rich presence for the in-shell local player. Enabled by default and
// ready to go out of the box - a client ID is just a public app identifier, not a secret, so
// the fork's own application is baked in as the default. It can be overridden with a personal
// application for a different name/art in the settings.
class DiscordConfig : public settings::ObjectNode {
    CONFIG_NODE(DiscordConfig, settings::ObjectNode)

    CONFIG_GLOBAL_PROPERTY(bool, enabled, true)
    // The fork's Discord application, used unless overridden
    CONFIG_GLOBAL_PROPERTY(QString, clientId, u"1554932189844480091"_s)
    // The two lines of the activity. {title}, {artist}, {album} and {file} are substituted;
    // the song shows as the headline and the artist below it unless these are changed.
    CONFIG_GLOBAL_PROPERTY(QString, titleFormat, u"{title}"_s)
    CONFIG_GLOBAL_PROPERTY(QString, descFormat, u"{artist}"_s)
    // Discord cannot show a local file, so the cover is looked up online by artist/album
    CONFIG_GLOBAL_PROPERTY(bool, showCover, true)
    CONFIG_GLOBAL_PROPERTY(bool, showElapsed, true)
    // Which activity type Discord labels it with, using Discord's own numbering: 0 = playing,
    // 1 = streaming, 2 = listening, 3 = watching, 5 = competing. Listening by default so the
    // card reads "Listening to" rather than "Playing". 4 is the app-only custom status and
    // has no meaning here. Types a client does not honour fall back to playing.
    CONFIG_GLOBAL_PROPERTY(int, activityType, 2)
    // Which activity field Discord uses as the status text in member lists, the same
    // switch Music Presence and the like expose: 0 = the app name ("caelestia"), 1 = the
    // artist line, 2 = the song line. Details is the default so the song shows, like
    // YouTube Music does.
    CONFIG_GLOBAL_PROPERTY(int, statusDisplay, 2)
};

// System sound effects, played through the system's XDG sound theme
class SoundEffectsConfig : public settings::ObjectNode {
    CONFIG_NODE(SoundEffectsConfig, settings::ObjectNode)

    CONFIG_GLOBAL_PROPERTY(bool, enabled, false)
    CONFIG_GLOBAL_PROPERTY(qreal, sfxVolume, 0.9)
    CONFIG_GLOBAL_PROPERTY(qreal, notificationVolume, 0.5)
    CONFIG_GLOBAL_PROPERTY(bool, cameraClick, true)
    CONFIG_GLOBAL_PROPERTY(bool, chargingStarted, true)
    CONFIG_GLOBAL_PROPERTY(bool, volumeTick, true)
    CONFIG_GLOBAL_PROPERTY(bool, screenLock, true)
    CONFIG_GLOBAL_PROPERTY(bool, screenUnlock, true)
    CONFIG_GLOBAL_PROPERTY(bool, lowBattery, true)
    CONFIG_GLOBAL_PROPERTY(bool, screenRecord, true)
};

class ServiceConfig : public settings::ObjectNode {
    CONFIG_NODE(ServiceConfig, settings::ObjectNode)

    // Where the shell's git checkout lives, for the Update page (empty: ~/Documents/Github/cykler-caelestia)
    CONFIG_GLOBAL_PROPERTY(QString, repoPath, {})
    // Branch the Update page tracks
    CONFIG_GLOBAL_PROPERTY(QString, updateBranch, u"main"_s)
    CONFIG_GLOBAL_PROPERTY(QString, weatherLocation, {})
    // Auto guesses based on locale
    CONFIG_GLOBAL_ENUM_PROPERTY(TemperatureUnit, weatherUnits, TemperatureUnit::Auto)
    // Always Celsius by default cause apparently even imperial system users don't use Fahrenheit for perf temps?
    CONFIG_GLOBAL_ENUM_PROPERTY(TemperatureUnit, sensorUnits, TemperatureUnit::Celsius)
    // Binary (KiB/MiB/GiB) or decimal (KB/MB/GB) data sizes
    CONFIG_GLOBAL_ENUM_PROPERTY(DataUnit, dataUnits, DataUnit::Binary)
    CONFIG_GLOBAL_ENUM_PROPERTY(ClockFormat, clockFormat, ClockFormat::Auto)
    CONFIG_GLOBAL_ENUM_PROPERTY(GpuType, gpuType, GpuType::Auto)
    CONFIG_GLOBAL_PROPERTY(int, visualiserBars, 60)
    CONFIG_GLOBAL_PROPERTY(qreal, audioIncrement, 0.1)
    CONFIG_GLOBAL_PROPERTY(qreal, brightnessIncrement, 0.1)
    CONFIG_GLOBAL_PROPERTY(qreal, maxVolume, 1.0)
    // NOTE(fork): the system-wide equalizer is opt-in and off by default. It routes every stream
    // through a PipeWire filter chain, so leaving it enabled by default would change the audio
    // setup of anyone who merely updates the shell
    CONFIG_GLOBAL_PROPERTY(bool, equalizer, false)
    CONFIG_GLOBAL_PROPERTY(bool, smartScheme, true)
    CONFIG_GLOBAL_PROPERTY(QString, defaultPlayer, u"Spotify"_s)
    CONFIG_GLOBAL_LIST(PlayerAliasList, playerAliases,
        DEFAULT_ARG({
            vmap({ { u"from"_s, u"com.github.th_ch.youtube_music"_s }, { u"to"_s, u"YT Music"_s } }),
        }))
    CONFIG_GLOBAL_ENUM_PROPERTY(LyricsBackend, lyricsBackend, LyricsBackend::Auto)
    CONFIG_GLOBAL_SUBOBJECT(DiscordConfig, discord)
    CONFIG_GLOBAL_SUBOBJECT(SoundEffectsConfig, soundEffects)
};

} // namespace caelestia::config
