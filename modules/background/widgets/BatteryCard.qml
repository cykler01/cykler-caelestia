pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import Caelestia.Config
import Caelestia.I18n
import Caelestia.Services
import qs.components
import qs.components.controls
import qs.services
import qs.utils
import qs.modules.background

// --- Battery: charge, state, rate and time remaining on a laptop; the GPU's power draw on a desktop. The bar
// style is one wide charge gauge, and the devices style lists every battery in reach: the laptop's, the
// paired phone's and those of connected Bluetooth devices ---
WidgetCard {
    id: bat

    readonly property var dev: UPower.displayDevice
    readonly property bool laptop: dev.isLaptopBattery
    readonly property real pct: dev.percentage
    readonly property bool full: dev.state === UPowerDeviceState.FullyCharged
    readonly property bool charging: dev.state === UPowerDeviceState.Charging || full
    readonly property real rate: Math.abs(dev.changeRate)
    readonly property real seconds: charging ? dev.timeToFull : dev.timeToEmpty
    readonly property bool low: pct < 0.2 && !charging
    readonly property string style: bat.variant === "ring" || bat.variant === "bar" || bat.variant === "devices" ? bat.variant : "default"
    // The ring variant draws the charge as a circle rather than as the bar beside the percentage
    readonly property bool ring: bat.variant === "ring"
    readonly property bool classic: bat.style === "default" || bat.style === "ring"
    readonly property color accent: bat.low ? Colours.palette.m3error : bat.charging ? Colours.palette.m3tertiary : Colours.palette.m3primary

    function duration(secs: real): string {
        if (secs <= 0)
            return "";
        const h = Math.floor(secs / 3600);
        const m = Math.round((secs % 3600) / 60);
        return h > 0 ? Tr.tr("%1 h %2 min").arg(h).arg(m) : Tr.tr("%1 min").arg(m);
    }

    // Every battery the devices style lists, laptop first, then the phone, then Bluetooth flattest first.
    // { name, detail, icon, value, charging }
    readonly property var batteries: {
        if (bat.style !== "devices")
            return [];

        const list = [];
        if (bat.laptop)
            list.push({
                name: Tr.tr("This laptop"),
                detail: bat.full ? Tr.tr("Fully charged") : bat.seconds >= 60 ? (bat.charging ? Tr.tr("Full in %1").arg(bat.duration(bat.seconds)) : Tr.tr("%1 left").arg(bat.duration(bat.seconds))) : bat.charging ? Tr.tr("Charging") : Tr.tr("On battery"),
                icon: "laptop",
                value: bat.pct,
                charging: bat.charging && !bat.full
            });

        // KDE Connect reports -1 until the phone has sent a reading
        for (const phone of KdeConnect.devices.filter(d => (d.batteryCharge ?? -1) >= 0))
            list.push({
                name: phone.name,
                detail: phone.batteryCharging ? Tr.tr("Charging") : Tr.tr("Phone"),
                icon: "smartphone",
                value: phone.batteryCharge / 100,
                charging: phone.batteryCharging
            });

        const bluetooth = [...Bluetooth.devices.values].filter(d => d.state === BluetoothDeviceState.Connected && d.batteryAvailable).sort((a, b) => (a.battery - b.battery) || (a.name ?? "").localeCompare(b.name ?? ""));
        for (const device of bluetooth)
            list.push({
                name: device.name || Tr.tr("Unknown device"),
                detail: Tr.tr("Bluetooth"),
                icon: Icons.getBluetoothIcon(device.icon ?? ""),
                value: device.battery,
                charging: false
            });

        return list;
    }

    // A desktop has no battery of its own, so the classic styles show the graphics card's draw instead and
    // the devices style shows whatever else has one. Hidden only when there is nothing at all to say
    visible: bat.style === "devices" || laptop || Gpu.power > 0
    title: bat.style === "bar" ? "" : bat.style === "devices" ? Tr.tr("Batteries") : laptop ? Tr.tr("Battery") : Tr.tr("Power draw")
    icon: bat.style === "devices" || laptop ? (charging ? "battery_charging_full" : "battery_full") : "bolt"
    padding: bat.style === "bar" ? Tokens.padding.large : Tokens.padding.largeIncreased

    ServiceRef {
        service: bat.style !== "devices" ? Gpu : null
    }

    RowLayout {
        Layout.fillWidth: true
        visible: !bat.laptop && bat.style !== "devices"
        spacing: Tokens.spacing.medium

        StyledText {
            text: `${Math.round(Gpu.power)} W`
            color: Colours.palette.m3onSurface
            font: Tokens.font.headline.builders.medium.weight(Font.DemiBold).build()
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: Tr.tr("Graphics card")
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.medium
            }

            StyledText {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: Gpu.name
                color: Colours.palette.m3outline
                font: Tokens.font.label.small
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        visible: bat.laptop && bat.style === "default"
        spacing: Tokens.spacing.medium

        StyledText {
            text: `${Math.round(bat.pct * 100)}%`
            color: bat.low ? Colours.palette.m3error : Colours.palette.m3onSurface
            font: Tokens.font.headline.builders.medium.weight(Font.DemiBold).build()
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.extraSmall

            StyledText {
                text: bat.full ? Tr.tr("Fully charged") : bat.charging ? Tr.tr("Charging") : Tr.tr("On battery")
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.medium
            }

            StyledRect {
                Layout.fillWidth: true
                implicitHeight: 8
                radius: Tokens.rounding.full
                color: Colours.palette.m3surfaceContainerHighest

                StyledRect {
                    width: parent.width * Math.max(0, Math.min(1, bat.pct))
                    height: parent.height
                    radius: Tokens.rounding.full
                    color: bat.low ? Colours.palette.m3error : bat.charging ? Colours.palette.m3tertiary : Colours.palette.m3primary
                }
            }
        }
    }

    // The ring variant: the charge as a circle on the left, the percentage and state against the right edge
    RowLayout {
        Layout.fillWidth: true
        visible: bat.laptop && bat.style === "ring"
        spacing: Tokens.spacing.medium

        CircularProgress {
            implicitSize: 88
            strokeWidth: 8
            value: bat.pct
            fgColour: bat.accent
            bgColour: Colours.palette.m3surfaceContainerHighest

            // Short and without overshoot, so a reading that changes on its own does not keep redrawing
            Behavior on clampedVal {
                Anim {
                    type: Anim.FastEffects
                }
            }

            // A ring this size reads as a hole without something in it, so the state gets a glyph: a bolt
            // while charging, and a half-empty battery once it is running low
            MaterialIcon {
                anchors.centerIn: parent
                text: bat.charging ? "bolt" : bat.low ? "battery_alert" : "battery_full"
                color: bat.accent
                fontStyle: Tokens.font.icon.builders.medium.build()
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: Tokens.spacing.extraSmall

            StyledText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignRight
                text: `${Math.round(bat.pct * 100)}%`
                color: bat.low ? Colours.palette.m3error : Colours.palette.m3onSurface
                font: Tokens.font.headline.builders.medium.weight(Font.DemiBold).build()
            }

            StyledText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
                text: bat.full ? Tr.tr("Fully charged") : bat.charging ? Tr.tr("Charging") : Tr.tr("On battery")
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.medium
            }
        }
    }

    // Rate and time to empty/full. The row is always there on a laptop and its contents fade out
    // instead of collapsing, so a battery that is full (no rate, no time left to report) keeps the
    // same height and the card does not shrink out from under the widgets below it.
    RowLayout {
        Layout.fillWidth: true
        visible: bat.laptop && bat.classic
        spacing: Tokens.spacing.small

        MaterialIcon {
            opacity: bat.rate > 0 && !bat.full ? 1 : 0
            text: bat.charging ? "bolt" : "trending_down"
            color: bat.charging ? Colours.palette.m3tertiary : Colours.palette.m3primary
            fontStyle: Tokens.font.icon.small
        }

        StyledText {
            opacity: bat.rate > 0 && !bat.full ? 1 : 0
            text: `${bat.charging ? "+" : "−"}${bat.rate.toFixed(1)} W`
            color: Colours.palette.m3onSurface
            font: Tokens.font.label.medium
        }

        Item {
            Layout.fillWidth: true
        }

        StyledText {
            opacity: bat.seconds >= 60 && !bat.full ? 1 : 0
            text: bat.charging ? Tr.tr("Full in %1").arg(bat.duration(bat.seconds)) : Tr.tr("%1 left").arg(bat.duration(bat.seconds))
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.label.medium
        }
    }

    // Bar: the charge as one wide gauge in ten cells, like the cells drawn on a battery, with a terminal at
    // the end. The figure and what the battery is doing sit over it
    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: bat.laptop && bat.style === "bar"
        spacing: Tokens.spacing.small

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.medium

            StyledText {
                text: `${Math.round(bat.pct * 100)}%`
                color: bat.low ? Colours.palette.m3error : Colours.palette.m3onSurface
                font: Tokens.font.headline.builders.medium.weight(Font.DemiBold).build()
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 0

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.extraSmall

                    MaterialIcon {
                        visible: bat.charging && !bat.full
                        text: "bolt"
                        color: bat.accent
                        fontStyle: Tokens.font.icon.small
                    }

                    StyledText {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: bat.full ? Tr.tr("Fully charged") : bat.charging ? Tr.tr("Charging") : Tr.tr("On battery")
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.label.medium
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: text !== ""
                    elide: Text.ElideRight
                    text: {
                        if (bat.full || bat.seconds < 60)
                            return bat.rate > 0 && !bat.full ? `${bat.charging ? "+" : "−"}${bat.rate.toFixed(1)} W` : "";
                        return bat.charging ? Tr.tr("Full in %1").arg(bat.duration(bat.seconds)) : Tr.tr("%1 left").arg(bat.duration(bat.seconds));
                    }
                    color: Colours.palette.m3outline
                    font: Tokens.font.label.small
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.maximumHeight: 22
            spacing: 2

            Repeater {
                model: bat.style === "bar" ? 10 : 0

                StyledRect {
                    id: cell

                    required property int index
                    // How much of this tenth is charged, so the last cell fills part way rather than snapping
                    readonly property real fill: Math.max(0, Math.min(1, bat.pct * 10 - cell.index))

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    // Only the two ends are rounded fully, so the ten read as one bar cut into cells
                    topLeftRadius: cell.index === 0 ? Tokens.rounding.small : 2
                    bottomLeftRadius: cell.index === 0 ? Tokens.rounding.small : 2
                    topRightRadius: cell.index === 9 ? Tokens.rounding.small : 2
                    bottomRightRadius: cell.index === 9 ? Tokens.rounding.small : 2
                    color: Colours.palette.m3surfaceContainerHighest
                    clip: true

                    StyledRect {
                        width: parent.width * cell.fill
                        height: parent.height
                        color: bat.accent
                    }
                }
            }

            // The terminal, lit once the last cell is full
            StyledRect {
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: 1
                Layout.preferredWidth: 4
                Layout.preferredHeight: 10
                topRightRadius: 2
                bottomRightRadius: 2
                color: bat.pct >= 0.995 ? bat.accent : Colours.palette.m3surfaceContainerHighest
            }
        }
    }

    // Devices: one row per battery, a glyph, its name and state, a short bar and the figure. Scrolls rather
    // than growing the card, like the Bluetooth card
    ListView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 60
        visible: bat.style === "devices" && bat.batteries.length > 0
        clip: true
        spacing: Tokens.spacing.small
        interactive: contentHeight > height
        model: bat.batteries

        delegate: RowLayout {
            id: device

            required property var modelData
            readonly property bool low: device.modelData.value < 0.2 && !device.modelData.charging
            readonly property color colour: device.low ? Colours.palette.m3error : device.modelData.charging ? Colours.palette.m3tertiary : Colours.palette.m3primary

            width: ListView.view.width
            spacing: Tokens.spacing.small

            StyledRect {
                implicitWidth: implicitHeight
                implicitHeight: deviceIcon.implicitHeight + Tokens.padding.small * 2
                radius: Tokens.rounding.full
                color: Qt.alpha(device.colour, 0.16)

                MaterialIcon {
                    id: deviceIcon

                    anchors.centerIn: parent
                    text: device.modelData.icon
                    color: device.colour
                    fontStyle: Tokens.font.icon.small
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: device.modelData.name
                    color: Colours.palette.m3onSurface
                    font: Tokens.font.label.medium
                }

                StyledText {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: device.modelData.detail
                    color: Colours.palette.m3outline
                    font: Tokens.font.label.small
                }
            }

            StyledRect {
                implicitWidth: 56
                implicitHeight: 6
                radius: Tokens.rounding.full
                color: Colours.palette.m3surfaceContainerHighest

                StyledRect {
                    width: Math.max(height, parent.width * Math.max(0, Math.min(1, device.modelData.value)))
                    height: parent.height
                    radius: Tokens.rounding.full
                    color: device.colour
                }
            }

            StyledText {
                Layout.preferredWidth: 36
                horizontalAlignment: Text.AlignRight
                text: Strings.percentOne(device.modelData.value)
                color: device.low ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.small
            }
        }
    }

    StyledText {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: bat.style === "devices" && bat.batteries.length === 0
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.Wrap
        text: Tr.tr("No batteries in reach. Connect a Bluetooth device or pair a phone to see its charge here")
        color: Colours.palette.m3outline
        font: Tokens.font.label.medium
    }
}
