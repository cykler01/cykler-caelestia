pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import Caelestia.Models
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services

// NOTE(fork): the media library. Browsing lists the folders under the music folder, one row
// per folder or track, and every row carries that entry's cover art beside the name. Searching
// reads titles, artists and albums over the whole library as well as paths, so an artist brings
// up everything by them. Lists rather than a cover gallery, since what this mostly gets opened
// in is the sidebar.
//
// Selecting turns taps on tracks into a selection that can be added to the queue in one go,
// and it survives opening a folder or searching, so a batch can be gathered up from several
// places before it is queued.
//
// The queue button in the header swaps the whole pane over to what has been queued, in the
// order it will play, where songs can be moved around and taken back out.
StyledClippingRect {
    id: root

    // Showing the queue rather than the library
    property bool onQueue

    readonly property string query: search.text.trim().toLowerCase()
    readonly property bool searching: root.query.length > 0

    // The selection, kept as paths in the order they were picked so the queue plays back in
    // the order they were chosen, and by path rather than list position so opening a folder or
    // typing a search doesn't throw it away
    property bool selecting
    property var selected: []
    readonly property var selectedLookup: {
        const lookup = {};
        for (const path of root.selected)
            lookup[path] = true;
        return lookup;
    }
    readonly property int selectedCount: root.selected.length
    // The tracks the list is showing, so "select all" means everything on screen
    readonly property var listedTracks: root.items.filter(item => item.kind === "track")
    readonly property bool allListedSelected: root.listedTracks.length > 0 && root.listedTracks.every(item => root.selectedLookup[item.path] === true)

    readonly property bool atRoot: Music.atRoot
    readonly property string title: {
        if (root.onQueue)
            return Tr.tr("Queue");
        if (root.searching)
            return Tr.tr("Search results");
        return Music.relativeDir ? Music.relativeDir.split("/").join(" › ") : Tr.tr("Music");
    }
    readonly property string emptyIcon: {
        if (root.onQueue)
            return "queue_music";
        if (root.searching)
            return "search_off";
        return "music_off";
    }
    readonly property string emptyText: {
        if (root.onQueue)
            return Tr.tr("Nothing queued");
        if (root.searching)
            return Tr.tr("No matches");
        return Tr.tr("No music here");
    }
    // Rows whichever list is showing, so the empty state covers both of them
    readonly property int visibleRows: root.onQueue ? queue.rows.length : list.count

    // What the list is showing, one plain object per row so the row doesn't have to care
    // whether it is looking at a folder or a track. The tags are only touched when a search
    // needs them, so a library list is not rebuilt every time the tag scan lands.
    readonly property var items: {
        if (root.searching)
            return root.searchItems();

        const rows = [];
        const dirs = Music.subDirs;
        for (let i = 0; i < dirs.length; i++)
            rows.push(root.folderRow(dirs[i]));
        const tracks = Music.folderTracks;
        for (let i = 0; i < tracks.length; i++)
            rows.push(root.trackRow(tracks[i]));
        return rows;
    }

    signal trackPlayed

    // The tags are only read once something opens the library, so a session that never does
    // pays nothing for them
    Component.onCompleted: Music.ensureTags()

    onVisibleChanged: {
        // The sidebar unmaps this as it closes, which drops the search field's focus, so it
        // is taken back when the library comes round again
        if (root.visible)
            search.forceActiveFocus();
    }

    function countLabel(count: int): string {
        return Tr.trN("%1 track", "%1 tracks", count).arg(count);
    }

    // Path of an entry relative to the music folder, for telling search results apart
    function relativeDirOf(entry: FileSystemEntry): string {
        const dir = entry.parentDir;
        if (!dir.startsWith(Music.rootDir))
            return dir;
        return dir.slice(Music.rootDir.length).replace(/^\//, "");
    }

    function trackRow(entry: FileSystemEntry): var {
        return {
            kind: "track",
            name: Music.titleFor(entry),
            // Where a result lives, when it has no artist to show instead
            subtitle: Music.artistFor(entry) || (root.searching ? root.relativeDirOf(entry) : ""),
            cover: Music.coverForEntry(entry),
            path: entry.path,
            entry: entry
        };
    }

    function folderRow(entry: FileSystemEntry): var {
        return {
            kind: "folder",
            name: entry.name,
            subtitle: root.countLabel(Music.tracksByDir[entry.path]?.length ?? 0),
            cover: Music.folderCoversFor(entry.path)[0] ?? "",
            entry: entry
        };
    }

    // Searched over the path, so an album or folder name finds its tracks, and over the tags,
    // so an artist brings up their songs
    function matches(entry: FileSystemEntry, tag: var): bool {
        if (entry.relativePath.toLowerCase().includes(root.query))
            return true;
        if (tag === undefined)
            return false;

        return (tag.title ?? "").toLowerCase().includes(root.query) || (tag.artist ?? "").toLowerCase().includes(root.query) || (tag.album ?? "").toLowerCase().includes(root.query);
    }

    function searchItems(): var {
        const results = [];
        const tags = Music.tags;
        const library = Music.library;
        for (let i = 0; i < library.length; i++) {
            if (root.matches(library[i], tags[library[i].path]))
                results.push(root.trackRow(library[i]));
        }
        return results;
    }

    function isSelected(item: var): bool {
        return item.kind === "track" && root.selectedLookup[item.path] === true;
    }

    function toggleSelection(item: var): void {
        if (root.isSelected(item)) {
            const keep = [];
            for (const path of root.selected)
                if (path !== item.path)
                    keep.push(path);
            root.selected = keep;
            return;
        }

        root.selected = root.selected.concat([item.path]);
    }

    // Takes everything on screen, or gives it back once it is all selected - the usual
    // select all toggle
    function toggleSelectAll(): void {
        const listed = root.listedTracks;
        if (root.allListedSelected) {
            const listedPaths = listed.map(item => item.path);
            root.selected = root.selected.filter(path => !listedPaths.includes(path));
            return;
        }

        const next = root.selected.slice();
        for (const item of listed)
            if (!next.includes(item.path))
                next.push(item.path);
        root.selected = next;
    }

    // Queues the selection in the order it was picked, and leaves selection mode so the queue
    // is what the controls are on next. Adding says nothing on the screen: the queue button in
    // the header fills up, and that is the whole of the feedback.
    function addToQueue(): void {
        const paths = root.selected.slice();
        if (paths.length === 0)
            return;

        Music.enqueue(paths);
        root.selecting = false;
    }

    onSelectingChanged: {
        // Leaving the mode drops the selection, so coming back to it starts clean
        if (!root.selecting)
            root.selected = [];
    }

    function stopSearching(): void {
        search.text = "";
    }

    // Going up leaves a search behind rather than navigating under it, so the list you land
    // back on is the one you were looking at
    function goUp(): void {
        root.stopSearching();
        Music.cdUp();
    }

    function goRoot(): void {
        root.stopSearching();
        Music.cdRoot();
    }

    function activate(item: var): void {
        if (item.kind === "folder") {
            root.stopSearching();
            Music.cd(item.entry.path);
            return;
        }

        // A track plays, or is collected up while selecting. Folders still open either way,
        // so a selection can be carried into them.
        if (root.selecting) {
            root.toggleSelection(item);
            return;
        }

        root.playItem(item);
    }

    // Playing a track queues whatever else is on the list behind it, so a folder plays through
    // instead of stopping after one song
    function playItem(item: var): void {
        if (item.kind !== "track")
            return;

        const rows = root.items;
        const paths = [];
        let index = -1;
        for (let i = 0; i < rows.length; i++) {
            if (rows[i].kind !== "track")
                continue;
            if (rows[i].path === item.path)
                index = paths.length;
            paths.push(rows[i].path);
        }

        if (index < 0)
            return;

        Music.playQueue(paths, index);
        root.trackPlayed();
    }

    // The second button on a row: this one track goes into the queue behind whatever is
    // playing, and playback carries on undisturbed
    function enqueueItem(item: var): void {
        if (item.kind !== "track")
            return;

        Music.enqueue([item.path]);
    }

    // The queue is a plain list, so leaving a selection behind while it is up would only make
    // it come back unexplained
    onOnQueueChanged: root.selecting = false

    clip: true
    color: Colours.tPalette.m3surfaceContainer
    radius: Tokens.rounding.large

    Item {
        id: body

        anchors.fill: parent
        anchors.margins: Tokens.padding.medium
        visible: root.enabled && height > 0

        RowLayout {
            id: header

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: Tokens.spacing.extraSmall

            // Browsing only - the queue has no folders to climb out of
            IconButton {
                icon: "arrow_upward"
                type: IconButton.Text
                visible: !root.onQueue
                disabled: root.atRoot && !root.searching
                onClicked: root.goUp()
            }

            StyledText {
                Layout.fillWidth: true
                text: root.title
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.medium
                elide: Text.ElideMiddle
            }

            // Multi-select: tracks collect into a selection instead of playing, so a batch can
            // be queued up in one go
            IconButton {
                icon: "checklist"
                isToggle: true
                visible: !root.onQueue
                checked: root.selecting
                type: root.selecting ? IconButton.Filled : IconButton.Tonal
                onClicked: root.selecting = !root.selecting
            }

            IconButton {
                icon: "home"
                type: IconButton.Text
                visible: !root.onQueue
                disabled: root.atRoot && !root.searching
                onClicked: root.goRoot()
            }

            // What has been queued, in the order it will play, where songs can be moved
            // around and taken back out
            IconButton {
                icon: "queue_music"
                isToggle: true
                checked: root.onQueue
                type: root.onQueue ? IconButton.Filled : IconButton.Tonal
                onClicked: root.onQueue = !root.onQueue
            }
        }

        SearchBar {
            id: search

            anchors.top: header.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: Tokens.spacing.small

            // Nothing to search in the queue
            visible: !root.onQueue
            // Takes focus whenever the library does, so the field can be typed into without
            // reaching for it first
            focus: root.enabled && visible
            placeholderText: Tr.tr("Search songs and artists")
            font: Tokens.font.body.small
            topPadding: Tokens.padding.small
            bottomPadding: Tokens.padding.small
        }

        Item {
            id: viewport

            anchors.top: root.onQueue ? header.bottom : search.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: Tokens.spacing.medium
            // Clamped so the list never gets a negative height while a drawer animates, and
            // shorter while the selection bar is under it
            height: Math.max(0, body.height - y - (selectionBar.visible ? selectionBar.height + Tokens.spacing.medium : 0))
            clip: true

            // Only the rows on screen are ever built, so a folder of a few thousand tracks
            // doesn't build a few thousand rows in one go and lock the shell up while it does
            StyledListView {
                id: list

                anchors.fill: parent
                // Gutter for the scrollbar, so the rows don't sit under it
                anchors.rightMargin: Tokens.padding.small
                visible: !root.onQueue
                clip: true
                spacing: Tokens.spacing.extraSmall / 2

                StyledScrollBar.vertical: StyledScrollBar {
                    flickable: list
                }

                model: root.items

                delegate: LibraryRow {
                    required property var modelData

                    width: list.width
                    item: modelData
                    // Followed live rather than baked into the row above, so a song finishing or
                    // playback being paused only revisits the rows on screen instead of making
                    // the whole list again - which, with every row's title, artist and art read
                    // out of the library, is what a folder of a few hundred tracks feels like
                    current: modelData.path === Music.currentFile
                    playing: modelData.path === Music.currentFile && Music.playing
                    selecting: root.selecting
                    selected: root.isSelected(modelData)
                    onClicked: root.activate(modelData)
                    onPlayClicked: root.playItem(modelData)
                    onEnqueueClicked: root.enqueueItem(modelData)
                }
            }

            // The queue, once the header button swaps over to it
            QueueView {
                id: queue

                anchors.fill: parent
                // Same gutter as the library list, so both scroll under the scrollbar
                anchors.rightMargin: Tokens.padding.small
                visible: root.onQueue
            }

            ColumnLayout {
                anchors.centerIn: parent
                spacing: Tokens.spacing.extraSmall
                opacity: root.visibleRows === 0 ? 1 : 0
                visible: opacity > 0

                Behavior on opacity {
                    Anim {
                        type: Anim.DefaultEffects
                    }
                }

                MaterialIcon {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.emptyIcon
                    color: Colours.palette.m3outline
                    fontStyle: Tokens.font.icon.extraLarge
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.emptyText
                    color: Colours.palette.m3outline
                    font: Tokens.font.body.medium
                }
            }
        }

        // What the selection is for. The count comes first, so what has been collected is
        // legible without working out which buttons are on.
        RowLayout {
            id: selectionBar

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            spacing: Tokens.spacing.extraSmall
            visible: root.selecting && !root.onQueue

            StyledText {
                Layout.fillWidth: true
                text: Tr.tr("%1 selected").arg(root.selectedCount)
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.medium
                elide: Text.ElideRight
            }

            IconButton {
                icon: "select_all"
                type: IconButton.Tonal
                isToggle: true
                checked: root.allListedSelected
                disabled: root.listedTracks.length === 0
                onClicked: root.toggleSelectAll()
            }

            IconTextButton {
                icon: "playlist_add"
                text: Tr.tr("Add to queue")
                type: IconTextButton.Filled
                disabled: root.selectedCount === 0
                onClicked: root.addToQueue()
            }

            IconButton {
                icon: "close"
                type: IconButton.Text
                onClicked: root.selecting = false
            }
        }
    }
}
