import QtQuick
import qs.modules.background.widgets

// One of the desktop's widgets (modules/background/widgets) on the lock screen, in the style its
// options pick: the real card, drawn by the same preview the desktop's widget picker uses, at its
// desktop size times the element's scale.
//
// For looking at only. A locked screen mustn't run a search, open a link or take notes, and a card
// that took the keyboard would take it from the password field, so the card is disabled and every
// press on it is caught before it gets there
Item {
    id: root

    property real s: 1
    property var opts: ({})
    property var lock: null
    // The desktop widget's id, from the element's ("widget:calendar" draws "calendar")
    property string kind

    implicitWidth: card.implicitWidth * root.s
    implicitHeight: card.implicitHeight * root.s

    WidgetPreview {
        id: card

        kind: root.kind
        variant: root.opts.style ?? ""
        width: implicitWidth
        height: implicitHeight
        enabled: false
        scale: root.s
        transformOrigin: Item.TopLeft
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        hoverEnabled: true
        onWheel: wheel => wheel.accepted = true
    }
}
