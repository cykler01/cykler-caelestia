import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

// One small round-ended reading, icon then value
StyledRect {
    id: root

    property real s: 1
    property string icon
    property string text

    implicitWidth: row.implicitWidth + Tokens.padding.large * 2 * root.s
    implicitHeight: row.implicitHeight + Tokens.padding.small * 2 * root.s
    radius: Tokens.rounding.full
    color: Colours.tPalette.m3surfaceContainer

    RowLayout {
        id: row

        anchors.centerIn: parent
        spacing: Tokens.spacing.small * root.s

        MaterialIcon {
            text: root.icon
            color: Colours.palette.m3primary
            fontStyle: Tokens.font.icon.builders.medium.scale(root.s).build()
        }

        StyledText {
            text: root.text
            color: Colours.palette.m3onSurface
            font: Tokens.font.label.builders.large.scale(root.s).weight(Font.DemiBold).build()
        }
    }
}
