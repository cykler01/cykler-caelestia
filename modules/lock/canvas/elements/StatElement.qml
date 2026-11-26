import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.utils

// One reading for a tile: an icon at the top, a big value and what it is under it. Battery falls
// back to the uptime on a machine without one
ColumnLayout {
    id: root

    property real s: 1

    property var lock: null
    property var opts: ({})

    readonly property var battery: UPower.displayDevice
    readonly property bool charging: [UPowerDeviceState.Charging, UPowerDeviceState.FullyCharged, UPowerDeviceState.PendingCharge].includes(battery.state)
    readonly property string metric: opts.metric === "battery" && !battery.isLaptopBattery ? "uptime" : (opts.metric ?? "battery")

    readonly property var reading: {
        switch (root.metric) {
        case "battery":
            return {
                icon: Icons.getBatteryIcon(root.battery.percentage, root.charging),
                value: Strings.percentOne(root.battery.percentage),
                label: root.charging ? Tr.tr("Charging") : Tr.tr("Battery")
            };
        case "weather":
            return {
                icon: Weather.cc ? Weather.icon : "cloud_off",
                value: Weather.cc ? Weather.temp : "--",
                label: Weather.cc ? Weather.description : Tr.tr("No weather")
            };
        case "day":
            {
                const now = Time.date;
                const start = new Date(now.getFullYear(), 0, 0);
                const day = Math.floor((now - start) / 86400000);
                return {
                    icon: "event",
                    // TRANSLATORS: %1 = the day of the year (1-366)
                    value: Tr.tr("Day %1").arg(day),
                    label: Time.format("yyyy")
                };
            }
        default:
            return {
                icon: "schedule",
                value: SysInfo.uptimeShort.split(",")[0],
                label: Tr.tr("Uptime")
            };
        }
    }

    spacing: Tokens.spacing.small * root.s

    MaterialIcon {
        text: root.reading.icon
        color: Colours.palette.m3primary
        fontStyle: Tokens.font.icon.builders.large.scale(root.s).build()
    }

    StyledText {
        Layout.topMargin: Tokens.spacing.medium * root.s
        text: root.reading.value
        color: Colours.palette.m3onSurface
        font: Tokens.font.headline.builders.medium.scale(root.s).weight(Font.DemiBold).build()
    }

    StyledText {
        Layout.maximumWidth: 200 * root.s
        text: root.reading.label
        color: Colours.palette.m3onSurfaceVariant
        font: Tokens.font.label.builders.large.scale(root.s).build()
        elide: Text.ElideRight
    }
}
