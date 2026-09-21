pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.modules.nexus.common

// Add-threshold button styled like the nexus rows (fork feature)
ConnectedRect {
    id: root

    signal clicked

    Layout.fillWidth: true
    implicitHeight: row.implicitHeight + Tokens.padding.medium * 2

    topLeftRadius: root.first ? Tokens.rounding.extraLarge : Tokens.rounding.extraSmall
    topRightRadius: root.first ? Tokens.rounding.extraLarge : Tokens.rounding.extraSmall
    bottomLeftRadius: root.last ? Tokens.rounding.extraLarge : Tokens.rounding.extraSmall
    bottomRightRadius: root.last ? Tokens.rounding.extraLarge : Tokens.rounding.extraSmall

    color: Colours.layer(Colours.palette.m3surfaceContainerHigh, 2)

    StateLayer {
        onClicked: root.clicked()
    }

    RowLayout {
        id: row

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Tokens.padding.largeIncreased
        anchors.rightMargin: Tokens.padding.largeIncreased
        spacing: Tokens.spacing.medium

        MaterialIcon {
            color: Colours.palette.m3primary
            fontStyle: Tokens.font.icon.medium
            text: "add_circle"
        }

        StyledText {
            Layout.fillWidth: true
            text: Tr.tr("Add threshold")
            color: Colours.palette.m3primary
            font: Tokens.font.body.small
        }
    }
}
