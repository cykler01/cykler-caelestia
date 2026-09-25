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

    // Artist/title/album, read out of the files themselves by taglib through MusicTags. Only
    // read when something asks for them - the search and the artist shown beside a track - so a
    // session that never opens the library never pays for the scan.
    readonly property var tags: MusicTags.tags
    readonly property bool tagsScanning: MusicTags.scanning
    property bool tagsWanted

    // Whether anything needs the music folder scanned: the library being opened, or something loaded in the
    // player (its queue shows covers from the folder indexes). Until then nothing is scanned or watched, so a
    // session that never plays local music pays nothing for the folder, however big it is.
    readonly property bool scanLibrary: tagsWanted || current !== null || queue.length > 0 || played.length > 0

    // Watched so a change on disk re-reads the tags once something has asked for them
    readonly property int librarySize: root.library.length

    onLibrarySizeChanged: {
        if (root.tagsWanted)
            root.readTags();
    }

    // Shuffling changes the queue itself rather than picking a random song when one ends: what
    // the queue view shows is then what plays, and the order can be read off it. Switching off
    // puts the songs that have not played back in the order they were in, leaving anything added
    // or moved while shuffled (which that order has nothing to say about) where it is.
    onShuffleChanged: {
        if (root.shuffle) {
            root.unshuffledQueue = root.queue.slice();
            root.queue = root.shuffled(root.queue);
            return;
        }

        const saved = root.unshuffledQueue;
        root.unshuffledQueue = [];
        if (saved.length === 0)
            return;

        const current = root.queue;
        const restored = [];
        for (const entry of saved) {
            if (current.indexOf(entry) >= 0)
                restored.push(entry);
        }
        for (const entry of current) {
            if (!restored.includes(entry))
                restored.push(entry);
        }
        root.queue = restored;
    }

    // The folder currently being browsed
    readonly property list<FileSystemEntry> subDirs: browseDirs.entries
    readonly property list<FileSystemEntry> folderTracks: browseTracks.entries
    property string currentDir: rootDir
    readonly property bool atRoot: currentDir === rootDir
    readonly property string relativeDir: root.atRoot || !currentDir.startsWith(rootDir) ? "" : currentDir.slice(rootDir.length + 1)

    // Playback. The queue plays out top to bottom in the queue view: what has already played,
    // the song playing now, the songs picked by hand, then the rest of the album, artist or
    // folder they were picked out of. Every entry is { path, origin } - origin being "user"
    // for something added to the queue by hand and "auto" for the rest of a context - so the
    // two halves of what is still to come can be shown and reordered apart from each other.
    property var played: []
    property var current: null
    property var queue: []
    property bool shuffle: false
    // The order the upcoming queue was in before shuffle was switched on, so switching it off
    // can put it back. Holds the very entries the queue held, so a song that has since been
    // added, moved or played out can be told apart from the ones the saved order knows about.
    property var unshuffledQueue: []
    // "off" | "all" | "one"
    property string repeatMode: "off"
    property real volume: 1

    // How much history is kept, so a queue left running doesn't pile it up forever
    readonly property int playedLimit: 100

    readonly property bool hasTrack: root.current !== null
    readonly property string currentFile: root.current?.path ?? ""
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
    // Where the playhead is in the whole context, counting the history as already played
    readonly property string queueLabel: root.hasTrack ? `${root.played.length + 1}/${root.played.length + 1 + root.queue.length}` : ""

    // Every image under the music folder, so the library gallery can show covers for folders
    // it isn't currently inside of
    readonly property list<FileSystemEntry> artEntries: allArt.entries

    // Those images and the tracks, grouped by the folder they are in, plus the art that sits
    // beside a track (named after it, what yt-dlp leaves behind). The gallery asks for the covers
    // of one entry at a time, so grouping them once here is what keeps a tile to a lookup in its
    // own folder instead of a walk over the whole library: with a few thousand tracks the latter
    // is per tile, and that is what locks the shell up when a big folder is opened. Each index is
    // rebuilt only when a scan changes what is on disk.
    readonly property var artByDir: {
        const index = {};
        const images = root.artEntries;
        for (let i = 0; i < images.length; i++) {
            const dir = images[i].parentDir;
            if (!(dir in index))
                index[dir] = [];
            index[dir].push(images[i]);
        }
        return index;
    }
    readonly property var artByTrack: {
        const index = {};
        const images = root.artEntries;
        for (let i = 0; i < images.length; i++) {
            const key = `${images[i].parentDir}/${images[i].baseName}`;
            if (!(key in index))
                index[key] = images[i].path;
        }
        return index;
    }
    readonly property var tracksByDir: {
        const index = {};
        const tracks = root.library;
        for (let i = 0; i < tracks.length; i++) {
            const dir = tracks[i].parentDir;
            if (!(dir in index))
                index[dir] = [];
            index[dir].push(tracks[i]);
        }
        return index;
    }

    // The best cover image inside a folder. A file named after `stem` is the art yt-dlp saved
    // next to a track and wins over the folder's own cover, matching the now playing view.
    function coverFor(dir: string, stem: string): string {
        if (stem) {
            const art = root.artByTrack[`${dir}/${stem}`];
            if (art)
                return art;
        }

        const preferred = ["cover", "folder", "front", "album", "albumart", "artwork"];
        const images = root.artByDir[dir] ?? [];
        let best = "";
        let bestRank = preferred.length;
        let first = "";
        for (let i = 0; i < images.length; i++) {
            const image = images[i];
            if (!first)
                first = image.path;

            const rank = preferred.indexOf(image.baseName.toLowerCase());
            if (rank >= 0 && rank < bestRank) {
                bestRank = rank;
                best = image.path;
            }
        }
        return best || first;
    }

    // Covers to show on a folder tile: the folder's own cover, else the covers of its first
    // tracks, which the gallery lays out as a collage as soon as there are four of them
    function folderCoversFor(dir: string): var {
        const own = root.coverFor(dir, "");
        if (own)
            return [own];

        const tracks = root.tracksByDir[dir] ?? [];
        const collage = [];
        for (let i = 0; i < tracks.length && collage.length < 4; i++) {
            const art = root.artByTrack[`${dir}/${tracks[i].baseName}`];
            if (art)
                collage.push(art);
        }

        if (collage.length === 0)
            return [];
        return collage.length >= 4 ? collage : collage.slice(0, 1);
    }

    // Every track by path, so a queued track - which is only a path - can be shown with the
    // same title, artist and art a library row would use
    readonly property var entriesByPath: {
        const index = {};
        const entries = root.library;
        for (let i = 0; i < entries.length; i++)
            index[entries[i].path] = entries[i];
        return index;
    }

    function entryFor(path: string): var {
        return root.entriesByPath[path];
    }

    // What a row shows for a track - its title, its artist and its art - kept per path. Every
    // list in the media UI asks for all three of these for every row it builds, and the queue
    // lists are rebuilt whenever the player touches the queue, so looking each one up per row
    // per rebuild is what makes a library of a few thousand tracks crawl: the title and the
    // artist each cross into C++ for the tags, and the art walks the folder indexes. The map is
    // remade - which empties it - only when the tags, the library or the art on disk change,
    // which is the whole of what can change an answer.
    readonly property var rowFacts: {
        root.tags;
        root.library;
        root.artEntries;
        return {};
    }

    function factsFor(entry: FileSystemEntry): var {
        const path = entry.path;
        let facts = root.rowFacts[path];
        if (facts !== undefined)
            return facts;

        facts = {
            title: MusicTags.titleOf(path) || entry.baseName,
            artist: MusicTags.artistOf(path),
            cover: root.coverForTrack(entry)
        };
        root.rowFacts[path] = facts;
        return facts;
    }

    // A track's title, falling back to its file name so a row always has something to show
    function titleFor(entry: FileSystemEntry): string {
        return root.factsFor(entry).title;
    }

    function artistFor(entry: FileSystemEntry): string {
        return root.factsFor(entry).artist;
    }

    function coverForEntry(entry: FileSystemEntry): string {
        return root.factsFor(entry).cover;
    }

    // The one image to show beside a track: the track's own art, then whatever its folder has
    function coverForTrack(entry: FileSystemEntry): string {
        const own = root.coverFor(entry.parentDir, entry.baseName);
        if (own)
            return own;

        const covers = root.folderCoversFor(entry.parentDir);
        return covers.length > 0 ? covers[0] : "";
    }

    // Reads every track's tags. Cheap to call as often as you like: asking for a set of files
    // that has already been read does nothing at all.
    function ensureTags(): void {
        root.tagsWanted = true;
        root.readTags();
    }

    function readTags(): void {
        const paths = [];
        const entries = root.library;
        for (let i = 0; i < entries.length; i++)
            paths.push(entries[i].path);
        MusicTags.scan(paths);
    }

    function playQueue(paths: var, index: int): void {
        if (!paths || paths.length === 0)
            return;

        const at = Math.max(0, Math.min(index, paths.length - 1));
        const entries = paths.map(path => ({ path: path, origin: "auto" }));

        // Shuffling deals the rest of the context out in a random order, which is the order it
        // plays in and the order the queue view shows. Everything the context put before the
        // song picked is dealt out with it rather than counted as played, since under shuffle
        // there is no "before" - the whole context is one pool. The order it would have played
        // in is kept so switching shuffle off can restore it.
        if (root.shuffle) {
            const rest = entries.filter((_, i) => i !== at);
            root.unshuffledQueue = rest.slice();
            root.played = [];
            root.current = entries[at];
            root.queue = root.shuffled(rest);
            root.loadCurrent();
            return;
        }

        // A context replaces whatever came before it, so the history starts again. What the
        // context puts before the chosen song counts as played, so previous() walks back into
        // it the same way it walks back through anything else.
        root.unshuffledQueue = [];
        root.played = entries.slice(0, at);
        root.current = entries[at];
        root.queue = entries.slice(at + 1);
        root.loadCurrent();
    }

    // Adds tracks to the queue without disturbing what is playing, so there is no gap and the
    // current song carries on. They go ahead of the rest of the album or artist they were
    // picked out of but behind anything already added, so hand-picked songs play first, in the
    // order they were picked. Adding to an empty player starts the queue instead of leaving it
    // silent, which is what adding to nothing would otherwise do.
    function enqueue(paths: var): void {
        if (!paths || paths.length === 0)
            return;

        const added = paths.map(path => ({ path: path, origin: "user" }));
        const queued = root.queue;
        let at = 0;
        while (at < queued.length && queued[at].origin === "user")
            at++;

        const merged = queued.slice(0, at).concat(added).concat(queued.slice(at));

        if (!root.hasTrack) {
            root.played = [];
            root.current = merged[0];
            root.queue = merged.slice(1);
            root.loadCurrent();
            return;
        }

        root.queue = merged;
    }

    // Jumps to a place in the queue, for picking a song out of what is still to come rather
    // than waiting for it. Everything ahead of it counts as played, so it can be walked back
    // to afterwards.
    function skipTo(index: int): void {
        if (index < 0 || index >= root.queue.length)
            return;

        root.played = root.trimPlayed(root.played.concat(root.queue.slice(0, index)));
        root.current = root.queue[index];
        root.queue = root.queue.slice(index + 1);
        root.loadCurrent();
    }

    // Moves a queued song up or down the queue. Nothing about what is playing changes, so
    // moving songs around never switches what you are hearing. The queue view only ever asks
    // for a move within one of its sections.
    function moveInQueue(from: int, to: int): void {
        const length = root.queue.length;
        if (from === to || from < 0 || from >= length || to < 0 || to >= length)
            return;

        const next = root.queue.slice();
        const moved = next.splice(from, 1)[0];
        next.splice(to, 0, moved);
        root.queue = next;
    }

    // Takes a song out of what is still to come. Nothing playing changes - the song that is
    // playing is not part of the queue, it is what the queue is waiting behind.
    function removeFromQueue(index: int): void {
        if (index < 0 || index >= root.queue.length)
            return;

        const next = root.queue.slice();
        next.splice(index, 1);
        root.queue = next;
    }

    // Takes a song out of the history, which only tidies the list up
    function removeFromPlayed(index: int): void {
        if (index < 0 || index >= root.played.length)
            return;

        const next = root.played.slice();
        next.splice(index, 1);
        root.played = next;
    }

    // Picking a song out of the history puts the playhead back there. Everything that came
    // after it goes back into the queue, along with the song it interrupts, so the songs that
    // were lined up behind it are still lined up behind it.
    function replayPlayed(index: int): void {
        if (index < 0 || index >= root.played.length)
            return;

        const entry = root.played[index];
        const later = root.played.slice(index + 1);
        const playing = root.current ? [root.current] : [];

        root.played = root.played.slice(0, index);
        root.current = entry;
        root.queue = later.concat(playing).concat(root.queue);
        root.loadCurrent();
    }

    // Keeps the history to its limit, oldest first out
    function trimPlayed(entries: var): var {
        return entries.length > root.playedLimit ? entries.slice(entries.length - root.playedLimit) : entries;
    }

    // The queue in a random order, one song at a time: Fisher-Yates, so every order is equally
    // likely, which a sort with a random comparator would not be
    function shuffled(entries: var): var {
        const out = entries.slice();
        for (let i = out.length - 1; i > 0; i--) {
            const j = Math.floor(Math.random() * (i + 1));
            const tmp = out[i];
            out[i] = out[j];
            out[j] = tmp;
        }
        return out;
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

    // The song that is playing moves into the history and the next one starts. At the end of
    // the queue: playing it all again if the repeat is on, otherwise stopping with nothing
    // playing and everything in the history.
    function next(): void {
        if (!root.hasTrack)
            return;

        const finished = root.trimPlayed(root.played.concat([root.current]));

        if (root.queue.length > 0) {
            // The queue is already in the order shuffle wants it played - it is shuffled when
            // shuffle is switched on, and again when a context is picked under it - so a track
            // finishing just takes the front of it. Shuffle no longer picks at random here, and
            // the queue view and what is heard stay the same list in the same order.
            const queue = root.queue;
            root.played = finished;
            root.current = queue[0];
            root.queue = queue.slice(1);
            root.loadCurrent();
            return;
        }

        if (root.repeatMode === "all") {
            // Round again, with the song that just finished at the end of it
            root.played = [];
            root.current = finished[0];
            root.queue = finished.slice(1);
            root.loadCurrent();
            return;
        }

        root.played = finished;
        root.current = null;
        mediaPlayer.stop();
        mediaPlayer.position = 0;
    }

    // Back one song: the last thing in the history becomes what is playing, and the song it
    // interrupts goes back to the front of the queue so next() returns to it.
    function previous(): void {
        // Restart the track unless we're near its very beginning. With nothing playing - the
        // end of the queue arrived at with the repeat off - this is what picks the last song in
        // the history back up.
        if (root.hasTrack && mediaPlayer.position > 3000) {
            mediaPlayer.position = 0;
            return;
        }

        if (root.played.length === 0) {
            if (root.hasTrack && root.repeatMode === "all" && root.queue.length > 0) {
                // Wrap round to the end of what is still queued
                const last = root.queue[root.queue.length - 1];
                root.queue = [root.current].concat(root.queue.slice(0, -1));
                root.current = last;
                root.loadCurrent();
                return;
            }

            if (root.hasTrack)
                mediaPlayer.position = 0;
            return;
        }

        const back = root.played[root.played.length - 1];
        root.played = root.played.slice(0, -1);
        // What is playing goes back to the front of the queue, so next() returns to it
        if (root.current)
            root.queue = [root.current].concat(root.queue);
        root.current = back;
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

        path: root.scanLibrary ? root.rootDir : ""
        recursive: true
        watchChanges: root.scanLibrary
        filter: FileSystemModel.Files
        nameFilters: root.audioFilters
    }

    FileSystemModel {
        id: browseDirs

        path: root.scanLibrary ? root.currentDir : ""
        recursive: false
        watchChanges: root.scanLibrary
        filter: FileSystemModel.Dirs
    }

    FileSystemModel {
        id: browseTracks

        path: root.scanLibrary ? root.currentDir : ""
        recursive: false
        watchChanges: root.scanLibrary
        filter: FileSystemModel.Files
        nameFilters: root.audioFilters
    }

    FileSystemModel {
        id: trackArt

        path: root.trackDir || (root.scanLibrary ? root.rootDir : "")
        recursive: false
        filter: FileSystemModel.Images
    }

    FileSystemModel {
        id: allArt

        path: root.scanLibrary ? root.rootDir : ""
        recursive: true
        watchChanges: root.scanLibrary
        filter: FileSystemModel.Images
    }
}
