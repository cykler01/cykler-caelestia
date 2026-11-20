pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.utils

// Battery, network and Bluetooth as a row of small pills, for the layouts that have no centre
// card to hang this off (split, sidebar, minimal). Each pill hides itself when there's nothing
// to say: no battery on a desktop, no Bluetooth adapter at all
RowLayout {
    id: root

    property real uiScale: 1

    readonly property var battery: UPower.displayDevice
    readonly property bool charging: [UPowerDeviceState.Charging, UPowerDeviceState.FullyCharged, UPowerDeviceState.PendingCharge].includes(battery.state)

    readonly property Nmcli.AccessPoint wifi: Nmcli.active
    readonly property Nmcli.EthernetDevice ethernet: Nmcli.activeEthernet
    readonly property bool hasEthernet: !!ethernet && ethernet.connected

    readonly property var btConnected: Bluetooth.devices.values.filter(d => d.connected)

    visible: Config.lock.statusChips ?? true
    spacing: Tokens.spacing.small * root.uiScale

    Chip {
        visible: root.battery.isLaptopBattery
        icon: Icons.getBatteryIcon(root.battery.percentage, root.charging)
        iconColour: root.battery.percentage < 0.2 && !root.charging ? Colours.palette.m3error : root.charging ? Colours.palette.m3tertiary : Colours.palette.m3primary
        text: Strings.percentOne(root.battery.percentage)
    }

    Chip {
        icon: root.hasEthernet ? "cable" : root.wifi ? Icons.getNetworkIcon(root.wifi.strength) : "wifi_off"
        text: root.wifi ? root.wifi.ssid : root.hasEthernet ? Tr.tr("Wired") : Nmcli.wifiEnabled ? Tr.tr("Not connected") : Tr.tr("Wi-Fi off")
    }

    Chip {
        visible: !!Bluetooth.defaultAdapter
        icon: !Bluetooth.defaultAdapter?.enabled ? "bluetooth_disabled" : root.btConnected.length > 0 ? "bluetooth_connected" : "bluetooth"
        text: {
            if (!Bluetooth.defaultAdapter?.enabled)
                return Tr.tr("Bluetooth off");
            if (root.btConnected.length === 1)
                return root.btConnected[0].name;
            if (root.btConnected.length > 1)
                // TRANSLATORS: %1 = number of connected Bluetooth devices
                return Tr.tr("%1 devices").arg(root.btConnected.length);
            return Tr.tr("Bluetooth on");
        }
    }

    component Chip: StyledRect {
        id: chip

        property string icon
        property string text
        property color iconColour: Colours.palette.m3primary

        implicitWidth: chipRow.implicitWidth + Tokens.padding.large * 2 * root.uiScale
        implicitHeight: chipRow.implicitHeight + Tokens.padding.small * 2 * root.uiScale
        radius: Tokens.rounding.full
        color: Colours.tPalette.m3surfaceContainer

        RowLayout {
            id: chipRow

            anchors.centerIn: parent
            spacing: Tokens.spacing.small * root.uiScale

            MaterialIcon {
                animate: true
                text: chip.icon
                color: chip.iconColour
                fontStyle: Tokens.font.icon.builders.small.scale(root.uiScale).build()
            }

            StyledText {
                Layout.maximumWidth: 220 * root.uiScale
                animate: true
                text: chip.text
                color: Colours.palette.m3onSurface
                font: Tokens.font.label.builders.large.scale(root.uiScale).weight(Font.DemiBold).build()
                elide: Text.ElideRight
            }
        }
    }
}
