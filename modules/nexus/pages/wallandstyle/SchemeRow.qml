import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.nexus.common

// NOTE(fork): a selectable colour scheme, showing the scheme's surface and primary
// colours as a preview. Moved from the launcher's scheme picker.
ConnectedRect {
    id: root

    required property var scheme
    readonly property bool current: root.scheme.name === Colours.scheme && root.scheme.flavour === Colours.flavour

    Layout.fillWidth: true
    implicitHeight: rowLayout.implicitHeight + rowLayout.anchors.margins * 2

    StateLayer {
        onClicked: Schemes.setScheme(root.scheme.name, root.scheme.flavour)
    }

    RowLayout {
        id: rowLayout

        anchors.fill: parent
        anchors.margins: Tokens.padding.medium
        anchors.leftMargin: Tokens.padding.largeIncreased
        anchors.rightMargin: Tokens.padding.largeIncreased
        spacing: Tokens.spacing.medium

        StyledRect {
            id: preview

            implicitWidth: Tokens.padding.extraExtraLarge
            implicitHeight: Tokens.padding.extraExtraLarge

            color: `#${root.scheme.colours.surface}`
            border.width: 1
            border.color: Qt.alpha(`#${root.scheme.colours.outline}`, 0.5)
            radius: Tokens.rounding.full

            Item {
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.right: parent.right

                implicitWidth: parent.implicitWidth / 2
                clip: true

                StyledRect {
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.right: parent.right

                    implicitWidth: preview.implicitWidth
                    color: `#${root.scheme.colours.primary}`
                    radius: Tokens.rounding.full
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                text: root.scheme.flavour
                font: Tokens.font.body.small
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                text: root.scheme.name
                color: Colours.palette.m3outline
                font: Tokens.font.label.small
                elide: Text.ElideRight
            }
        }

        MaterialIcon {
            visible: root.current
            text: "check"
            color: Colours.palette.m3onSurfaceVariant
            fontStyle: Tokens.font.icon.medium
        }
    }
}
