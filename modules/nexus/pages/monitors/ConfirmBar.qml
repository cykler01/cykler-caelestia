import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

RowLayout {
    id: root

    visible: Monitors.confirming
    spacing: Tokens.spacing.small

    MaterialIcon {
        text: "timer"
        fontStyle: Tokens.font.icon.small
        color: Colours.palette.m3primary
    }

    StyledText {
        Layout.fillWidth: true
        text: qsTr("Keep these display settings? Reverting in %1s").arg(Monitors.confirmSecondsLeft)
        font: Tokens.font.label.medium
        color: Colours.palette.m3primary
        elide: Text.ElideRight
    }

    TextButton {
        type: TextButton.Text
        isRound: true
        horizontalPadding: Tokens.padding.large
        text: qsTr("Revert")
        onClicked: Monitors.revertChanges()
    }

    TextButton {
        type: TextButton.Filled
        isRound: true
        horizontalPadding: Tokens.padding.large
        text: qsTr("Keep")
        onClicked: Monitors.keepChanges()
    }
}
