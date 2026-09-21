pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import Caelestia.I18n
import qs.components.controls
import qs.modules.nexus.common

// SelectRow for an idle timeout in seconds, where 0 means never (fork feature)
SelectRow {
    id: root

    // Seconds, 0 for never
    property int value

    signal timeoutChanged(int seconds)

    readonly property list<int> options: [0, 60, 120, 180, 300, 600, 900, 1800, 3600, 7200]

    readonly property list<MenuItem> timeItems: options.map(secs => itemComp.createObject(root, {
            text: root.describe(secs),
            value: secs
        }))

    function describe(secs: int): string {
        if (secs === 0)
            return Tr.tr("Never");
        if (secs < 3600)
            return Tr.tr("%1 min").arg(secs / 60);
        return Tr.tr("%1 h").arg(secs / 3600);
    }

    menuItems: timeItems
    active: timeItems.find(item => item.value === value) ?? null
    fallbackText: describe(value)
    fallbackIcon: "schedule"
    onSelected: item => root.timeoutChanged(item.value)

    Component {
        id: itemComp

        MenuItem {}
    }
}
