pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

// A row with a three-state control: force-disable / unchanged / force-enable (fork feature)
ConnectedRect {
    id: root

    required property string label
    property string subtext: ""
    property string value: ""
    readonly property bool isEnable: root.value === "enable"
    readonly property bool isDisable: root.value === "disable"
    readonly property bool isUnchanged: !root.isEnable && !root.isDisable

    signal triStateValueChanged(string newValue)

    Layout.fillWidth: true
    implicitHeight: row.implicitHeight + Tokens.padding.medium * 2

    RowLayout {
        id: row

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Tokens.padding.largeIncreased
        anchors.rightMargin: Tokens.padding.largeIncreased
        spacing: Tokens.spacing.medium

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                text: root.label
                font: Tokens.font.body.small
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                visible: root.subtext
                text: root.subtext
                color: Colours.palette.m3outline
                font: Tokens.font.label.small
                elide: Text.ElideRight
            }
        }

        Row {
            spacing: Tokens.spacing.extraSmall / 2

            IconButton {
                id: disableButton

                isRound: true
                type: IconButton.Tonal
                icon: "toggle_off"
                inactiveColour: root.isDisable ? Colours.palette.m3error : Colours.tPalette.m3surfaceContainerHigh
                inactiveOnColour: root.isDisable ? Colours.palette.m3onError : Colours.palette.m3onSurfaceVariant

                onClicked: root.triStateValueChanged("disable")
            }

            IconButton {
                id: unchangedButton

                isRound: true
                type: IconButton.Tonal
                icon: "block"
                inactiveColour: root.isUnchanged ? Colours.palette.m3primary : Colours.tPalette.m3surfaceContainerHigh
                inactiveOnColour: root.isUnchanged ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant

                onClicked: root.triStateValueChanged("")
            }

            IconButton {
                id: enableButton

                isRound: true
                type: IconButton.Tonal
                icon: "toggle_on"
                inactiveColour: root.isEnable ? Colours.palette.m3primary : Colours.tPalette.m3surfaceContainerHigh
                inactiveOnColour: root.isEnable ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant

                onClicked: root.triStateValueChanged("enable")
            }
        }
    }
}
