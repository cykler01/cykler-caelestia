pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Components
import Caelestia.Config
import Caelestia.I18n
import Caelestia.Models
import qs.components
import qs.components.containers
import qs.components.controls
import qs.components.widgets
import qs.services

// NOTE(fork): the local music player view of the dashboard media tab. The library panel
// browses the configured music folder or searches it, and the right hand side drives
// playback through the Music service.
RowLayout {
    id: root

    readonly property string query: search.text.trim().toLowerCase()
    readonly property bool searching: root.query.length > 0
    readonly property real coverSize: Math.max(0, Math.min(Tokens.sizes.dashboard.mediaCoverArtSize, root.height))
    readonly property var folderItems: {
        const items = [];
        const dirs = Music.subDirs;
        for (let i = 0; i < dirs.length; i++)
            items.push(dirs[i]);
        const files = Music.folderTracks;
        for (let i = 0; i < files.length; i++)
            items.push(files[i]);
        return items;
    }
    // Searched over the whole path, so an album or folder name finds its tracks too
    readonly property var searchResults: {
        if (!root.searching)
            return [];

        const results = [];
        const library = Music.library;
        for (let i = 0; i < library.length; i++)
            if (library[i].relativePath.toLowerCase().includes(root.query))
                results.push(library[i]);
        return results;
    }
    readonly property var items: root.searching ? root.searchResults : root.folderItems

    function timeStr(seconds: real): string {
        if (!isFinite(seconds) || seconds <= 0)
            return "0:00";

        const total = Math.floor(seconds);
        return `${Math.floor(total / 60)}:${(total % 60).toString().padStart(2, "0")}`;
    }

    // Path of an entry relative to the music folder, for disambiguating search results
    function relativeDirOf(entry: FileSystemEntry): string {
        const dir = entry.parentDir;
        if (!dir.startsWith(Music.rootDir))
            return dir;
        return dir.slice(Music.rootDir.length).replace(/^\//, "");
    }

    // Plays a library entry, queueing the rest of the folder or search results behind it
    function playEntry(entry: FileSystemEntry): void {
        if (entry.isDir) {
            Music.cd(entry.path);
            return;
        }

        const entries = root.searching ? root.searchResults : Music.folderTracks;
        const paths = [];
        let index = -1;
        for (let i = 0; i < entries.length; i++) {
            if (entries[i].isDir)
                continue;
            if (entries[i].path === entry.path)
                index = paths.length;
            paths.push(entries[i].path);
        }

        if (index >= 0)
            Music.playQueue(paths, index);
    }

    spacing: Tokens.spacing.large

    // Library
    ColumnLayout {
        Layout.preferredWidth: Tokens.sizes.dashboard.mediaSectionWidth
        Layout.fillHeight: true
        spacing: Tokens.spacing.small

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.extraSmall

            IconButton {
                icon: "arrow_upward"
                type: IconButton.Text
                disabled: Music.atRoot
                onClicked: Music.cdUp()
            }

            StyledText {
                Layout.fillWidth: true
                text: Music.relativeDir || Tr.tr("Music")
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.medium
                elide: Text.ElideLeft
            }

            IconButton {
                icon: "home"
                type: IconButton.Text
                disabled: Music.atRoot
                onClicked: Music.cdRoot()
            }
        }

        SearchBar {
            id: search

            Layout.fillWidth: true
            placeholderText: Tr.tr("Search music")
            font: Tokens.font.body.small
            topPadding: Tokens.padding.small
            bottomPadding: Tokens.padding.small
        }

        StyledClippingRect {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Tokens.rounding.large
            color: Colours.tPalette.m3surfaceContainer

            StyledListView {
                id: list

                anchors.fill: parent
                anchors.margins: Tokens.padding.extraSmall
                clip: true
                spacing: Tokens.spacing.extraSmall / 2
                model: root.items

                StyledScrollBar.vertical: StyledScrollBar {
                    flickable: list
                }

                delegate: StyledRect {
                    id: entry

                    required property FileSystemEntry modelData
                    required property int index

                    readonly property bool isCurrent: !entry.modelData.isDir && entry.modelData.path === Music.currentFile
                    readonly property string subtitle: entry.modelData.isDir || !root.searching ? "" : root.relativeDirOf(entry.modelData)

                    implicitWidth: ListView.view.width
                    implicitHeight: layout.implicitHeight + Tokens.padding.small * 2
                    radius: Tokens.rounding.medium
                    color: entry.isCurrent ? Colours.palette.m3secondaryContainer : "transparent"

                    StateLayer {
                        onClicked: root.playEntry(entry.modelData)
                    }

                    RowLayout {
                        id: layout

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Tokens.padding.medium
                        anchors.rightMargin: Tokens.padding.medium
                        spacing: Tokens.spacing.small

                        MaterialIcon {
                            text: entry.modelData.isDir ? "folder" : entry.isCurrent && Music.playing ? "graphic_eq" : "music_note"
                            color: entry.isCurrent ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                            fontStyle: Tokens.font.icon.small
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            StyledText {
                                Layout.fillWidth: true
                                text: entry.modelData.isDir ? entry.modelData.name : entry.modelData.baseName
                                color: entry.isCurrent ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                                font: Tokens.font.body.medium
                                elide: Text.ElideRight
                            }

                            StyledText {
                                Layout.fillWidth: true
                                visible: entry.subtitle !== ""
                                text: entry.subtitle
                                color: entry.isCurrent ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3outline
                                font: Tokens.font.label.small
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                anchors.centerIn: parent
                spacing: Tokens.spacing.extraSmall
                opacity: list.count === 0 ? 1 : 0
                visible: opacity > 0

                Behavior on opacity {
                    Anim {
                        type: Anim.DefaultEffects
                    }
                }

                MaterialIcon {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.searching ? "search_off" : "music_off"
                    color: Colours.palette.m3outline
                    fontStyle: Tokens.font.icon.extraLarge
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.searching ? Tr.tr("No matches") : Tr.tr("No music here")
                    color: Colours.palette.m3outline
                    font: Tokens.font.body.medium
                }
            }
        }
    }

    // Now playing
    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Tokens.spacing.large

        CoverArt {
            id: cover

            Layout.alignment: Qt.AlignVCenter
            implicitWidth: root.coverSize
            implicitHeight: root.coverSize
            source: Music.coverPath
            spinning: Music.playing
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Tokens.spacing.extraSmall

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                StyledText {
                    Layout.fillWidth: true
                    animate: true
                    text: Music.hasTrack ? Music.title : Tr.tr("Nothing playing")
                    font: Tokens.font.title.large
                    elide: Text.ElideRight
                }

                StyledText {
                    visible: Music.queueLabel !== ""
                    text: Music.queueLabel
                    color: Colours.palette.m3outline
                    font: Tokens.font.label.medium
                }
            }

            StyledText {
                Layout.fillWidth: true
                visible: Music.hasTrack
                animate: true
                text: Music.artist || Tr.tr("Unknown artist")
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.title.medium
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                visible: Music.hasTrack
                animate: true
                text: Music.album || Tr.tr("Unknown album")
                color: Colours.palette.m3secondary
                font: Tokens.font.body.medium
                elide: Text.ElideRight
            }

            Item {
                Layout.fillHeight: true
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                TextMetrics {
                    id: timeMetrics

                    text: "00:00"
                    font: Tokens.font.label.small
                }

                StyledText {
                    id: positionLabel

                    Layout.preferredWidth: timeMetrics.width
                    text: root.timeStr(Music.position)
                    color: Colours.palette.m3onSurfaceVariant
                    font: timeMetrics.font
                    horizontalAlignment: Text.AlignHCenter
                }

                StyledSlider {
                    id: positionSlider

                    Layout.fillWidth: true
                    enabled: Music.hasTrack && Music.duration > 0
                    value: Music.duration > 0 ? Music.position / Music.duration : 0
                    wavy: true
                    animateWave: Music.playing
                    waveFrequency: 5
                    waveDuration: 2000
                    interactionOnMove: false
                    onInteraction: value => Music.seek(value * Music.duration)

                    Binding {
                        target: positionLabel
                        property: "text"
                        value: root.timeStr(positionSlider.pos * Music.duration)
                        when: positionSlider.dragging
                    }
                }

                StyledText {
                    Layout.preferredWidth: timeMetrics.width
                    text: root.timeStr(Music.duration)
                    color: Colours.palette.m3onSurfaceVariant
                    font: timeMetrics.font
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            ButtonRow {
                Layout.fillWidth: true
                Layout.topMargin: Tokens.spacing.small
                spacing: Tokens.spacing.extraSmall

                IconButton {
                    type: IconButton.Tonal
                    icon: "shuffle"
                    isRound: true
                    shapeMorph: true
                    checked: Music.shuffle
                    disabled: Music.queue.length < 2
                    font: Tokens.font.icon.builders.medium.weight(Font.Medium).build()
                    implicitWidth: Math.round(implicitHeight * 0.9)
                    onClicked: Music.shuffle = !Music.shuffle
                }

                IconButton {
                    type: IconButton.Tonal
                    icon: "skip_previous"
                    isRound: true
                    shapeMorph: true
                    disabled: !Music.hasTrack
                    font: Tokens.font.icon.large
                    onClicked: Music.previous()
                }

                IconButton {
                    fillWidth: true
                    icon: Music.playing ? "pause" : "play_arrow"
                    isRound: true
                    shapeMorph: true
                    checked: Music.playing
                    disabled: !Music.hasTrack
                    font: Tokens.font.icon.large
                    onClicked: Music.togglePlaying()
                }

                IconButton {
                    type: IconButton.Tonal
                    icon: "skip_next"
                    isRound: true
                    shapeMorph: true
                    disabled: !Music.hasTrack
                    font: Tokens.font.icon.large
                    onClicked: Music.next()
                }

                IconButton {
                    type: IconButton.Tonal
                    icon: Music.repeatMode === "one" ? "repeat_one" : "repeat"
                    isRound: true
                    shapeMorph: true
                    checked: Music.repeatMode !== "off"
                    font: Tokens.font.icon.builders.medium.weight(Font.Medium).build()
                    implicitWidth: Math.round(implicitHeight * 0.9)
                    onClicked: Music.cycleRepeat()
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Tokens.spacing.small
                spacing: Tokens.spacing.small

                MaterialIcon {
                    text: Music.volume === 0 ? "volume_off" : "volume_up"
                    color: Colours.palette.m3onSurfaceVariant
                    fontStyle: Tokens.font.icon.small
                }

                StyledSlider {
                    Layout.fillWidth: true
                    value: Music.volume
                    onInteraction: value => Music.setVolume(value)
                }
            }
        }
    }
}
