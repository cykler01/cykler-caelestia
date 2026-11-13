pragma Singleton

import QtQml
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Caelestia
import Caelestia.Config
import qs.components.misc

Singleton {
    id: root

    readonly property list<MprisPlayer> list: Mpris.players.values

    // Some players stay registered with nothing loaded at all, or with the placeholders below where
    // a field should be. Neither is a track, so they are not counted as media anywhere (the notch,
    // the media tab and the widgets otherwise showed them as "Unknown title"/"Unknown artist" with
    // a 0:00 out of 0:00 bar).
    readonly property list<string> metaPlaceholders: ["unknown", "unknown title", "unknown artist", "unknown album", "unknown track", "untitled", "no title"]

    // Only the players with something to show, both for picking what is displayed and for the
    // selector that offers what can be picked
    readonly property list<MprisPlayer> mediaPlayers: list.filter(p => root.hasMedia(p))

    // A player that is actually playing beats the default/first one when nothing was picked by hand.
    // The pick is filtered too: a player that starts playing with nothing loaded is still not media
    readonly property MprisPlayer active: (root.hasMedia(props.manualActive) ? props.manualActive : null) ?? mediaPlayers.find(p => p.isPlaying) ?? mediaPlayers.find(p => getIdentity(p) === GlobalConfig.services.defaultPlayer) ?? mediaPlayers[0] ?? null
    property alias manualActive: props.manualActive

    // Dedup key for progressive metadata (e.g. mpv-mpris/yt-dlp player fills title then artist later).
    property string lastTrackKey: ""

    // Fired once per unique track (deduped per track below), e.g. the notch
    // uses this to trigger its own transient display of what's playing.
    signal trackChanged(title: string, artist: string)

    // Fired when the active player was switched automatically to whatever started playing, so that
    // views which can also show the in-shell player know to come back to the MPRIS one
    signal autoSwitched(player: MprisPlayer)

    // Follows the audio: a player that starts playing becomes the active one, and if the active one
    // stops while another is still playing, that one takes over. Picking a player by hand still works,
    // it just stays until something else starts playing.
    // The player picked by hand in the media selector. While it is playing nothing else takes over from it.
    property MprisPlayer pinned

    // NOTE(fork): the last player that was actually playing, kept for a while after it pauses so
    // the notch and widgets do not lose what they were showing the moment playback stops - only
    // while the app behind it is still open. A real playing player always wins over this.
    property MprisPlayer rememberedPlayer: null
    readonly property MprisPlayer recentPlayer: mediaPlayers.find(p => p.isPlaying) ?? (root.hasMedia(root.rememberedPlayer) ? root.rememberedPlayer : null) ?? root.active
    // When the remembered player last started playing, so the notch can tell whether this or
    // the local player (Music.lastPlayedAt) was more recently the one actually making sound
    property real rememberedAt: 0

    // Whether a metadata field says anything, rather than being empty or one of the placeholders
    // some players report in its place
    function hasMeta(value: string): bool {
        const text = (value ?? "").trim().toLowerCase();
        return text !== "" && !root.metaPlaceholders.includes(text);
    }

    // A player with neither a title nor an artist has no track to show, however it is playing -
    // without this it turned up as "Unknown title"/"Unknown artist" and a 0:00 out of 0:00 bar
    function hasMedia(player: MprisPlayer): bool {
        if (!player)
            return false;
        return root.hasMeta(player.trackTitle) || root.hasMeta(player.trackArtist);
    }

    function markPlaying(player: MprisPlayer): void {
        root.rememberedPlayer = player;
        root.rememberedAt = Date.now();
        rememberTimer.stop();
    }

    function markStopped(player: MprisPlayer): void {
        if (root.rememberedPlayer === player)
            rememberTimer.restart();
    }

    // The remembered player's own app closing (it drops out of Mpris.players) clears it early
    // rather than waiting out the timer for a player that is no longer there to resume
    onListChanged: {
        if (root.rememberedPlayer && !list.includes(root.rememberedPlayer)) {
            root.rememberedPlayer = null;
            rememberTimer.stop();
        }
    }

    Timer {
        id: rememberTimer

        interval: 5 * 60 * 1000
        onTriggered: root.rememberedPlayer = null
    }

    function pick(player: MprisPlayer): void {
        pinned = player;
        props.manualActive = player;
    }

    function followPlayback(player: MprisPlayer): void {
        if (!player)
            return;

        if (pinned && pinned !== player && pinned.isPlaying)
            return;
        if (pinned === player && !player.isPlaying)
            pinned = null;

        if (player.isPlaying) {
            if (root.active !== player || props.manualActive !== player) {
                props.manualActive = player;
                root.autoSwitched(player);
            }
        } else if (player === root.active) {
            const other = list.find(p => p !== player && p.isPlaying);
            if (other) {
                props.manualActive = other;
                root.autoSwitched(other);
            }
        }
    }

    function getIdentity(player: MprisPlayer): string {
        if (!player)
            return "";
        const alias = GlobalConfig.services.playerAliases.values.find(a => a.from === player.identity);
        return alias?.to ?? player.identity;
    }

    function getArtUrl(player: MprisPlayer): string {
        if (!player)
            return "";
        if (player.trackArtUrl)
            return player.trackArtUrl;

        const url = player.metadata["xesam:url"] ?? "";
        if (url.startsWith("https://www.youtube.com/watch")) {
            // Fallback for youtube
            const id = url.match(/[?&]v=([\w-]{11})/)?.[1];
            return id ? `https://img.youtube.com/vi/${id}/hqdefault.jpg` : "";
        }
        return "";
    }

    // Quickshell only emits postTrackChanged when trackid/url/title change, so late
    // artist updates (common with mpv-mpris + yt-dlp player) never retrigger it. Watch
    // title/artist too and fire trackChanged once both are usable, deduped per track.
    function maybeNotifyTrackChanged(): void {
        const player = root.active;
        if (!player)
            return;

        const title = player.trackTitle ?? "";
        const artist = player.trackArtist ?? "";
        if (!title || !artist)
            return;

        const key = `${getIdentity(player)}\0${player.uniqueId}\0${title}\0${artist}`;
        if (key === lastTrackKey)
            return;

        lastTrackKey = key;
        root.trackChanged(title, artist);
    }

    onActiveChanged: lastTrackKey = ""

    Connections {
        function onPostTrackChanged(): void {
            root.maybeNotifyTrackChanged();
        }

        function onTrackTitleChanged(): void {
            root.maybeNotifyTrackChanged();
        }

        function onTrackArtistChanged(): void {
            root.maybeNotifyTrackChanged();
        }

        target: root.active
    }

    Instantiator {
        model: root.list

        Connections {
            required property MprisPlayer modelData

            function onIsPlayingChanged(): void {
                root.followPlayback(target);
                if (target.isPlaying)
                    root.markPlaying(target);
                else
                    root.markStopped(target);
            }

            target: modelData
        }
    }

    PersistentProperties {
        id: props

        property MprisPlayer manualActive

        reloadableId: "players"
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "mediaToggle"
        description: "Toggle media playback"
        onPressed: {
            // Only one thing should be making sound at a time, same rule the notch uses to pick
            // what it shows: whichever side is actually playing right now wins outright, and if
            // neither is, whichever paused most recently is what this resumes.
            const active = root.active;
            if (Music.playing) {
                Music.togglePlaying();
            } else if (active?.isPlaying) {
                if (active.canTogglePlaying)
                    active.togglePlaying();
            } else if (Music.recentlyPlaying && (!root.recentPlayer || Music.lastPlayedAt >= root.rememberedAt)) {
                Music.togglePlaying();
            } else if (active && active.canTogglePlaying) {
                active.togglePlaying();
            }
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "mediaPrev"
        description: "Previous track"
        onPressed: {
            const active = root.active;
            if (active && active.canGoPrevious)
                active.previous();
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "mediaNext"
        description: "Next track"
        onPressed: {
            const active = root.active;
            if (active && active.canGoNext)
                active.next();
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "mediaStop"
        description: "Stop media playback"
        onPressed: root.active?.stop()
    }

    IpcHandler {
        function getActive(prop: string): string {
            const active = root.active;
            return active ? active[prop] ?? "Invalid property" : "No active player";
        }

        function list(): string {
            return root.list.map(p => root.getIdentity(p)).join("\n");
        }

        function play(): void {
            const active = root.active;
            if (active?.canPlay)
                active.play();
        }

        function pause(): void {
            const active = root.active;
            if (active?.canPause)
                active.pause();
        }

        function playPause(): void {
            const active = root.active;
            if (active?.canTogglePlaying)
                active.togglePlaying();
        }

        function previous(): void {
            const active = root.active;
            if (active?.canGoPrevious)
                active.previous();
        }

        function next(): void {
            const active = root.active;
            if (active?.canGoNext)
                active.next();
        }

        function stop(): void {
            root.active?.stop();
        }

        target: "mpris"
    }
}
