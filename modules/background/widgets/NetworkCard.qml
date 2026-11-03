pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.modules.background

// --- Network: the download and upload rates, each with a bar against the busiest reading on the card ---
WidgetCard {
    id: net

    // Sampled in services/WidgetData.qml rather than here: the card is unloaded whenever windows hide the
    // desktop, and a card that came back would otherwise start with nothing to scale its bars against
    readonly property real down: WidgetData.down
    readonly property real up: WidgetData.up
    // The busiest reading either direction has seen recently, which is what the bars are measured against.
    // Never zero, so an idle link draws empty bars instead of dividing by nothing
    readonly property real peak: Math.max(1, WidgetData.downHistory.concat(WidgetData.upHistory).reduce((m, v) => Math.max(m, v), 0))

    title: Tr.tr("Network")
    icon: "swap_vert"

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.small

        Speed {
            icon: "download"
            label: Tr.tr("Download")
            value: net.down
            colour: Colours.palette.m3primary
        }

        Speed {
            icon: "upload"
            label: Tr.tr("Upload")
            value: net.up
            colour: Colours.palette.m3tertiary
        }
    }

    component Speed: ColumnLayout {
        id: speed

        property string icon
        property string label
        property real value
        property color colour

        Layout.fillWidth: true
        spacing: Tokens.spacing.extraSmall

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.extraSmall

            MaterialIcon {
                text: speed.icon
                color: speed.colour
                fontStyle: Tokens.font.icon.small
            }

            StyledText {
                Layout.fillWidth: true
                text: speed.label
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.small
            }

            StyledText {
                text: Units.formatBytes(speed.value, true)
                color: Colours.palette.m3onSurface
                font: Tokens.font.label.medium
            }
        }

        StyledRect {
            Layout.fillWidth: true
            implicitHeight: 4
            radius: Tokens.rounding.full
            color: Colours.palette.m3surfaceContainerHighest

            StyledRect {
                width: parent.width * Math.max(0, Math.min(1, speed.value / net.peak))
                height: parent.height
                radius: Tokens.rounding.full
                color: speed.colour
            }
        }
    }
}
