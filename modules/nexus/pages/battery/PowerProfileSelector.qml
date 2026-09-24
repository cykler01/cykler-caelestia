pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.I18n
import qs.components.controls
import qs.modules.nexus.common

// SelectRow with the standard power-profile options (fork feature)
SelectRow {
    id: root

    property string value
    property bool showRestore: false
    property bool showUnchanged: false

    // NOTE(fork): label is set by the caller via the `label` alias
    readonly property list<MenuItem> profileItems: {
        const items = [];

        if (root.showRestore)
            items.push(profileComp.createObject(root, {
                text: Tr.trCtx("Previous", "restore the setting from before the shell changed it"),
                icon: "refresh",
                value: "restore"
            }));

        if (root.showUnchanged)
            items.push(profileComp.createObject(root, {
                text: Tr.trCtx("Keep current", "leave the setting unchanged"),
                icon: "block",
                value: ""
            }));

        items.push(profileComp.createObject(root, {
            text: Tr.tr("Power Saver"),
            icon: "battery_saver",
            value: "power-saver"
        }));
        items.push(profileComp.createObject(root, {
            text: Tr.tr("Balanced"),
            icon: "balance",
            value: "balanced"
        }));
        items.push(profileComp.createObject(root, {
            text: Tr.tr("Performance"),
            icon: "speed",
            value: "performance"
        }));

        return items;
    }

    readonly property Component profileComp: Component {
        ProfileMenuItem {}
    }

    signal profileChanged(string newValue)

    menuItems: root.profileItems
    active: root.profileItems.find(item => item.value === root.value) ?? null

    onSelected: item => {
        if (item)
            root.profileChanged(item.value);
    }

    component ProfileMenuItem: MenuItem {
        text: ""
    }
}
