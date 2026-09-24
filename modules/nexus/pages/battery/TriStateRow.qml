pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.modules.nexus.common

// A row with a three-state control: force off / keep as is / force on (fork feature)
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

        SegmentedButtons {
            value: root.isUnchanged ? "" : root.value
            options: [
                {
                    text: Tr.trCtx("Off", "force a visual effect off"),
                    value: "disable"
                },
                {
                    text: Tr.trCtx("Keep", "leave a visual effect as it is"),
                    value: ""
                },
                {
                    text: Tr.trCtx("On", "force a visual effect on"),
                    value: "enable"
                }
            ]
            onPicked: v => root.triStateValueChanged(v)
        }
    }
}
