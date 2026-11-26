import QtQuick
import Quickshell.Services.UPower
import Caelestia.Config
import qs.services
import qs.utils

// The date, weather and battery as a row of small chips, after a watch face's complications
Row {
    id: root

    property real s: 1

    property var lock: null
    property var opts: ({})

    readonly property var battery: UPower.displayDevice
    readonly property bool charging: [UPowerDeviceState.Charging, UPowerDeviceState.FullyCharged, UPowerDeviceState.PendingCharge].includes(battery.state)

    spacing: Tokens.spacing.medium * root.s

    Chip {
        visible: root.opts.date ?? true
        s: root.s
        icon: "calendar_today"
        text: Time.format("ddd d")
    }

    Chip {
        visible: (root.opts.weather ?? true) && !!Weather.cc
        s: root.s
        icon: Weather.icon
        text: Weather.temp
    }

    Chip {
        visible: (root.opts.battery ?? true) && root.battery.isLaptopBattery
        s: root.s
        icon: Icons.getBatteryIcon(root.battery.percentage, root.charging)
        text: Strings.percentOne(root.battery.percentage)
    }
}
