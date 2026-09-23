pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

ConnectedRect {
    id: root

    property alias icon: icon.text
    property alias label: label.text
    property alias valueLabel: valueLabel.text
    property real value
    property real from
    property real to: 1
    property real stepSize: GlobalConfig.services.audioIncrement

    // StyledSlider is 0-1 only, so expose the value in its own range
    readonly property real position: root.to === root.from ? 0 : Math.max(0, Math.min(1, (root.value - root.from) / (root.to - root.from)))

    signal moved(value: real)

    function valueAt(pos: real): real {
        const clamped = Math.max(0, Math.min(1, pos));
        return root.from + clamped * (root.to - root.from);
    }

    Layout.fillWidth: true
    implicitHeight: rowLayout.implicitHeight + rowLayout.anchors.margins + rowLayout.anchors.topMargin

    RowLayout {
        id: rowLayout

        anchors.fill: parent
        anchors.margins: Tokens.padding.largeIncreased
        anchors.topMargin: Tokens.padding.large
        spacing: Tokens.spacing.medium

        MaterialIcon {
            id: icon

            color: Colours.palette.m3onSurfaceVariant
            fontStyle: Tokens.font.icon.medium
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.medium

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                StyledText {
                    id: label

                    Layout.fillWidth: true
                    font: Tokens.font.body.small
                    elide: Text.ElideRight
                }

                StyledText {
                    id: valueLabel

                    color: Colours.palette.m3outline
                    font: Tokens.font.body.small
                }
            }

            CustomMouseArea {
                function onWheel(event: WheelEvent): void {
                    if (event.angleDelta.y > 0)
                        root.moved(Math.min(root.to, root.value + root.stepSize));
                    else if (event.angleDelta.y < 0)
                        root.moved(Math.max(root.from, root.value - root.stepSize));
                }

                Layout.fillWidth: true
                implicitHeight: Tokens.padding.medium * 2

                StyledSlider {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    implicitHeight: parent.implicitHeight

                    radius: Tokens.rounding.small
                    value: root.position
                    enabled: root.enabled
                    onInteraction: v => root.moved(root.valueAt(v))
                }
            }
        }
    }
}
