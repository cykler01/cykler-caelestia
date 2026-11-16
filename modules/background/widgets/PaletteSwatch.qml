pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// One colour of the scheme on the palette card: a patch of it, optionally named in its own "on" colour.
// It says nothing about its value itself; hovering and clicking are passed up, and the card shows the
// name and hex of whichever patch is under the pointer in its header, which is the one place on the card
// with room for it whatever the size of the patch
Item {
    id: root

    property color colour
    // The colour text is set in on this patch: the scheme's own pairing where it has one
    property color onColour: Colours.on(root.colour)
    // The colour's name, for the header
    property string name
    // Text drawn on the patch itself; nothing for the small ones
    property string label
    property font labelFont: Tokens.font.label.small
    // A small dot in the middle, for the tone the scheme actually uses
    property bool marked

    property real topLeftRadius: Tokens.rounding.small
    property real topRightRadius: Tokens.rounding.small
    property real bottomLeftRadius: Tokens.rounding.small
    property real bottomRightRadius: Tokens.rounding.small

    readonly property bool hovered: touch.containsMouse
    // As #RRGGBB, the form every colour picker takes
    readonly property string hex: `#${[root.colour.r, root.colour.g, root.colour.b].map(c => Math.round(c * 255).toString(16).padStart(2, "0")).join("")}`.toUpperCase()

    signal activated

    Rectangle {
        anchors.fill: parent
        color: root.colour
        topLeftRadius: root.topLeftRadius
        topRightRadius: root.topRightRadius
        bottomLeftRadius: root.bottomLeftRadius
        bottomRightRadius: root.bottomRightRadius

        Behavior on color {
            CAnim {}
        }
    }

    StyledText {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: Tokens.padding.small
        anchors.rightMargin: Tokens.padding.extraSmall
        anchors.bottomMargin: Tokens.padding.small
        visible: root.label !== ""
        elide: Text.ElideRight
        text: root.label
        color: root.onColour
        font: root.labelFont
    }

    Rectangle {
        anchors.centerIn: parent
        visible: root.marked
        width: 6
        height: 6
        radius: 3
        color: root.onColour
    }

    StateLayer {
        id: touch

        color: root.onColour
        topLeftRadius: root.topLeftRadius
        topRightRadius: root.topRightRadius
        bottomLeftRadius: root.bottomLeftRadius
        bottomRightRadius: root.bottomRightRadius
        onClicked: root.activated()
    }
}
