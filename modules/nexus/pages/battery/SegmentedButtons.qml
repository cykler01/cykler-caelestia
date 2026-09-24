pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components.controls
import qs.services

// A row of connected buttons with one selected, e.g. Off / Keep / On (fork feature).
// The selection is drawn from `value` rather than the buttons' own toggle state, so it always
// matches the setting even when the selected button is clicked again.
RowLayout {
    id: root

    // [{ text, icon?, value }]
    required property var options
    property string value
    property bool fillWidth

    signal picked(value: string)

    spacing: Tokens.spacing.extraSmall / 2

    Repeater {
        model: root.options

        IconTextButton {
            id: button

            required property var modelData
            required property int index
            readonly property bool selected: root.value === modelData.value

            Layout.fillWidth: root.fillWidth
            icon: modelData.icon ?? ""
            iconLabel.visible: !!modelData.icon
            text: modelData.text
            font: Tokens.font.body.small
            radiusMorph: false
            horizontalPadding: Tokens.padding.medium
            verticalPadding: Tokens.padding.small

            // Outer corners rounded, inner ones tight, like Material's connected button group
            topLeftRadius: index === 0 || selected ? Tokens.rounding.full : Tokens.rounding.extraSmall
            bottomLeftRadius: topLeftRadius
            topRightRadius: index === root.options.length - 1 || selected ? Tokens.rounding.full : Tokens.rounding.extraSmall
            bottomRightRadius: topRightRadius

            inactiveColour: selected ? Colours.palette.m3primary : Colours.tPalette.m3surfaceContainerHigh
            inactiveOnColour: selected ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant

            onClicked: root.picked(modelData.value)
        }
    }
}
