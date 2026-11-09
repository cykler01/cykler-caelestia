pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.filedialog
import qs.services
import qs.modules.dashboard.dash

// The dashboard's home page. It keeps the shape it has always had - a top row above a bottom
// row, with full-height columns either side of them - but which cards are in each of those four
// places, and in what order, now comes from Config.dashboard.widgets rather than being fixed
// here. The shipped defaults are the old layout exactly.
//
// The settings page renders this same component, scaled down and with `editing` set, as a live
// preview you rearrange the real cards in; see modules/nexus/common/DashPreview.qml.
Item {
    id: root

    required property ScreenState screenState
    required property FileDialog facePicker

    // Set by the settings preview, never on the real page
    property bool editing: false
    property var editController: null
    property real editScale: 1

    readonly property real spacing: Tokens.spacing.medium

    // Exposed so the preview can hit-test a drag against the real places
    readonly property var zones: [leftZone, topZone, bottomZone, rightZone]

    // The two rows stacked, with a gap between them only when both have something in them
    readonly property real rowsHeight: topZone.naturalHeight + bottomZone.naturalHeight + (topZone.visible && bottomZone.visible ? root.spacing : 0)

    // A full-height column has to fit too, so the page is as tall as the taller of the two -
    // and never shorter than the floor, for a layout left with nothing that has a height of
    // its own to be measured by
    readonly property real contentHeight: Math.max(root.rowsHeight, leftZone.naturalHeight, rightZone.naturalHeight, Tokens.sizes.dashboard.homeMinHeight)

    implicitWidth: outer.implicitWidth
    implicitHeight: root.contentHeight

    RowLayout {
        id: outer

        anchors.fill: parent
        spacing: root.spacing

        DashZone {
            id: leftZone

            Layout.fillHeight: true
            visible: !leftZone.empty || root.editing
            zoneId: "left"
            vertical: true
            screenState: root.screenState
            facePicker: root.facePicker
            editing: root.editing
            editController: root.editController
            editScale: root.editScale
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: root.spacing

            DashZone {
                id: topZone

                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredHeight: topZone.naturalHeight
                visible: !topZone.empty || root.editing
                zoneId: "top"
                vertical: false
                screenState: root.screenState
                facePicker: root.facePicker
                editing: root.editing
                editController: root.editController
                editScale: root.editScale
            }

            DashZone {
                id: bottomZone

                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredHeight: bottomZone.naturalHeight
                visible: !bottomZone.empty || root.editing
                zoneId: "bottom"
                vertical: false
                screenState: root.screenState
                facePicker: root.facePicker
                editing: root.editing
                editController: root.editController
                editScale: root.editScale
            }
        }

        DashZone {
            id: rightZone

            Layout.fillHeight: true
            visible: !rightZone.empty || root.editing
            zoneId: "right"
            vertical: true
            screenState: root.screenState
            facePicker: root.facePicker
            editing: root.editing
            editController: root.editController
            editScale: root.editScale
        }
    }
}
