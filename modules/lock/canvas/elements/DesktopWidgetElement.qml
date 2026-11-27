import QtQuick
import qs.modules.background.widgets

// One of the desktop's widgets (modules/background/widgets) on the lock screen, in the style its
// options pick: the real card, drawn by the same preview the desktop's widget picker uses, at its
// desktop size times the element's own scale.
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
    // The screen's own scale, without the element's own, so the two can be told apart below
    property real uiScale: 1

    // NOTE(fork): a desktop widget is a fixed-size design - its words and its charts are laid out at
    // the card's own size - so drawing it bigger is a scaled-up picture of both rather than a bigger
    // card, which is what made these look soft wherever the lock UI scales up (a 1600p screen draws
    // them almost half again their size). It is drawn at its own size or smaller, as the widget
    // picker's previews are (background/widgets/WidgetPreview.qml); only an element whose own Size
    // asks for more is blown up, and then it is the size that was asked for
    readonly property real elementScale: root.s / Math.max(0.001, root.uiScale)
    readonly property real zoom: Math.min(1, root.uiScale) * root.elementScale

    implicitWidth: card.width * root.zoom
    implicitHeight: card.height * root.zoom

    WidgetPreview {
        id: card

        kind: root.kind
        variant: root.opts.style ?? ""
        width: implicitWidth
        height: implicitHeight
        enabled: false
        scale: root.zoom
        transformOrigin: Item.TopLeft
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        hoverEnabled: true
        onWheel: wheel => wheel.accepted = true
    }
}
