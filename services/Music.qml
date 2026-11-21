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

    // NOTE(fork): Qt's ffmpeg backend only surfaces format-level metadata, and an Ogg/Opus file
    // keeps its tags on the audio stream instead, so an .opus track reported nothing and showed
    // up as its file name with "Unknown artist" (and no lyrics, which are looked up by artist).
    // The taglib scan reads those files fine, so fall back to it for the now-playing fields.
    readonly property var currentTags: root.tags[root.currentFile] ?? ({})

    // Only Ogg containers (Opus/Vorbis) keep their tags on the audio stream where Qt cannot see
    // them, so only those need a taglib read when they load; mp3/m4a/flac/aac sessions never
    // reach the scan below and behave exactly as they did.
    readonly property bool currentNeedsTagScan: /\.(opus|ogg|oga)$/i.test(root.currentFile)

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

    // NOTE(fork): kept true for a while after pausing, so the notch and widgets do not lose
    // what they were showing the moment playback stops - only while a track is still loaded.
    // Cleared early if the queue empties out instead of waiting out the timer.
    property bool wasRecentlyPlaying: false
    readonly property bool recentlyPlaying: root.hasTrack && (root.playing || root.wasRecentlyPlaying)
    // When this last started playing, so the notch can tell whether this or an MPRIS player
    // (Players.rememberedAt) was more recently the one actually making sound
    property real lastPlayedAt: 0

    onPlayingChanged: {
        if (root.playing) {
            root.wasRecentlyPlaying = true;
            root.lastPlayedAt = Date.now();
            memoryTimer.stop();

            // Only one thing should be making sound at a time: starting the local player pauses
            // whatever MPRIS player was playing, the same as pressing pause on it directly
            if (Players.active?.isPlaying && Players.active?.canPause)
                Players.active.pause();
        } else {
            memoryTimer.restart();
        }
    }

    onCurrentChanged: {
        if (root.currentNeedsTagScan && root.currentTags.title === undefined)
            root.ensureTags();
    }

    onHasTrackChanged: {
        if (!root.hasTrack) {
            root.wasRecentlyPlaying = false;
            memoryTimer.stop();
        }
    }

    Timer {
        id: memoryTimer

        interval: 5 * 60 * 1000
        onTriggered: root.wasRecentlyPlaying = false
    }

    readonly property real position: mediaPlayer.position / 1000

    readonly property real duration: mediaPlayer.duration / 1000

    // metaData is read through this property so the bindings below track metaDataChanged
    readonly property var metaData: mediaPlayer.metaData

    readonly property string title: root.metaData?.stringValue(MediaMetaData.Title) || root.currentTags.title || root.fileName

    readonly property string artist: root.metaData?.stringValue(MediaMetaData.ContributingArtist) || root.metaData?.stringValue(MediaMetaData.AlbumArtist) || root.currentTags.artist || ""

    readonly property string album: root.metaData?.stringValue(MediaMetaData.AlbumTitle) || root.currentTags.album || ""

    // Cover art. Art embedded in the track wins, then a well known image next to it. The ffmpeg
    // backend exposes the attached picture as ThumbnailImage and leaves CoverArtImage unset, and
    // hands it over as a QImage, which Image.source cannot take, so it goes through the image
    // cache first and what the UI points at is the path it was written to.
    readonly property string trackDir: root.currentFile ? root.currentFile.slice(0, root.currentFile.lastIndexOf("/")) : ""

    readonly property list<FileSystemEntry> trackImages: trackArt.entries

    // A file's name without its extension. FileSystemEntry.baseName cuts at the first dot, so
    // "Vol. 1 - Song.m4a" and "Vol. 2 - Other.m4a" would both come out as "Vol", and art named
    // after one track would be matched to the other.
    function stemOf(name: string): string {
        const dot = name.lastIndexOf(".");
        return dot > 0 ? name.slice(0, dot) : name;
    }

    readonly property string folderCover: {
        const preferred = ["cover", "folder", "front", "album", "albumart", "artwork"];
        const images = root.trackImages;
        for (let i = 0; i < preferred.length; i++)
            for (let j = 0; j < images.length; j++)
                if (root.stemOf(images[j].name).toLowerCase() === preferred[i])
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
        const stem = root.stemOf(root.fileName);
        if (!stem)
            return "";

        const images = root.trackImages;
        let best = "";
        let bestSize = -1;
        for (let i = 0; i < images.length; i++) {
            // Both the original yt-dlp saved and the converted one can be there; take the larger
            if (root.stemOf(images[i].name) !== stem || images[i].size <= bestSize)
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
            const key = `${images[i].parentDir}/${root.stemOf(images[i].name)}`;
            if (!(key in index))
                index[key] = images[i].path;
        }
        return index;
    }

    // Images that are not the art of one particular track, by folder. A folder of downloads has
    // one image per song, and taking any of them as "the folder's cover" puts one song's picture
    // on every track that has none of its own.
    readonly property var looseArtByDir: {
        const trackKeys = {};
        const tracks = root.library;
        for (let i = 0; i < tracks.length; i++)
            trackKeys[`${tracks[i].parentDir}/${root.stemOf(tracks[i].name)}`] = true;

        const index = {};
        const images = root.artEntries;
        for (let i = 0; i < images.length; i++) {
            if (`${images[i].parentDir}/${root.stemOf(images[i].name)}` in trackKeys)
                continue;
            const dir = images[i].parentDir;
            if (!(dir in index))
                index[dir] = [];
            index[dir].push(images[i]);
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
    // next to a track and wins over the folder's own cover, matching the now playing view. The
    // folder's own cover is an image with a cover-like name, or failing that one that does not
    // belong to a track.
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
        for (let i = 0; i < images.length; i++) {
            const rank = preferred.indexOf(root.stemOf(images[i].name).toLowerCase());
            if (rank >= 0 && rank < bestRank) {
                bestRank = rank;
                best = images[i].path;
            }
        }
        return best || (root.looseArtByDir[dir]?.[0]?.path ?? "");
    }

    // What a folder tile shows: the folder's own image if it has one, otherwise the first few
    // tracks anywhere under it, each with the art that sits beside it (the tile asks for the
    // art inside the file itself, see MusicCovers). Kept per folder for as long as the library
    // and its art are unchanged.
    function previewFor(dir: string): var {
        const key = `dir:${dir}`;
        let preview = root.rowFacts[key];
        if (preview !== undefined)
            return preview;

        const tracks = [];
        const prefix = `${dir}/`;
        const entries = root.library;
        for (let i = 0; i < entries.length && tracks.length < 4; i++) {
            if (!entries[i].path.startsWith(prefix))
                continue;
            tracks.push({
                path: entries[i].path,
                fallback: root.artByTrack[`${entries[i].parentDir}/${root.stemOf(entries[i].name)}`] ?? ""
            });
        }

        preview = {
            cover: root.coverFor(dir, ""),
            tracks: tracks
        };
        root.rowFacts[key] = preview;
        return preview;
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
            title: MusicTags.titleOf(path) || root.stemOf(entry.name),
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

    // The art that sits beside a track on disk: an image named after it, then its folder's
    // cover. Art inside the file itself is not here, it has to be read (see MusicCovers), and
    // wins over this wherever it is found.
    function coverForTrack(entry: FileSystemEntry): string {
        return root.coverFor(entry.parentDir, root.stemOf(entry.name));
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
        const entries = paths.map(path => ({
                    path: path,
                    origin: "auto"
                }));

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

    // Shuffles the whole library: a song at random to start on, and the rest of the music
    // folder dealt out behind it in a random order. This is what the shuffle button does when
    // there is no context to shuffle - nothing open, nothing playing - so pressing it on an
    // empty player still puts music on rather than doing nothing.
    function shuffleAll(): void {
        const entries = root.library;
        if (entries.length === 0)
            return;

        const paths = [];
        for (let i = 0; i < entries.length; i++)
            paths.push(entries[i].path);

        const at = Math.floor(Math.random() * paths.length);
        root.shuffle = true;
        root.playQueue(paths, at);
    }

    // Adds tracks to the queue without disturbing what is playing, so there is no gap and the
    // current song carries on. They go ahead of the rest of the album or artist they were
    // picked out of but behind anything already added, so hand-picked songs play first, in the
    // order they were picked. Adding to an empty player starts the queue instead of leaving it
    // silent, which is what adding to nothing would otherwise do.
    function enqueue(paths: var): void {
        if (!paths || paths.length === 0)
            return;

        const added = paths.map(path => ({
                    path: path,
                    origin: "user"
                }));
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
