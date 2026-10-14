pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.utils

// Wi-Fi / ethernet status, mirroring the sidebar's own network popout state - the active
// access point when on wireless, the connected ethernet device otherwise, and a disabled
// message when the radio is off or nothing is plugged in
StyledRect {
    id: root

    readonly property Nmcli.AccessPoint wifi: Nmcli.active
    readonly property Nmcli.EthernetDevice ethernet: Nmcli.activeEthernet
    readonly property bool hasWifi: !!wifi
    readonly property bool hasEthernet: !!ethernet && ethernet.connected
    readonly property string title: hasWifi ? wifi.ssid : hasEthernet ? Tr.tr("Wired") : Nmcli.wifiEnabled ? Tr.tr("Not connected") : Tr.tr("Wi-Fi off")
    // 0..100 signal strength, shown only on wireless
    readonly property int strength: wifi?.strength ?? 0

    implicitHeight: row.implicitHeight + Tokens.padding.large * 2
    radius: Tokens.rounding.extraLarge
    color: Colours.tPalette.m3surfaceContainer
    clip: true

    RowLayout {
        id: row

        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.medium

        MaterialIcon {
            text: root.hasEthernet ? "cable" : root.hasWifi ? Icons.getNetworkIcon(root.strength) : "wifi_off"
            color: Colours.palette.m3primary
            fontStyle: Tokens.font.icon.large
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.extraSmall

            StyledText {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                horizontalAlignment: Text.AlignHCenter
                text: root.title
                color: Colours.palette.m3onSurface
                font: Tokens.font.title.builders.medium.weight(Font.DemiBold).build()
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                horizontalAlignment: Text.AlignHCenter
                text: root.hasWifi ? Tr.tr("%1% signal").arg(root.strength) : root.hasEthernet ? Tr.tr("Connected") : root.title
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.medium
                elide: Text.ElideRight
            }
        }
    }
}
