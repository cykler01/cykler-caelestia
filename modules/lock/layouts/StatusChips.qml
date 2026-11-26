pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import Caelestia.Config
import Caelestia.I18n
import Caelestia.State
import qs.components
import qs.services
import qs.utils

// A row of small status pills for the layouts that have no centre card to hang this off (split,
// sidebar, minimal). Which pills show and in what order is Config.lock.statusEntries, edited in
// Nexus > Lock screen > Layout; the first entry sits outermost. Each pill also hides itself when
// there's nothing to say: no battery on a desktop, no Bluetooth adapter, nothing playing
RowLayout {
    id: root

    property real uiScale: 1

    readonly property var battery: UPower.displayDevice
    readonly property bool charging: [UPowerDeviceState.Charging, UPowerDeviceState.FullyCharged, UPowerDeviceState.PendingCharge].includes(battery.state)

    readonly property Nmcli.AccessPoint wifi: Nmcli.active
    readonly property Nmcli.EthernetDevice ethernet: Nmcli.activeEthernet
    readonly property bool hasEthernet: !!ethernet && ethernet.connected

    readonly property var btConnected: Bluetooth.devices.values.filter(d => d.connected)

    readonly property list<string> knownIds: ["battery", "network", "bluetooth", "volume", "mic", "vpn", "keyboard", "notifs", "media", "power", "uptime"]

    // Every entry's enabled flag is read here so the row is rebuilt whenever one is switched
    readonly property var entries: {
        const values = Config.lock.statusEntries?.values ?? [];
        for (const e of values)
            void e.enabled;
        if (values.length === 0 && !Config.lock.statusEntries)
            // Plugin without the list yet: the original three
            return [{ id: "battery" }, { id: "network" }, { id: "bluetooth" }];
        return values.filter(e => e.enabled && root.knownIds.includes(e.id));
    }

    // What a pill shows: { shown, icon, text, colour (optional) }. Only the branch for the asked
    // id runs, so a pill only ever watches the services it actually needs
    function infoFor(id: string): var {
        switch (id) {
        case "battery":
            return {
                shown: root.battery.isLaptopBattery,
                icon: Icons.getBatteryIcon(root.battery.percentage, root.charging),
                text: Strings.percentOne(root.battery.percentage),
                colour: root.battery.percentage < 0.2 && !root.charging ? Colours.palette.m3error : root.charging ? Colours.palette.m3tertiary : undefined
            };
        case "network":
            return {
                shown: true,
                icon: root.hasEthernet ? "cable" : root.wifi ? Icons.getNetworkIcon(root.wifi.strength) : "wifi_off",
                text: root.wifi ? root.wifi.ssid : root.hasEthernet ? Tr.tr("Wired") : Nmcli.wifiEnabled ? Tr.tr("Not connected") : Tr.tr("Wi-Fi off")
            };
        case "bluetooth":
            {
                const on = Bluetooth.defaultAdapter?.enabled ?? false;
                const n = root.btConnected.length;
                return {
                    shown: !!Bluetooth.defaultAdapter,
                    icon: !on ? "bluetooth_disabled" : n > 0 ? "bluetooth_connected" : "bluetooth",
                    // TRANSLATORS: %1 = number of connected Bluetooth devices
                    text: !on ? Tr.tr("Bluetooth off") : n === 1 ? root.btConnected[0].name : n > 1 ? Tr.tr("%1 devices").arg(n) : Tr.tr("Bluetooth on")
                };
            }
        case "volume":
            return {
                shown: !!Audio.sink,
                icon: Audio.silent ? "volume_off" : Audio.volume < 0.5 ? "volume_down" : "volume_up",
                text: Audio.muted ? Tr.tr("Muted") : `${Math.round(Audio.volume * 100)}%`
            };
        case "mic":
            return {
                shown: !!Audio.source,
                icon: Audio.sourceMuted ? "mic_off" : "mic",
                text: Audio.sourceMuted ? Tr.tr("Mic muted") : Tr.tr("Mic on"),
                colour: Audio.sourceMuted ? Colours.palette.m3error : undefined
            };
        case "vpn":
            return {
                shown: true,
                icon: VPN.connected ? "vpn_lock" : "vpn_key_off",
                text: VPN.connected ? (VPN.status?.server || Tr.tr("VPN on")) : Tr.tr("VPN off")
            };
        case "keyboard":
            return {
                shown: true,
                icon: Hypr.capsLock ? "keyboard_capslock_badge" : "keyboard",
                // TRANSLATORS: %1 = short keyboard layout name, e.g. "US"
                text: Hypr.capsLock ? Tr.tr("%1 · Caps").arg(Hypr.kbLayout.toUpperCase()) : Hypr.kbLayout.toUpperCase(),
                colour: Hypr.capsLock ? Colours.palette.m3tertiary : undefined
            };
        case "notifs":
            {
                const n = Notifs.notClosed.length;
                return {
                    shown: true,
                    icon: PersistentState.doNotDisturb ? "notifications_off" : n > 0 ? "notifications_unread" : "notifications",
                    text: PersistentState.doNotDisturb ? Tr.tr("Do not disturb") : n > 0 ? Tr.trN("%n notification", "%n notifications", n) : Tr.tr("No notifications")
                };
            }
        case "media":
            {
                const p = Players.active;
                const title = p?.trackTitle ?? "";
                return {
                    shown: !!p && title !== "",
                    icon: p?.isPlaying ? "music_note" : "pause",
                    text: p?.trackArtist ? `${title} · ${p.trackArtist}` : title
                };
            }
        case "power":
            return {
                shown: true,
                icon: PowerProfiles.profile === PowerProfile.PowerSaver ? "energy_savings_leaf" : PowerProfiles.profile === PowerProfile.Performance ? "rocket_launch" : "balance",
                text: PowerProfiles.profile === PowerProfile.PowerSaver ? Tr.tr("Power saver") : PowerProfiles.profile === PowerProfile.Performance ? Tr.tr("Performance") : Tr.tr("Balanced")
            };
        case "uptime":
            return {
                shown: SysInfo.uptimeShort !== "",
                icon: "schedule",
                // TRANSLATORS: %1 = how long the machine has been up, e.g. "3 hours, 12 minutes"
                text: Tr.tr("Up %1").arg(SysInfo.uptimeShort)
            };
        }
        return {
            shown: false
        };
    }

    visible: root.entries.length > 0
    spacing: Tokens.spacing.small * root.uiScale

    Repeater {
        model: root.entries

        Chip {
            required property var modelData
            readonly property var info: root.infoFor(modelData.id)

            visible: info.shown
            icon: info.icon ?? ""
            text: info.text ?? ""
            iconColour: info.colour ?? Colours.palette.m3primary
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
