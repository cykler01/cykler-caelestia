pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.Mpris
import Caelestia.I18n
import qs.services

// NOTE(fork): one interface over whatever the dashboard media tab controls, either an
// external MPRIS player or the in-shell local player. Reads fall back to empty values so
// the UI can bind without null checks, and the actions route to the wrapped player.
QtObject {
    id: root

    // Set one of these: an MPRIS player to wrap, or local to wrap the in-shell player
    property MprisPlayer mpris
    property bool local

    readonly property bool available: root.local ? Music.hasTrack : root.mpris !== null
    readonly property bool isPlaying: root.local ? Music.playing : (root.mpris?.isPlaying ?? false)
    readonly property string title: root.local ? (Music.hasTrack ? Music.title : "") : (root.mpris?.trackTitle ?? "")
    readonly property string artist: root.local ? Music.artist : (root.mpris?.trackArtist ?? "")
    readonly property string album: root.local ? Music.album : (root.mpris?.trackAlbum ?? "")
    readonly property string coverSource: root.local ? Music.coverPath : Players.getArtUrl(root.mpris)
    readonly property real length: root.local ? Music.duration : (root.mpris?.length ?? 0)
    readonly property real position: root.local ? Music.position : (root.mpris?.position ?? 0)

    readonly property bool canSeek: root.local ? Music.duration > 0 : (root.mpris?.canSeek ?? false)
    readonly property bool canTogglePlaying: root.local ? Music.hasTrack : (root.mpris?.canTogglePlaying ?? false)
    readonly property bool canGoPrevious: root.local ? Music.hasTrack : (root.mpris?.canGoPrevious ?? false)
    readonly property bool canGoNext: root.local ? Music.hasTrack : (root.mpris?.canGoNext ?? false)

    readonly property bool shuffle: root.local ? Music.shuffle : (root.mpris?.shuffle ?? false)
    readonly property bool shuffleSupported: root.local ? Music.queue.length > 1 : (root.mpris?.shuffleSupported ?? false)
    readonly property bool loopSupported: root.local ? true : (root.mpris?.loopSupported ?? false)
    // Exposed as MprisLoopState for both, so the UI only has one enum to reason about
    readonly property int loopState: {
        if (!root.local)
            return root.mpris?.loopState ?? MprisLoopState.None;
        if (Music.repeatMode === "one")
            return MprisLoopState.Track;
        if (Music.repeatMode === "all")
            return MprisLoopState.Playlist;
        return MprisLoopState.None;
    }

    readonly property bool volumeSupported: root.local
    readonly property real volume: Music.volume

    readonly property string identity: root.local ? Tr.tr("Local player") : Players.getIdentity(root.mpris)

    // MPRIS positions only refresh when asked, so the position timer pokes this
    function refresh(): void {
        if (!root.local)
            root.mpris?.positionChanged();
    }

    function togglePlaying(): void {
        if (root.local)
            Music.togglePlaying();
        else
            root.mpris?.togglePlaying();
    }

    function previous(): void {
        if (root.local)
            Music.previous();
        else
            root.mpris?.previous();
    }

    function next(): void {
        if (root.local)
            Music.next();
        else
            root.mpris?.next();
    }

    function seek(seconds: real): void {
        if (root.local) {
            Music.seek(seconds);
        } else if (root.mpris?.canSeek && root.mpris?.positionSupported) {
            root.mpris.position = seconds;
        }
    }

    function toggleShuffle(): void {
        if (root.local)
            Music.shuffle = !Music.shuffle;
        else if (root.mpris)
            root.mpris.shuffle = !root.mpris.shuffle;
    }

    function cycleLoop(): void {
        if (root.local) {
            Music.cycleRepeat();
            return;
        }

        const state = root.mpris?.loopState;
        if (state === MprisLoopState.None)
            root.mpris.loopState = MprisLoopState.Track;
        else if (state === MprisLoopState.Track)
            root.mpris.loopState = MprisLoopState.Playlist;
        else
            root.mpris.loopState = MprisLoopState.None;
    }

    function setVolume(value: real): void {
        Music.setVolume(value);
    }
}
