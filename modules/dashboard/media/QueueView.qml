pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services

// NOTE(fork): the queue as it plays out, top to bottom: what has already played, the song
// playing now, the songs picked by hand, and the rest of the album, artist or folder they were
// picked out of. Playback walks down the list - the song playing now, then the hand-picked
// ones in the order they were added, then the rest of the context - and every song that
// finishes moves up into the history behind the playhead (see Music.next).
//
// Songs in the two upcoming sections are dragged to reorder them, and each section is dragged
// on its own: the hand-picked songs are ahead of the context by definition, so a drag cannot
// move one across into the other. Everything else is a button: the delete on a song row takes
// it out of the queue, or out of the history if it has already played, and a tap plays a song
// straight from wherever it is.
//
// The queue holds paths, so each row's title, artist and art come from the library entry for
// that path, falling back to the file name for anything that has since gone from disk.
StyledListView {
    id: root

    // The song being dragged: its position in its own section, where it would land, and the
    // queue indices of that section in order, so a move can be asked for in queue terms
    property int dragOrdinal: -1
    property int dragToOrdinal: -1
    property string dragSection: ""
    property var dragIndices: []
    readonly property bool reordering: root.dragOrdinal >= 0

    // Every song row is the same height, which is what lets a drag work out how far it has
    // been moved and where it would land
    readonly property int rowHeight: 40 + Tokens.padding.small * 2 + Tokens.spacing.extraSmall / 2

    // The rows of the list: a header, or a song. index is the song's place in the list it
    // belongs to - the history, or the queue - and ordinal its place within its section, which
    // is what a drag moves it around by.
    readonly property var rows: {
        const list = [];
        const played = Music.played;
        const queue = Music.queue;

        if (played.length > 0) {
            list.push({ kind: "header", section: "played", text: Tr.tr("Played"), count: played.length });
            for (let i = 0; i < played.length; i++)
                list.push(root.trackRow(played[i].path, "played", i, i, false));
        }

        if (Music.hasTrack) {
            list.push({ kind: "header", section: "current", text: Tr.tr("Now playing"), count: 1 });
            list.push(root.trackRow(Music.current.path, "current", 0, 0, true));
        }

        // The queue, split by where each song came from
        const user = [];
        const auto = [];
        for (let i = 0; i < queue.length; i++) {
            if (queue[i].origin === "user")
                user.push({ path: queue[i].path, index: i });
            else
                auto.push({ path: queue[i].path, index: i });
        }

        if (user.length > 0) {
            list.push({ kind: "header", section: "user", text: Tr.tr("Your queue"), count: user.length });
            for (let i = 0; i < user.length; i++)
                list.push(root.trackRow(user[i].path, "user", user[i].index, i, false));
        }

        if (auto.length > 0) {
            list.push({ kind: "header", section: "auto", text: Tr.tr("Auto queue"), count: auto.length });
            for (let i = 0; i < auto.length; i++)
                list.push(root.trackRow(auto[i].path, "auto", auto[i].index, i, false));
        }

        return list;
    }

    // The row showing the song that is playing, so the view can keep it in sight
    readonly property int currentRow: root.rows.findIndex(row => row.kind === "track" && row.section === "current")

    function trackRow(path: string, section: string, index: int, ordinal: int, current: bool): var {
        const entry = Music.entryFor(path);
        return {
            kind: "track",
            section: section,
            index: index,
            ordinal: ordinal,
            name: entry ? Music.titleFor(entry) : path.slice(path.lastIndexOf("/") + 1).replace(/\.[^.]+$/, ""),
            subtitle: entry ? Music.artistFor(entry) : "",
            cover: entry ? Music.coverForEntry(entry) : "",
            current: current,
            playing: current && Music.playing
        };
    }

    // Whether a row can be dragged: only a song still to come has anywhere to go
    function reorderable(row: var): bool {
        return row.kind === "track" && (row.section === "user" || row.section === "auto");
    }

    // Whether a row can be taken out of the list: anything but the one playing, which is not
    // waiting for anything
    function removable(row: var): bool {
        return row.kind === "track" && row.section !== "current";
    }

    function beginDrag(section: string, ordinal: int): void {
        root.dragSection = section;
        root.dragOrdinal = ordinal;
        root.dragToOrdinal = ordinal;
        // The queue indices of this section, in order, so the drag can be turned into a move
        root.dragIndices = root.rows.filter(row => row.kind === "track" && row.section === section).map(row => row.index);
    }

    // A drag is measured in rows: one row up or down is one place in the section it started in
    function updateDrag(rows: int): void {
        if (!root.reordering)
            return;

        const last = root.dragIndices.length - 1;
        root.dragToOrdinal = Math.max(0, Math.min(last, root.dragOrdinal + rows));
    }

    function endDrag(): void {
        if (root.reordering && root.dragToOrdinal !== root.dragOrdinal)
            Music.moveInQueue(root.dragIndices[root.dragOrdinal], root.dragIndices[root.dragToOrdinal]);

        root.dragOrdinal = -1;
        root.dragToOrdinal = -1;
        root.dragSection = "";
        root.dragIndices = [];
    }

    // Where a row sits while another one is being dragged over it: out of the way by a row,
    // unless it is the one being dragged, which follows the pointer instead
    function rowShift(row: var): real {
        if (!root.reordering || row.kind !== "track" || row.section !== root.dragSection || row.ordinal === root.dragOrdinal)
            return 0;

        if (root.dragToOrdinal > root.dragOrdinal && row.ordinal > root.dragOrdinal && row.ordinal <= root.dragToOrdinal)
            return -root.rowHeight;
        if (root.dragToOrdinal < root.dragOrdinal && row.ordinal < root.dragOrdinal && row.ordinal >= root.dragToOrdinal)
            return root.rowHeight;
        return 0;
    }

    // Keeps the song that is playing in sight as the queue moves on: the history above it
    // grows as songs finish, which would otherwise push it off the bottom
    onCurrentRowChanged: {
        if (root.currentRow >= 0)
            root.positionViewAtIndex(root.currentRow, ListView.Contain);
    }

    onVisibleChanged: {
        if (visible && root.currentRow >= 0)
            root.positionViewAtIndex(root.currentRow, ListView.Contain);
    }

    clip: true
    spacing: 0

    StyledScrollBar.vertical: StyledScrollBar {
        flickable: root
    }

    model: root.rows

    delegate: Item {
        id: holder

        required property var modelData

        readonly property bool isHeader: holder.modelData.kind === "header"
        readonly property bool draggable: root.reorderable(holder.modelData)
        // The row being dragged, which is the one that follows the pointer
        readonly property bool draggingThis: root.reordering && holder.draggable && holder.modelData.ordinal === root.dragOrdinal && holder.modelData.section === root.dragSection

        width: root.width
        // Only songs have to be a fixed height; a header takes what its text needs
        height: holder.isHeader ? header.implicitHeight + Tokens.padding.medium + Tokens.padding.extraSmall : root.rowHeight

        Item {
            id: body

            width: holder.width
            height: holder.height
            y: holder.draggingThis ? drag.translation.y : root.rowShift(holder.modelData)
            z: holder.draggingThis ? 2 : 0

            Behavior on y {
                enabled: !holder.draggingThis

                Anim {
                    type: Anim.DefaultEffects
                }
            }

            RowLayout {
                id: header

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                spacing: Tokens.spacing.small
                visible: holder.isHeader

                StyledText {
                    text: holder.modelData.text ?? ""
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.medium
                }

                StyledText {
                    Layout.fillWidth: true
                    text: holder.modelData.count ?? ""
                    color: Colours.palette.m3outline
                    font: Tokens.font.label.small
                }
            }

            // What a dragged row sits on, so it reads as picked up
            StyledRect {
                anchors.fill: parent
                visible: holder.draggingThis
                color: Colours.tPalette.m3surfaceContainerHighest
                radius: Tokens.rounding.medium
            }

            LibraryRow {
                id: row

                anchors.fill: parent
                anchors.topMargin: Tokens.spacing.extraSmall / 4
                anchors.bottomMargin: Tokens.spacing.extraSmall / 4
                visible: !holder.isHeader
                // The history is behind us, so it sits back a little
                opacity: holder.modelData.section === "played" ? 0.6 : 1
                item: holder.modelData
                reorderable: holder.draggable
                removable: root.removable(holder.modelData)
                onClicked: {
                    if (holder.modelData.section === "played")
                        Music.replayPlayed(holder.modelData.index);
                    else if (holder.modelData.section !== "current")
                        Music.skipTo(holder.modelData.index);
                }
                onRemoveClicked: {
                    if (holder.modelData.section === "played")
                        Music.removeFromPlayed(holder.modelData.index);
                    else
                        Music.removeFromQueue(holder.modelData.index);
                }
            }

            // The drag itself. It only starts once the pointer has moved, so a tap still reaches
            // the row underneath and plays the song.
            DragHandler {
                id: drag

                target: null
                enabled: holder.draggable
                xAxis.enabled: false
                cursorShape: Qt.OpenHandCursor

                onActiveChanged: {
                    if (active)
                        root.beginDrag(holder.modelData.section, holder.modelData.ordinal);
                    else
                        root.endDrag();
                }

                onTranslationChanged: {
                    if (active)
                        root.updateDrag(Math.round(translation.y / root.rowHeight));
                }
            }
        }
    }
}
