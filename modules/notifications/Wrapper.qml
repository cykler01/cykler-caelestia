import QtQuick
import qs.components

Item {
    id: root

    required property ScreenState screenState
    required property Item sidebarPanel
    property alias osdPanel: content.osdPanel
    property alias sessionPanel: content.sessionPanel
    property alias utilitiesPanel: content.utilitiesPanel

    visible: height > 0
    anchors.topMargin: -5
    implicitWidth: Math.max(sidebarPanel.width, content.implicitWidth)
    implicitHeight: content.implicitHeight

    Content {
        id: content

        // The content itself keeps its normal (unmirrored) layout
        LayoutMirroring.enabled: false
        LayoutMirroring.childrenInherit: true

        anchors.topMargin: -root.anchors.topMargin
        screenState: root.screenState
    }
}
