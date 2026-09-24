pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Hyprland
import Caelestia.I18n
import qs.components.controls
import qs.modules.nexus.common

// SelectRow with the monitor refresh-rate options (fork feature)
SelectRow {
    id: root

    property string value
    property bool showRestore: false
    property bool showUnchanged: false

    // NOTE(fork): label is set by the caller via the `label` alias
    readonly property list<MenuItem> rateItems: {
        const items = [];

        if (root.showRestore)
            items.push(rateComp.createObject(root, {
                text: Tr.trCtx("Previous", "restore the setting from before the shell changed it"),
                icon: "refresh",
                value: "restore"
            }));

        if (root.showUnchanged)
            items.push(rateComp.createObject(root, {
                text: Tr.trCtx("Keep current", "leave the setting unchanged"),
                icon: "block",
                value: ""
            }));

        const uniqueRates = new Set();

        for (const monitor of Hyprland.monitors.values) {
            const data = monitor.lastIpcObject;
            if (!data?.availableModes)
                continue;

            for (const mode of data.availableModes) {
                const match = mode.match(/@(\d+(?:\.\d+)?)Hz/);
                if (match)
                    uniqueRates.add(Math.round(parseFloat(match[1])));
            }
        }

        const sortedRates = [...uniqueRates].sort((a, b) => a - b);
        for (const rate of sortedRates)
            items.push(rateComp.createObject(root, {
                text: `${rate} Hz`,
                icon: "speed",
                value: rate.toString()
            }));

        items.push(rateComp.createObject(root, {
            text: Tr.tr("Auto (lowest)"),
            icon: "battery_saver",
            value: "auto"
        }));

        return items;
    }

    readonly property Component rateComp: Component {
        RateMenuItem {}
    }

    signal rateChanged(string newValue)

    menuItems: root.rateItems
    active: root.rateItems.find(item => item.value === root.value) ?? null

    onSelected: item => {
        if (item)
            root.rateChanged(item.value);
    }

    component RateMenuItem: MenuItem {
        text: ""
    }
}
