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
    // Whether the user opened the equalizer drawer, which shares the slot under the player
    property bool eqToggled

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
    // The equalizer is an opt-in service (Settings > Audio), so the tab only offers it - and only
    // keeps it open - while that option is on
    readonly property bool eqOpen: root.eqToggled && Equalizer.enabled
    // Only one of them is ever open, so the tab only ever grows by the one drawer
    readonly property bool drawerOpen: root.libraryOpen || root.eqOpen
    // How much the drawer adds to the tab (and so to the dashboard) while it is open
    readonly property real drawerHeight: 320
    // Breathing room between the player and the drawer, on top of the layout's own spacing, so
    // the drawer opens clear of the controls instead of on top of them
    readonly property real drawerGap: Tokens.spacing.large
    // Room the fixed tab height leaves for the player, and the height the player actually needs.
    // A track with a volume row, or the placeholder, is taller than that room; the tab grows to
    // match rather than cutting the bottom off the controls.
    readonly property real playerRoom: Tokens.sizes.dashboard.mediaTabHeight - Tokens.padding.large * 2 - header.height - Tokens.spacing.small * 2
    readonly property real playerHeight: Math.max(root.playerRoom, content.implicitHeight, noMedia.implicitHeight)

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
    // The player and the drawer both grow the tab rather than eating into each other, so the
    // controls keep the height they have while the drawer is closed and the drawer stays below
    // whatever the player is showing
    implicitHeight: Tokens.sizes.dashboard.mediaTabHeight + (root.drawerOpen ? root.drawerHeight + root.drawerGap : 0) + Math.max(0, root.playerHeight - root.playerRoom)

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
            Layout.fillHeight: true
            spacing: Tokens.spacing.extraLarge

            // The player's own column. The header belongs over the cover and details rather than
            // across the whole tab, which is what lets the lyrics column beside it run the full
            // height of the tab instead of starting below the header
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Tokens.spacing.small

                RowLayout {
                    id: header

                    Layout.fillWidth: true
                    spacing: Tokens.spacing.extraSmall

                    IconButton {
                        // The library is the only thing worth showing when there's nothing to control
                        visible: root.source.available
                        icon: "library_music"
                        type: root.libraryOpen ? IconButton.Filled : IconButton.Tonal
                        isToggle: true
                        checked: root.libraryOpen
                        onClicked: {
                            root.libraryToggled = !root.libraryToggled;
                            if (root.libraryToggled)
                                root.eqToggled = false;
                        }
                    }

                    IconButton {
                        visible: Equalizer.enabled
                        icon: "equalizer"
                        type: root.eqOpen ? IconButton.Filled : IconButton.Tonal
                        isToggle: true
                        checked: root.eqOpen
                        onClicked: {
                            root.eqToggled = !root.eqToggled;
                            if (root.eqToggled)
                                root.libraryToggled = false;
                        }
                    }

                    // Sits just right of the drawer toggles rather than out at the right hand end,
                    // so the menu that comes out of it drops over the cover and details and leaves
                    // the lyrics column clear
                    SplitButton {
                        // Dropdown arrow leading, ahead of the name of the media system being
                        // controlled
                        expandOnLeft: true
                        menuItems: sourceItems.instances
                        active: menuItems.find(i => root.localActive ? i.modelData.kind === "local" : i.modelData.player === Players.active) ?? null
                        // Drops down rather than up: the header sits at the top of the tab, so
                        // there is far more room below the button than above it, and Menu still
                        // flips it back up by itself if one ever grows too tall to fit (see
                        // Menu.effectiveAbove). With the arrow leading, SplitButton lays the menu
                        // out under it, so the menu starts at the left edge of the selector
                        // rather than out at the far end of the label
                        menu.onItemSelected: item => root.selectSource((item as SourceItem).modelData)
                        fallbackIcon: "music_note"
                        fallbackText: Tr.trCtx("No players", "no media players active")
                    }

                    Item {
                        Layout.fillWidth: true
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

                            // Still in a layout of its own, so the details keep to their own height
                            // and stay centred in the column rather than being stretched by the
                            // loader
                            sourceComponent: RowLayout {
                                Details {
                                    Layout.fillWidth: true
                                    source: root.source
                                }
                            }
                        }
                    }
                }
            }

            // Spans the tab beside the player, since the header above only covers the player's own
            // column: the lyrics are as tall as the two of them together
            LyricsPane {
                Layout.fillHeight: true
                implicitWidth: Tokens.sizes.dashboard.mediaSectionWidth
                source: root.source
            }
        }

        // One slot holds either drawer, so the layout only ever has to account for a single one
        Item {
            id: drawer

            Layout.fillWidth: true
            Layout.topMargin: root.drawerOpen ? root.drawerGap : 0
            Layout.preferredHeight: root.drawerOpen ? root.drawerHeight : 0
            Layout.minimumHeight: 0
            clip: true

            Behavior on Layout.topMargin {
                Anim {}
            }

            Behavior on Layout.preferredHeight {
                Anim {}
            }

            LibraryBrowser {
                anchors.fill: parent
                opacity: root.libraryOpen ? 1 : 0
                enabled: root.libraryOpen

                onTrackPlayed: root.useLocal = true

                Behavior on opacity {
                    Anim {
                        type: Anim.DefaultEffects
                    }
                }
            }

            EqualizerPanel {
                anchors.fill: parent
                opacity: root.eqOpen ? 1 : 0
                enabled: root.eqOpen

                Behavior on opacity {
                    Anim {
                        type: Anim.DefaultEffects
                    }
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
