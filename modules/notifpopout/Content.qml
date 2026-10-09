import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.sidebar as Sidebar
import qs.modules.dashboard.media
import qs.modules.todopopout as TodoPopout
import qs.modules.notepadpopout as NotepadPopout

// Sits on the drawers window's frame (see Wrapper.qml), so there is no background of its own: the panel's
// morphing blob is the surface, and the content rests on it in the same containers the sidebar uses.
//
// Four tabs, moved between with the same swipe that opens the popout: the
// notification dock, the local music library, the to-do list and the notepad, so all four sit
// in the one panel that swipe already reaches rather than each needing a window of its own.
Item {
    id: root

    required property ScreenState screenState
    required property var props
    // Whether the popout is on screen (or animating out): the local player controls, which follow the playback
    // position many times a second, are only built then
    property bool shown: true

    // 0 notifications, 1 media library, 2 to-do, 3 notepad. Lives on the screen state so
    // closing the popout doesn't send it back to the first tab
    readonly property int tab: root.screenState.notifPopoutTab
    // The library walks the music folder, so it is only built the first time the tab is
    // actually opened, and kept afterwards rather than rebuilt on every switch back.
    // Seeded from the tab so a config reload on the library tab doesn't sit empty
    property bool libraryLoaded: root.tab === 1
    // Where the tab switch is, in tabs: follows the tab through an animation, and is what
    // everything that moves between the panes below reads
    property real tabPos: root.tab

    function showTab(index: int): void {
        root.screenState.notifPopoutTab = index;
    }

    onTabChanged: {
        if (root.tab === 1)
            root.libraryLoaded = true;
    }

    Behavior on tabPos {
        Anim {
            type: Anim.DefaultSpatial
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Tokens.spacing.medium

        SegmentedBar {
            Layout.fillWidth: true
            // Icon-only: four full labels ("Notifications" is a long word) don't fit this
            // panel's width without the icon and text squeezing into each other
            compact: true

            model: [
                {
                    icon: "notifications",
                    text: Tr.tr("Notifications")
                },
                {
                    icon: "library_music",
                    text: Tr.tr("Music")
                },
                {
                    icon: "checklist",
                    text: Tr.tr("To-do")
                },
                {
                    icon: "edit_note",
                    text: Tr.tr("Notepad")
                }
            ]
            currentIndex: root.tab
            onActivated: index => root.showTab(index)
        }

        // The panes sit side by side and slide past each other, fading as they go, so switching
        // reads as moving along rather than as one thing replacing another
        Item {
            id: panes

            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            StyledRect {
                id: notifPane

                readonly property real offset: 0 - root.tabPos

                x: offset * panes.width * 0.6
                width: panes.width
                height: panes.height
                opacity: 1 - Math.min(1, Math.abs(offset))
                visible: opacity > 0
                radius: Tokens.rounding.large
                color: Colours.tPalette.m3surfaceContainerLow

                Sidebar.NotifDock {
                    anchors.fill: parent

                    props: root.props
                    screenState: root.screenState
                }
            }

            StyledRect {
                id: libraryPane

                readonly property real offset: 1 - root.tabPos

                x: offset * panes.width * 0.6
                width: panes.width
                height: panes.height
                opacity: 1 - Math.min(1, Math.abs(offset))
                visible: opacity > 0
                radius: Tokens.rounding.large
                color: Colours.tPalette.m3surfaceContainerLow

                Loader {
                    anchors.fill: parent
                    active: root.libraryLoaded

                    sourceComponent: LibraryBrowser {
                        // Sits straight on the container, like the notification cards do
                        color: "transparent"
                    }
                }
            }

            StyledRect {
                id: todoPane

                readonly property real offset: 2 - root.tabPos

                x: offset * panes.width * 0.6
                width: panes.width
                height: panes.height
                opacity: 1 - Math.min(1, Math.abs(offset))
                visible: opacity > 0
                radius: Tokens.rounding.large
                color: Colours.tPalette.m3surfaceContainerLow

                TodoPopout.Content {
                    anchors.fill: parent

                    open: root.tab === 2
                    screenState: root.screenState
                }
            }

            StyledRect {
                id: notepadPane

                readonly property real offset: 3 - root.tabPos

                x: offset * panes.width * 0.6
                width: panes.width
                height: panes.height
                opacity: 1 - Math.min(1, Math.abs(offset))
                visible: opacity > 0
                radius: Tokens.rounding.large
                color: Colours.tPalette.m3surfaceContainerLow

                NotepadPopout.Content {
                    anchors.fill: parent

                    open: root.tab === 3
                    screenState: root.screenState
                }
            }
        }

        // Controls for the in-shell player alone, under the library. The media tab's own
        // controls follow whichever MPRIS player is active; these keep driving the local
        // queue while you are picking from it, and while anything else is playing. They grow in
        // and out with the tab rather than popping the panes' height about, and shrink away again
        // moving on to the to-do or notepad tab.
        Loader {
            id: localControls

            // 1 right on the music tab, fading out towards either neighbour
            readonly property real nearMusic: Math.max(0, 1 - Math.abs(root.tabPos - 1))

            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.medium
            Layout.rightMargin: Tokens.padding.medium
            Layout.preferredHeight: (item ? item.implicitHeight : 64) * nearMusic
            visible: nearMusic > 0.01
            opacity: nearMusic
            clip: true
            active: root.shown && (root.tab === 1 || nearMusic > 0.01)

            sourceComponent: LocalControls {}
        }
    }
}
