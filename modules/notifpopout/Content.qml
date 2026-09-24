import QtQuick
import Caelestia.Config
import qs.components
import qs.modules.sidebar as Sidebar
import qs.services

// Translucent on purpose: the blur comes from the compositor, which blurs
// whatever is behind this layer window (see NotifPopout.qml for the rules).
StyledRect {
    id: root

    required property ScreenState screenState
    required property var props

    readonly property real tintOpacity: 0.4
    readonly property real cardOpacity: 0.5

    radius: Tokens.rounding.extraLarge
    color: Qt.alpha(Colours.palette.m3surface, tintOpacity)
    border.width: 1
    border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.3)

    Sidebar.NotifDock {
        props: root.props
        screenState: root.screenState
        cardOpacity: root.cardOpacity
    }
}
