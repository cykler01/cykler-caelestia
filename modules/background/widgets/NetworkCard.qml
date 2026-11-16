pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import Caelestia.Services
import qs.components
import qs.services
import qs.utils
import qs.modules.background

// --- Network: the download and upload rates, each with a bar against the busiest reading on the card. The
// graph style draws the last minute of both, the details style says what the machine is connected to, and the
// compact style is just the two rates ---
WidgetCard {
    id: net

    readonly property string style: net.variant === "graph" || net.variant === "details" || net.variant === "compact" ? net.variant : "default"

    // Sampled in services/WidgetData.qml rather than here: the card is unloaded whenever windows hide the
    // desktop, and a card that came back would otherwise start with nothing to scale its bars against.
    // WidgetData only samples while a network card is placed, though, so a card shown anywhere else - the
    // Add-widget picker - samples for itself instead of sitting at zero
    readonly property bool sampling: !WidgetData.wantsNetwork
    property var ownDownHistory: []
    property var ownUpHistory: []
    readonly property var downHistory: net.sampling ? net.ownDownHistory : WidgetData.downHistory
    readonly property var upHistory: net.sampling ? net.ownUpHistory : WidgetData.upHistory
    readonly property real down: net.sampling ? (net.ownDownHistory[net.ownDownHistory.length - 1] ?? 0) : WidgetData.down
    readonly property real up: net.sampling ? (net.ownUpHistory[net.ownUpHistory.length - 1] ?? 0) : WidgetData.up
    // The busiest reading either direction has seen recently, which is what the bars are measured against.
    // Never zero, so an idle link draws empty bars instead of dividing by nothing
    readonly property real peak: Math.max(1, net.downHistory.concat(net.upHistory).reduce((m, v) => Math.max(m, v), 0))

    // The connection, for the details style. Wi-Fi when there is an access point in use, the wire otherwise
    readonly property var accessPoint: Nmcli.active
    readonly property var ethernet: Nmcli.activeEthernet
    readonly property bool wired: !net.accessPoint && !!net.ethernet
    readonly property bool online: !!net.accessPoint || !!net.ethernet
    readonly property string connectionName: net.accessPoint?.ssid ?? net.ethernet?.connection ?? ""
    readonly property string address: (net.wired ? Nmcli.ethernetDeviceDetails?.ipAddress : Nmcli.wirelessDeviceDetails?.ipAddress) ?? ""

    function band(mhz: int): string {
        if (mhz >= 5925)
            return Tr.tr("6 GHz");
        if (mhz >= 4900)
            return Tr.tr("5 GHz");
        return mhz > 0 ? Tr.tr("2.4 GHz") : "";
    }

    // The details style names the connection in its header, the way the weather card names the city
    title: net.style === "compact" ? "" : net.style === "details" && net.online ? net.connectionName : Tr.tr("Network")
    icon: net.style !== "details" ? "swap_vert" : net.wired ? "lan" : net.accessPoint ? Icons.getNetworkIcon(net.accessPoint.strength) : "wifi_off"
    // The compact strip is two cells tall, and the usual margin would leave its figures no room across
    padding: net.style === "compact" ? Tokens.padding.large : Tokens.padding.largeIncreased

    // Nmcli reads the address once when it starts and again when the connection changes. A details card that
    // arrives after a quiet start, or before Nmcli has found the connection, may find none yet, so it asks for
    // the one it is about to show
    function requestAddress(): void {
        if (net.style !== "details" || net.address !== "")
            return;
        if (net.wired)
            Nmcli.getEthernetDeviceDetails("", () => {});
        else if (net.accessPoint)
            // The interface list is what the details are looked up by, and it may not have been read yet
            Nmcli.getWirelessInterfaces(() => Nmcli.getWirelessDeviceDetails("", () => {}));
    }

    Component.onCompleted: requestAddress()
    onOnlineChanged: requestAddress()

    ServiceRef {
        service: net.sampling ? NetworkUsage : null
    }

    Timer {
        interval: WidgetData.sampleInterval
        running: net.sampling
        repeat: true
        onTriggered: {
            net.ownDownHistory = WidgetData.pushSpeed(net.ownDownHistory, NetworkUsage.downloadSpeed ?? 0);
            net.ownUpHistory = WidgetData.pushSpeed(net.ownUpHistory, NetworkUsage.uploadSpeed ?? 0);
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        visible: net.style === "default"
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

    // Graph: the two rates above, and their last minute drawn back to back along one baseline - download
    // rising from it, upload hanging under it. Each half is scaled to its own busiest moment, since an upload
    // is usually a sliver of the download and would otherwise never leave the line
    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: net.style === "graph"
        spacing: Tokens.spacing.small

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.medium

            Rate {
                icon: "arrow_downward"
                label: Tr.tr("Download")
                value: net.down
                colour: Colours.palette.m3primary
            }

            Item {
                Layout.fillWidth: true
            }

            Rate {
                icon: "arrow_upward"
                label: Tr.tr("Upload")
                value: net.up
                colour: Colours.palette.m3tertiary
                mirrored: true
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 40

            SystemSparkline {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: parent.height / 2 - 1
                values: net.style === "graph" ? net.downHistory : []
                maximum: 0
                colour: Colours.palette.m3primary
                lineWidth: 1.5
            }

            StyledRect {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                implicitHeight: 1
                color: Qt.alpha(Colours.palette.m3outlineVariant, 0.6)
            }

            SystemSparkline {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: parent.height / 2 - 1
                values: net.style === "graph" ? net.upHistory : []
                maximum: 0
                inverted: true
                colour: Colours.palette.m3tertiary
                lineWidth: 1.5
            }
        }
    }

    // Details: what the machine is on, how well, at what address, and what is going over it now
    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: net.style === "details"
        spacing: Tokens.spacing.medium

        StyledText {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: {
                if (net.wired)
                    return [Tr.tr("Ethernet"), Nmcli.ethernetSpeed].filter(s => s).join(" · ");
                if (net.accessPoint)
                    return [Tr.tr("Wi-Fi"), net.band(net.accessPoint.frequency), net.accessPoint.isSecure ? Tr.tr("Secured") : Tr.tr("Open")].filter(s => s).join(" · ");
                return Nmcli.wifiEnabled ? Tr.tr("Not connected") : Tr.tr("Wi-Fi is off");
            }
            color: net.online ? Colours.palette.m3onSurfaceVariant : Colours.palette.m3outline
            font: Tokens.font.body.medium
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            rowSpacing: Tokens.spacing.small
            columnSpacing: Tokens.spacing.medium
            uniformCellWidths: true

            Fact {
                icon: net.wired ? "cable" : "signal_cellular_alt"
                label: net.wired ? Tr.tr("Link") : Tr.tr("Signal")
                value: net.wired ? (Nmcli.ethernetSpeed || Tr.tr("Up")) : net.accessPoint ? Strings.percent(net.accessPoint.strength) : "–"
            }

            Fact {
                icon: "lan"
                label: Tr.tr("Address")
                value: net.online && net.address !== "" ? net.address : "–"
            }

            Fact {
                icon: "arrow_downward"
                label: Tr.tr("Download")
                value: Units.formatBytes(net.down, true)
                accent: Colours.palette.m3primary
            }

            Fact {
                icon: "arrow_upward"
                label: Tr.tr("Upload")
                value: Units.formatBytes(net.up, true)
                accent: Colours.palette.m3tertiary
            }
        }
    }

    // Compact: the two rates stacked on the left, and both of their last minute in miniature beside them
    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: net.style === "compact"
        spacing: Tokens.spacing.medium

        ColumnLayout {
            Layout.alignment: Qt.AlignVCenter
            spacing: 0

            CompactRate {
                icon: "arrow_downward"
                value: net.down
                colour: Colours.palette.m3primary
            }

            CompactRate {
                icon: "arrow_upward"
                value: net.up
                colour: Colours.palette.m3tertiary
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            SystemSparkline {
                anchors.fill: parent
                values: net.style === "compact" ? net.downHistory : []
                maximum: Math.max(1, ...net.downHistory, ...net.upHistory)
                colour: Colours.palette.m3primary
                lineWidth: 1.5
            }

            SystemSparkline {
                anchors.fill: parent
                values: net.style === "compact" ? net.upHistory : []
                maximum: Math.max(1, ...net.downHistory, ...net.upHistory)
                colour: Colours.palette.m3tertiary
                lineWidth: 1.5
            }
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

    // A rate over the graph: a dot of the line's colour, what it is, and the figure. The upload one is
    // mirrored to the right edge, so the two read as the two ends of the graph under them
    component Rate: ColumnLayout {
        id: rate

        property string icon
        property string label
        property real value
        property color colour
        property bool mirrored

        spacing: 0

        RowLayout {
            Layout.alignment: rate.mirrored ? Qt.AlignRight : Qt.AlignLeft
            layoutDirection: rate.mirrored ? Qt.RightToLeft : Qt.LeftToRight
            spacing: Tokens.spacing.extraSmall

            MaterialIcon {
                text: rate.icon
                color: rate.colour
                fontStyle: Tokens.font.icon.small
            }

            StyledText {
                text: rate.label
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.small
            }
        }

        StyledText {
            Layout.alignment: rate.mirrored ? Qt.AlignRight : Qt.AlignLeft
            text: Units.formatBytes(rate.value, true)
            color: Colours.palette.m3onSurface
            font: Tokens.font.title.builders.small.weight(Font.DemiBold).build()
        }
    }

    // One fact about the connection: a small glyph, what it is, and its value under it
    component Fact: RowLayout {
        id: fact

        property string icon
        property string label
        property string value
        property color accent: Colours.palette.m3secondary

        Layout.fillWidth: true
        spacing: Tokens.spacing.small

        MaterialIcon {
            Layout.alignment: Qt.AlignVCenter
            text: fact.icon
            color: fact.accent
            fontStyle: Tokens.font.icon.small
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: fact.label
                color: Colours.palette.m3outline
                font: Tokens.font.label.small
            }

            StyledText {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: fact.value
                color: Colours.palette.m3onSurface
                font: Tokens.font.label.medium
            }
        }
    }

    component CompactRate: RowLayout {
        id: compactRate

        property string icon
        property real value
        property color colour

        spacing: Tokens.spacing.extraSmall

        MaterialIcon {
            text: compactRate.icon
            color: compactRate.colour
            fontStyle: Tokens.font.icon.small
        }

        StyledText {
            text: Units.formatBytes(compactRate.value, true)
            color: Colours.palette.m3onSurface
            font: Tokens.font.label.builders.medium.weight(Font.DemiBold).build()
        }
    }
}
