import QtQuick
import qs.components

Item {
    id: root

    required property ScreenState screenState
    required property Item sidebarPanel
    property alias osdPanel: content.osdPanel
    property alias sessionPanel: content.sessionPanel
    property alias utilitiesPanel: content.utilitiesPanel
    // Whether each of those panels is on the same side as the popups (only then do they limit how tall they can be)
    property alias osdSame: content.osdSame
    property alias sessionSame: content.sessionSame
    property alias utilitiesSame: content.utilitiesSame
    property alias atLeft: content.atLeft
    property alias atBottom: content.atBottom
    // Whether the sidebar stack is on the popups' side, which is what makes them as wide as the sidebar
    property bool stackSame: true

    visible: height > 0
    anchors.topMargin: -5
    implicitWidth: stackSame ? Math.max(sidebarPanel.width, content.implicitWidth) : content.implicitWidth
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
