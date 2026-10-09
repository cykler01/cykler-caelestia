import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.notifpopout as NotifPopout

Item {
    id: root

    required property Props props
    required property ScreenState screenState

    ColumnLayout {
        id: layout

        anchors.fill: parent
        spacing: Tokens.spacing.medium

        StyledRect {
            Layout.fillWidth: true
            Layout.fillHeight: true

            radius: Tokens.rounding.large
            color: Colours.tPalette.m3surfaceContainerLow

            // Notifications, the local music library, the to-do list and the notepad, as tabs
            // of one card (see modules/notifpopout/Content.qml, shared with the swipe gesture)
            NotifPopout.Content {
                objectName: "sidebarNotifications"
                anchors.fill: parent
                anchors.margins: Tokens.padding.large

                shown: root.screenState.sidebar
                props: root.props
                screenState: root.screenState
            }
        }

        StyledRect {
            Layout.topMargin: Tokens.padding.large - layout.spacing
            Layout.fillWidth: true
            implicitHeight: 1

            color: Colours.tPalette.m3outlineVariant
        }
    }
}
