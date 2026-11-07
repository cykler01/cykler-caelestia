pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.utils
import qs.modules.background

// --- Bluetooth: the charge left in each connected device that reports one ---
//
// The devices are read straight from BlueZ through Quickshell rather than sampled: a battery reading only
// changes every minute or so, so there is nothing here worth caching the way the system card does.
WidgetCard {
    id: bt

    readonly property var connected: [...Bluetooth.devices.values].filter(d => d.state === BluetoothDeviceState.Connected)
    // Not every device reports a charge (adapters, some keyboards), so only the ones with a reading are listed.
    // Flattest first, which puts whatever needs charging at the top of the card
    readonly property var devices: bt.connected.filter(d => d.batteryAvailable).sort((a, b) => (a.battery - b.battery) || (a.name ?? "").localeCompare(b.name ?? ""))
    readonly property bool adapterOn: Bluetooth.defaultAdapter?.enabled ?? false

    title: Tr.tr("Bluetooth")
    icon: "bluetooth"

    // Scrolls rather than growing the card, since the desktop grid gave it a fixed footprint: a handful of
    // connected devices is common and the card should not spill over the widget below it
    ListView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 80
        visible: bt.devices.length > 0
        clip: true
        spacing: Tokens.spacing.small
        model: bt.devices

        delegate: RowLayout {
            id: device

            required property BluetoothDevice modelData

            readonly property bool low: device.modelData.battery < 0.2

            width: ListView.view.width
            spacing: Tokens.spacing.small

            MaterialIcon {
                text: Icons.getBluetoothIcon(device.modelData.icon ?? "")
                color: device.low ? Colours.palette.m3error : Colours.palette.m3primary
                fontStyle: Tokens.font.icon.small
            }

            StyledText {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: device.modelData.name || Tr.tr("Unknown device")
                color: Colours.palette.m3onSurface
                font: Tokens.font.label.medium
            }

            StyledText {
                text: Strings.percentOne(device.modelData.battery)
                color: device.low ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.small
            }

            MaterialIcon {
                text: Icons.getBatteryIcon(device.modelData.battery)
                color: device.low ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
                fontStyle: Tokens.font.icon.small
            }
        }
    }

    StyledText {
        Layout.fillWidth: true
        Layout.fillHeight: true
        verticalAlignment: Text.AlignVCenter
        visible: bt.devices.length === 0
        wrapMode: Text.Wrap
        // Three different nothings: the radio is off, nothing is connected, or what is connected has no
        // battery to report
        text: !bt.adapterOn ? Tr.tr("Bluetooth is off") : bt.connected.length === 0 ? Tr.tr("No connected devices") : Tr.tr("No battery readings")
        color: Colours.palette.m3outline
        font: Tokens.font.label.medium
    }
}
