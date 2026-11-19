pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth
import Caelestia.Config
import Caelestia.I18n
import Caelestia.State
import qs.components
import qs.components.controls
import qs.services
import qs.utils
import qs.modules.background

// --- Quick toggles: Wi-Fi, Bluetooth, sound, microphone, do not disturb, keep awake and game mode, switched
// straight from the desktop. Round buttons in a grid or a row, or larger tiles that also say what each is
// doing. They drive the same services as the utilities panel's toggles, so either one shows the other's change ---
WidgetCard {
    id: tog

    readonly property string style: tog.variant === "row" || tog.variant === "tiles" ? tog.variant : "grid"

    // In the order every style lays them out. Game mode comes last, where the grid and the tiles give it the
    // wide slot their seventh place leaves
    readonly property list<string> toggles: ["wifi", "bluetooth", "sound", "mic", "dnd", "awake", "game"]

    function isOn(id: string): bool {
        switch (id) {
        case "wifi":
            return Nmcli.wifiEnabled;
        case "bluetooth":
            return Bluetooth.defaultAdapter?.enabled ?? false;
        case "sound":
            return !Audio.silent;
        case "mic":
            return !Audio.sourceMuted;
        case "dnd":
            return PersistentState.doNotDisturb;
        case "awake":
            return IdleInhibitor.active;
        case "game":
            return GameMode.enabled;
        }
        return false;
    }

    // Nothing to switch: no Bluetooth adapter, or no output or input device at all
    function isAvailable(id: string): bool {
        if (id === "bluetooth")
            return !!Bluetooth.defaultAdapter;
        if (id === "sound")
            return !!Audio.sink?.audio;
        if (id === "mic")
            return !!Audio.source?.audio;
        return true;
    }

    function toggle(id: string): void {
        switch (id) {
        case "wifi":
            Nmcli.toggleWifi();
            break;
        case "bluetooth":
            {
                const adapter = Bluetooth.defaultAdapter;
                if (adapter)
                    adapter.enabled = !adapter.enabled;
                break;
            }
        case "sound":
            Audio.toggleMuted();
            break;
        case "mic":
            {
                const audio = Audio.source?.audio;
                if (audio)
                    audio.muted = !audio.muted;
                break;
            }
        case "dnd":
            PersistentState.doNotDisturb = !PersistentState.doNotDisturb;
            break;
        case "awake":
            // On is the strongest mode, the one that holds off the lock screen as well as sleep: a desktop
            // switch is for "leave the screen alone", and the utilities panel offers the finer steps
            IdleInhibitor.mode = IdleInhibitor.active ? IdleInhibitor.off : IdleInhibitor.preventLockAndSleepMode;
            break;
        case "game":
            GameMode.enabled = !GameMode.enabled;
            break;
        }
    }

    function iconFor(id: string): string {
        const on = tog.isOn(id);
        switch (id) {
        case "wifi":
            return on ? "wifi" : "wifi_off";
        case "bluetooth":
            return on ? "bluetooth" : "bluetooth_disabled";
        case "sound":
            return on ? "volume_up" : "volume_off";
        case "mic":
            return on ? "mic" : "mic_off";
        case "dnd":
            return "do_not_disturb_on";
        case "awake":
            return "coffee";
        case "game":
            return "sports_esports";
        }
        return "toggle_on";
    }

    function labelFor(id: string): string {
        switch (id) {
        case "wifi":
            return Tr.tr("Wi-Fi");
        case "bluetooth":
            return Tr.tr("Bluetooth");
        case "sound":
            return Tr.tr("Sound");
        case "mic":
            return Tr.tr("Microphone");
        case "dnd":
            return Tr.tr("Do not disturb");
        case "awake":
            return Tr.trCtx("Keep awake", "idle inhibitor");
        case "game":
            return Tr.tr("Game mode");
        }
        return "";
    }

    // What the tiles say under the name: the network or the level where there is one, on or off otherwise
    function stateFor(id: string): string {
        if (!tog.isAvailable(id))
            return Tr.tr("Unavailable");
        const on = tog.isOn(id);
        if (id === "wifi" && on && Nmcli.active)
            return Nmcli.active.ssid;
        if (id === "bluetooth" && on) {
            const connected = [...Bluetooth.devices.values].filter(d => d.state === BluetoothDeviceState.Connected).length;
            // TRANSLATORS: %1 = how many Bluetooth devices are connected
            return connected > 0 ? Tr.tr("%1 connected").arg(connected) : Tr.tr("On");
        }
        if (id === "sound")
            return on ? Strings.percentOne(Audio.volume) : Tr.tr("Muted");
        if (id === "mic")
            return on ? Strings.percentOne(Audio.sourceVolume) : Tr.tr("Muted");
        return on ? Tr.tr("On") : Tr.tr("Off");
    }

    title: tog.style === "row" ? "" : Tr.tr("Quick toggles")
    icon: "toggle_on"
    padding: tog.style === "row" ? Tokens.padding.large : Tokens.padding.largeIncreased

    // Grid: six round switches in two rows of three, with game mode as a wide switch under them
    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: tog.style === "grid"
        spacing: Tokens.spacing.medium

        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 3
            rowSpacing: Tokens.spacing.medium
            columnSpacing: Tokens.spacing.medium

            Repeater {
                model: tog.style === "grid" ? tog.toggles.slice(0, 6) : []

                Item {
                    id: slot

                    required property string modelData

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    // A floor rather than the button's own size, which is worked out from the slot's
                    implicitWidth: 40
                    implicitHeight: 40

                    RoundToggle {
                        id: roundToggle

                        anchors.centerIn: parent
                        toggleId: slot.modelData
                        size: Math.min(slot.width, slot.height)
                    }
                }
            }
        }

        WideToggle {
            Layout.fillWidth: true
            toggleId: "game"
        }
    }

    // Row: all seven as one line of round switches, evenly spread
    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: tog.style === "row"
        spacing: 0

        Repeater {
            model: tog.style === "row" ? tog.toggles : []

            Item {
                id: rowSlot

                required property string modelData

                Layout.fillWidth: true
                Layout.fillHeight: true
                implicitWidth: 32
                implicitHeight: 32

                RoundToggle {
                    id: rowToggle

                    anchors.centerIn: parent
                    toggleId: rowSlot.modelData
                    size: Math.min(rowSlot.height, rowSlot.width - Tokens.spacing.small)
                }
            }
        }
    }

    // Tiles: rectangles in two columns with the name and what each is doing, game mode across the bottom
    GridLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: tog.style === "tiles"
        columns: 2
        rowSpacing: Tokens.spacing.small
        columnSpacing: Tokens.spacing.small
        uniformCellWidths: true
        uniformCellHeights: true

        Repeater {
            model: tog.style === "tiles" ? tog.toggles : []

            TileToggle {
                required property string modelData
                required property int index

                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.columnSpan: index === 6 ? 2 : 1
                toggleId: modelData
            }
        }
    }

    component RoundToggle: IconButton {
        id: round

        property string toggleId
        property real size: 48

        implicitWidth: size
        implicitHeight: size
        // Same surface as the utilities panel's switches, so the two read as the same control
        inactiveColour: Colours.layer(Colours.palette.m3surfaceContainerHighest, 2)
        font: Tokens.font.icon.medium
        isToggle: true
        isRound: true
        shapeMorph: true
        disabled: !tog.isAvailable(round.toggleId)
        checked: tog.isOn(round.toggleId)
        icon: tog.iconFor(round.toggleId)
        onClicked: tog.toggle(round.toggleId)
    }

    component WideToggle: ButtonBase {
        id: wide

        property string toggleId

        implicitWidth: wideRow.implicitWidth + Tokens.padding.large * 2
        implicitHeight: wideRow.implicitHeight + Tokens.padding.small * 2
        isToggle: true
        isRound: true
        activeColour: Colours.palette.m3primary
        inactiveColour: Colours.layer(Colours.palette.m3surfaceContainerHighest, 2)
        activeOnColour: Colours.palette.m3onPrimary
        inactiveOnColour: Colours.palette.m3onSurfaceVariant
        disabled: !tog.isAvailable(wide.toggleId)
        checked: tog.isOn(wide.toggleId)
        onClicked: tog.toggle(wide.toggleId)

        RowLayout {
            id: wideRow

            anchors.fill: parent
            anchors.leftMargin: Tokens.padding.large
            anchors.rightMargin: Tokens.padding.large
            spacing: Tokens.spacing.small

            MaterialIcon {
                text: tog.iconFor(wide.toggleId)
                color: wide.onColour
                fill: wide.internalChecked ? 1 : 0
                fontStyle: Tokens.font.icon.medium
            }

            StyledText {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: tog.labelFor(wide.toggleId)
                color: wide.onColour
                font: Tokens.font.label.builders.medium.weight(Font.DemiBold).build()
            }

            StyledText {
                text: wide.internalChecked ? Tr.tr("On") : Tr.tr("Off")
                color: wide.onColour
                opacity: 0.8
                font: Tokens.font.label.medium
            }
        }
    }

    component TileToggle: ButtonBase {
        id: tile

        property string toggleId

        implicitWidth: tileCol.implicitWidth + Tokens.padding.medium * 2
        implicitHeight: tileCol.implicitHeight + Tokens.padding.extraSmall * 2
        isToggle: true
        pressedRadius: Tokens.rounding.small
        checkedRadius: Tokens.rounding.large
        defaultRadius: Tokens.rounding.large
        activeColour: Colours.palette.m3primary
        inactiveColour: Colours.layer(Colours.palette.m3surfaceContainerHighest, 2)
        activeOnColour: Colours.palette.m3onPrimary
        inactiveOnColour: Colours.palette.m3onSurface
        disabled: !tog.isAvailable(tile.toggleId)
        checked: tog.isOn(tile.toggleId)
        onClicked: tog.toggle(tile.toggleId)

        RowLayout {
            id: tileCol

            anchors.fill: parent
            anchors.leftMargin: Tokens.padding.medium
            anchors.rightMargin: Tokens.padding.medium
            spacing: Tokens.spacing.small

            MaterialIcon {
                text: tog.iconFor(tile.toggleId)
                color: tile.onColour
                fill: tile.internalChecked ? 1 : 0
                fontStyle: Tokens.font.icon.medium
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: tog.labelFor(tile.toggleId)
                    color: tile.onColour
                    font: Tokens.font.label.builders.medium.weight(Font.DemiBold).build()
                }

                StyledText {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: tog.stateFor(tile.toggleId)
                    color: tile.onColour
                    opacity: 0.75
                    font: Tokens.font.label.small
                }
            }
        }
    }
}
