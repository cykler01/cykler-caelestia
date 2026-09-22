pragma Singleton

import QtQuick
import QtMultimedia
import Quickshell
import Caelestia.Images
import Caelestia.Models
import qs.utils

// NOTE(fork): in-shell local music player. Plays the audio files under the configured music
// folder (paths.musicDir) with a queue, shuffle, repeat and folder/search browsing.
Singleton {
    id: root

    readonly property string rootDir: Paths.musicdir
    // Formats handed to the file models and to the library scan
    readonly property list<string> audioFilters: ["*.mp3", "*.flac", "*.m4a", "*.aac", "*.ogg", "*.oga", "*.opus", "*.wav", "*.wv", "*.aiff", "*.ape", "*.wma"]

    // Every track under the music folder, searched over by the UI
    readonly property list<FileSystemEntry> library: allTracks.entries
    // The folder currently being browsed
    readonly property list<FileSystemEntry> subDirs: browseDirs.entries
    readonly property list<FileSystemEntry> folderTracks: browseTracks.entries
    property string currentDir: rootDir
    readonly property bool atRoot: currentDir === rootDir
    readonly property string relativeDir: root.atRoot || !currentDir.startsWith(rootDir) ? "" : currentDir.slice(rootDir.length + 1)

    // Playback
    property list<string> queue: []
    property int queueIndex: -1
    property bool shuffle: false
    // "off" | "all" | "one"
    property string repeatMode: "off"
    property real volume: 1

    readonly property bool hasTrack: queueIndex >= 0 && queueIndex < queue.length
    readonly property string currentFile: root.hasTrack ? queue[queueIndex] : ""
    readonly property string fileName: root.currentFile.slice(root.currentFile.lastIndexOf("/") + 1)
    readonly property bool playing: mediaPlayer.playbackState === MediaPlayer.PlayingState
    readonly property real position: mediaPlayer.position / 1000
    readonly property real duration: mediaPlayer.duration / 1000

    // metaData is read through this property so the bindings below track metaDataChanged
    readonly property var metaData: mediaPlayer.metaData
    readonly property string title: root.metaData?.stringValue(MediaMetaData.Title) || root.fileName
    readonly property string artist: root.metaData?.stringValue(MediaMetaData.ContributingArtist) || root.metaData?.stringValue(MediaMetaData.AlbumArtist) || ""
    readonly property string album: root.metaData?.stringValue(MediaMetaData.AlbumTitle) || ""

    // Cover art. Art embedded in the track wins, then a well known image next to it. The ffmpeg
    // backend exposes the attached picture as ThumbnailImage and leaves CoverArtImage unset, and
    // hands it over as a QImage, which Image.source cannot take, so it goes through the image
    // cache first and what the UI points at is the path it was written to.
    readonly property string trackDir: root.currentFile ? root.currentFile.slice(0, root.currentFile.lastIndexOf("/")) : ""
    readonly property list<FileSystemEntry> trackImages: trackArt.entries
    readonly property string folderCover: {
        const preferred = ["cover", "folder", "front", "album", "albumart", "artwork"];
        const images = root.trackImages;
        for (let i = 0; i < preferred.length; i++)
            for (let j = 0; j < images.length; j++)
                if (images[j].baseName.toLowerCase() === preferred[i])
                    return images[j].path;
        return "";
    }
    readonly property string embeddedCover: {
        const art = root.metaData?.value(MediaMetaData.ThumbnailImage);
        return art ? IUtils.saveImageToCache(art) : "";
    }
    // yt-dlp leaves the downloaded thumbnail beside the track, because opus cannot hold one
    // (its container has no attached picture support, so --embed-thumbnail only converts it)
    readonly property string sidecarCover: {
        const dot = root.fileName.lastIndexOf(".");
        const stem = dot > 0 ? root.fileName.slice(0, dot) : root.fileName;
        if (!stem)
            return "";

        const images = root.trackImages;
        let best = "";
        let bestSize = -1;
        for (let i = 0; i < images.length; i++) {
            // Both the original yt-dlp saved and the converted one can be there; take the larger
            if (images[i].baseName !== stem || images[i].size <= bestSize)
                continue;
            best = images[i].path;
            bestSize = images[i].size;
        }
        return best;
    }
    readonly property string coverPath: root.embeddedCover || root.sidecarCover || root.folderCover
    readonly property string queueLabel: root.hasTrack ? `${root.queueIndex + 1}/${root.queue.length}` : ""

    function playQueue(paths: var, index: int): void {
        if (!paths || paths.length === 0)
            return;

        root.queue = paths;
        root.queueIndex = Math.max(0, Math.min(index, paths.length - 1));
        root.loadCurrent();
    }

    function loadCurrent(): void {
        if (!root.hasTrack)
            return;

        mediaPlayer.source = Qt.resolvedUrl(root.currentFile);
        mediaPlayer.play();
    }

    function togglePlaying(): void {
        if (!root.hasTrack)
            return;

        if (root.playing)
            mediaPlayer.pause();
        else
            mediaPlayer.play();
    }

    function next(): void {
        if (!root.hasTrack)
            return;

        if (root.shuffle && root.queue.length > 1) {
            root.queueIndex = root.randomIndex();
        } else if (root.queueIndex < root.queue.length - 1) {
            root.queueIndex++;
        } else if (root.repeatMode === "all") {
            root.queueIndex = 0;
        } else {
            mediaPlayer.stop();
            mediaPlayer.position = 0;
            return;
        }

        root.loadCurrent();
    }

    function previous(): void {
        if (!root.hasTrack)
            return;

        // Restart the track unless we're near its very beginning
        if (mediaPlayer.position > 3000) {
            mediaPlayer.position = 0;
            return;
        }

        if (root.shuffle && root.queue.length > 1) {
            root.queueIndex = root.randomIndex();
        } else if (root.queueIndex > 0) {
            root.queueIndex--;
        } else if (root.repeatMode === "all") {
            root.queueIndex = root.queue.length - 1;
        } else {
            mediaPlayer.position = 0;
            return;
        }

        root.loadCurrent();
    }

    function seek(seconds: real): void {
        mediaPlayer.position = Math.round(seconds * 1000);
    }

    function setVolume(value: real): void {
        root.volume = Math.max(0, Math.min(1, value));
    }

    function cycleRepeat(): void {
        root.repeatMode = root.repeatMode === "off" ? "all" : root.repeatMode === "all" ? "one" : "off";
    }

    function randomIndex(): int {
        if (root.queue.length <= 1)
            return root.queueIndex;

        let index = root.queueIndex;
        while (index === root.queueIndex)
            index = Math.floor(Math.random() * root.queue.length);
        return index;
    }

    function cd(dir: string): void {
        root.currentDir = dir;
    }

    function cdUp(): void {
        if (root.atRoot)
            return;

        const parent = root.currentDir.slice(0, root.currentDir.lastIndexOf("/"));
        root.currentDir = parent.startsWith(root.rootDir) ? parent : root.rootDir;
    }

    function cdRoot(): void {
        root.currentDir = root.rootDir;
    }

    MediaPlayer {
        id: mediaPlayer

        // Repeat one loops natively, so only the end of the queue reaches next()
        loops: root.repeatMode === "one" ? MediaPlayer.Infinite : 1
        audioOutput: AudioOutput {
            id: audioOutput

            volume: root.volume
        }

        onMediaStatusChanged: {
            if (mediaStatus === MediaPlayer.EndOfMedia)
                root.next();
        }
    }

    FileSystemModel {
        id: allTracks

        path: root.rootDir
        recursive: true
        watchChanges: true
        filter: FileSystemModel.Files
        nameFilters: root.audioFilters
    }

    FileSystemModel {
        id: browseDirs

        path: root.currentDir
        recursive: false
        watchChanges: true
        filter: FileSystemModel.Dirs
    }

    FileSystemModel {
        id: browseTracks

        path: root.currentDir
        recursive: false
        watchChanges: true
        filter: FileSystemModel.Files
        nameFilters: root.audioFilters
    }

    FileSystemModel {
        id: trackArt

        path: root.trackDir || root.rootDir
        recursive: false
        filter: FileSystemModel.Images
    }
}
