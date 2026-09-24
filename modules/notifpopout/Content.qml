import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.modules.dashboard.media
import qs.modules.sidebar as Sidebar
import qs.services

// Translucent on purpose: the blur comes from the compositor, which blurs
// whatever is behind this layer window (see NotifPopout.qml for the rules).
//
// Two tabs, moved between with the same swipe that opens the popout: the
// notification dock and the local music library, so the picker for what to play
// lives where the swipe already goes rather than in a separate window.
StyledRect {
    id: root

    required property ScreenState screenState
    required property var props

    readonly property real tintOpacity: 0.4
    readonly property real cardOpacity: 0.5
    // 0 notifications, 1 media library. Lives on the screen state so closing the
    // popout doesn't send it back to the first tab
    readonly property int tab: root.screenState.notifPopoutTab
    // The library walks the music folder, so it is only built the first time the tab is
    // actually opened, and kept afterwards rather than rebuilt on every switch back.
    // Seeded from the tab so a config reload on the library tab doesn't sit empty
    property bool libraryLoaded: root.tab === 1

    function showTab(index: int): void {
        root.screenState.notifPopoutTab = index;
    }

    onTabChanged: {
        if (root.tab === 1)
            root.libraryLoaded = true;
    }

    radius: Tokens.rounding.extraLarge
    color: Qt.alpha(Colours.palette.m3surface, tintOpacity)
    border.width: 1
    border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.3)

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        RowLayout {
            // Lines the buttons up with the pane content underneath, which is inset by
            // the dock's own margins
            Layout.topMargin: Tokens.padding.medium
            Layout.leftMargin: Tokens.padding.medium
            Layout.rightMargin: Tokens.padding.medium
            Layout.fillWidth: true
            spacing: Tokens.spacing.extraSmall

            IconButton {
                icon: "notifications"
                isToggle: true
                checked: root.tab === 0
                type: root.tab === 0 ? IconButton.Filled : IconButton.Tonal
                onClicked: root.showTab(0)
            }

            IconButton {
                icon: "library_music"
                isToggle: true
                checked: root.tab === 1
                type: root.tab === 1 ? IconButton.Filled : IconButton.Tonal
                onClicked: root.showTab(1)
            }

            Item {
                Layout.fillWidth: true
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Sidebar.NotifDock {
                anchors.fill: parent
                visible: root.tab === 0

                props: root.props
                screenState: root.screenState
                cardOpacity: root.cardOpacity
            }

            Loader {
                anchors.fill: parent
                visible: root.tab === 1
                active: root.libraryLoaded

                sourceComponent: LibraryBrowser {
                    // Sits straight on the translucent panel, so the blur still reads
                    // through it the way the notification cards do
                    color: "transparent"
                }
            }
        }
    }
}
