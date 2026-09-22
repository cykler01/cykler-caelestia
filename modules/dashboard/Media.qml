import "media"
import QtQuick
import QtQuick.Layouts
import Quickshell
import M3Shapes
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services

// NOTE(fork): one media tab for both the external MPRIS players and the in-shell local
// player. The player keeps the original layout, and the library is a drawer underneath it
// that opens by itself whenever there is nothing to control.
Item {
    id: root

    required property ScreenState screenState

    // Whether the tab is controlling the in-shell player instead of an MPRIS player
    property bool useLocal
    // Whether the user opened the library drawer themselves
    property bool libraryToggled

    readonly property MediaSource localSource: MediaSource {
        local: true
    }
    readonly property MediaSource mprisSource: MediaSource {
        mpris: Players.active
    }
    // Nothing external means the in-shell player is the only thing to control
    readonly property bool localActive: root.useLocal || !Players.active
    readonly property MediaSource source: root.localActive ? root.localSource : root.mprisSource

    // The library is the only useful thing to show when there is nothing to control
    readonly property bool libraryOpen: root.libraryToggled || !root.source.available
    // How much the drawer adds to the tab (and so to the dashboard) while it is open
    readonly property real libraryHeight: 320

    // External players plus the in-shell player, for the source picker
    readonly property var sourceOptions: {
        const options = [];
        for (const player of Players.list)
            options.push({
                kind: "mpris",
                player: player,
                label: Players.getIdentity(player)
            });
        options.push({
            kind: "local",
            player: null,
            label: Tr.tr("Local player")
        });
        return options;
    }

    function selectSource(option): void {
        if (option.kind === "local") {
            root.useLocal = true;
            return;
        }
        root.useLocal = false;
        Players.manualActive = option.player;
    }

    implicitWidth: Tokens.sizes.dashboard.mediaTabWidth
    implicitHeight: Tokens.sizes.dashboard.mediaTabHeight + (root.libraryOpen ? root.libraryHeight : 0)

    BackgroundShapes {
        anchors.fill: parent
        playing: root.source.isPlaying
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.small

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.extraSmall

            IconButton {
                // The library is the only thing worth showing when there's nothing to control
                visible: root.source.available
                icon: "library_music"
                type: root.libraryOpen ? IconButton.Filled : IconButton.Tonal
                isToggle: true
                checked: root.libraryOpen
                onClicked: root.libraryToggled = !root.libraryToggled
            }

            Item {
                Layout.fillWidth: true
            }

            SplitButton {
                menuOnTop: true
                menuItems: sourceItems.instances
                active: menuItems.find(i => root.localActive ? i.modelData.kind === "local" : i.modelData.player === Players.active) ?? null
                menu.onItemSelected: item => root.selectSource((item as SourceItem).modelData)
                fallbackIcon: "music_note"
                fallbackText: Tr.trCtx("No players", "no media players active")
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Tokens.spacing.extraLarge

            CoverVisualiser {
                Layout.fillHeight: true
                implicitWidth: Tokens.sizes.dashboard.mediaSectionWidth
                source: root.source
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                state: root.source.available ? "" : "noMedia"

                states: State {
                    name: "noMedia"

                    PropertyChanges {
                        noMedia.opacity: 1
                        content.opacity: 0
                    }
                }

                transitions: [
                    Transition {
                        from: ""

                        SequentialAnimation {
                            Anim {
                                target: content
                                property: "opacity"
                                type: Anim.DefaultEffects
                            }
                            Anim {
                                target: noMedia
                                property: "opacity"
                                type: Anim.SlowEffects
                            }
                        }
                    },
                    Transition {
                        to: ""

                        SequentialAnimation {
                            Anim {
                                target: noMedia
                                property: "opacity"
                                type: Anim.DefaultEffects
                            }
                            Anim {
                                target: content
                                property: "opacity"
                                type: Anim.SlowEffects
                            }
                        }
                    }
                ]

                Loader {
                    id: noMedia

                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: -Tokens.padding.extraLarge * 2
                    asynchronous: true
                    active: opacity > 0
                    opacity: 0

                    sourceComponent: ColumnLayout {
                        spacing: Tokens.spacing.small

                        MaterialShape {
                            Layout.topMargin: (pathBounds().height - implicitSize) / 2
                            Layout.bottomMargin: (pathBounds().height - implicitSize) / 2 + Tokens.spacing.small
                            Layout.alignment: Qt.AlignHCenter
                            color: Colours.palette.m3primaryContainer
                            implicitSize: icon.implicitHeight + Tokens.padding.extraLarge * 2
                            shape: MaterialShape.ClamShell

                            Behavior on color {
                                CAnim {}
                            }

                            MaterialIcon {
                                id: icon

                                anchors.centerIn: parent
                                text: "queue_music"
                                fontStyle: Tokens.font.icon.builders.large.scale(2).build()
                                color: Colours.palette.m3onPrimaryContainer
                            }
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: Tr.tr("Nothing playing")
                            font: Tokens.font.headline.medium
                        }

                        StyledText {
                            text: Tr.tr("Pick something from the library to play it here!")
                            color: Colours.palette.m3onSurfaceVariant
                            font: Tokens.font.body.large
                        }
                    }
                }

                Loader {
                    id: content

                    anchors.fill: parent
                    asynchronous: true
                    active: opacity > 0

                    sourceComponent: RowLayout {
                        spacing: Tokens.spacing.extraLarge

                        Details {
                            Layout.fillWidth: true
                            source: root.source
                        }

                        LyricsPane {
                            Layout.fillHeight: true
                            implicitWidth: Tokens.sizes.dashboard.mediaSectionWidth
                            source: root.source
                        }
                    }
                }
            }
        }

        LibraryBrowser {
            Layout.fillWidth: true
            Layout.preferredHeight: root.libraryOpen ? root.libraryHeight : 0
            Layout.minimumHeight: 0
            clip: true
            opacity: root.libraryOpen ? 1 : 0
            enabled: root.libraryOpen

            onTrackPlayed: root.useLocal = true

            Behavior on Layout.preferredHeight {
                Anim {}
            }

            Behavior on opacity {
                Anim {
                    type: Anim.DefaultEffects
                }
            }
        }
    }

    Variants {
        id: sourceItems

        model: root.sourceOptions

        SourceItem {}
    }

    component SourceItem: MenuItem {
        required property var modelData

        text: modelData.label
        icon: modelData.kind === "local" ? "library_music" : "music_note"
        activeIcon: modelData.kind === "local" ? "library_music" : "animated_images"
    }
}
