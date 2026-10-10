pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.utils

// Laptop battery only - desktops with a GPU power draw have their own reading elsewhere, and
// this card has nothing useful to show without a battery at all
StyledRect {
    id: root

    readonly property var dev: UPower.displayDevice
    readonly property bool charging: [UPowerDeviceState.Charging, UPowerDeviceState.FullyCharged, UPowerDeviceState.PendingCharge].includes(dev.state)
    readonly property bool low: dev.percentage < 0.2 && !charging
    readonly property color accent: low ? Colours.palette.m3error : charging ? Colours.palette.m3tertiary : Colours.palette.m3primary

    visible: dev.isLaptopBattery
    implicitHeight: row.implicitHeight + Tokens.padding.large * 2
    radius: Tokens.rounding.extraLarge
    color: Colours.tPalette.m3surfaceContainer

    RowLayout {
        id: row

        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.medium

        MaterialIcon {
            text: root.charging ? "battery_charging_full" : "battery_full"
            color: root.accent
            fontStyle: Tokens.font.icon.large
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.extraSmall

            StyledText {
                text: Strings.percentOne(root.dev.percentage)
                color: Colours.palette.m3onSurface
                font: Tokens.font.title.builders.medium.weight(Font.DemiBold).build()
            }

            StyledRect {
                Layout.fillWidth: true
                implicitHeight: 6
                radius: Tokens.rounding.full
                color: Colours.palette.m3surfaceContainerHighest

                StyledRect {
                    width: parent.width * Math.max(0, Math.min(1, root.dev.percentage))
                    height: parent.height
                    radius: Tokens.rounding.full
                    color: root.accent
                }
            }
        }

        StyledText {
            text: root.charging ? Tr.tr("Charging") : Tr.tr("On battery")
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.label.medium
        }
    }
}
