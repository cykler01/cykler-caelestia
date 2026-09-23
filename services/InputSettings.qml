pragma Singleton

import QtQuick
import Quickshell
import qs.services

// NOTE(fork): mouse, scroll and touchpad options live in Hyprland, and changing them
// from Nexus is a runtime keyword. Those are forgotten on a config reload, so anything
// changed here is remembered and put back when Hyprland reloads or the shell starts.
// Options that have never been touched are left alone, so the user's own hyprland.conf
// still wins.
Singleton {
    id: root

    readonly property string sensitivityKey: "input:sensitivity"
    readonly property string accelProfileKey: "input:accel_profile"
    readonly property string scrollFactorKey: "input:scroll_factor"
    readonly property string touchpadScrollFactorKey: "input:touchpad:scroll_factor"

    // Kept in memory while a slider is dragged so the UI follows it. Applying makes
    // the shell re-read every Hyprland option, so it is only done once the value
    // settles rather than on every mouse move.
    property var overrides: ({})

    readonly property real sensitivity: root.current(root.sensitivityKey, 0)
    readonly property string accelProfile: root.current(root.accelProfileKey, "")
    readonly property real scrollFactor: root.current(root.scrollFactorKey, 1)
    readonly property real touchpadScrollFactor: root.current(root.touchpadScrollFactorKey, 1)

    // The override if the option was changed here, otherwise whatever Hyprland reports
    function current(key: string, fallback: var): var {
        return root.overrides[key] ?? Hypr.options[key] ?? fallback;
    }

    function set(key: string, value: var): void {
        const next = Object.assign({}, root.overrides);
        next[key] = value;
        root.overrides = next;
        commitTimer.restart();
    }

    function apply(): void {
        if (Object.keys(root.overrides).length > 0)
            Hypr.extras.applyOptions(root.overrides);
    }

    function commit(): void {
        props.overrides = root.overrides;
        root.apply();
    }

    Component.onCompleted: {
        root.overrides = props.overrides;
        root.apply();
    }

    Timer {
        id: commitTimer

        interval: 150
        onTriggered: root.commit()
    }

    Connections {
        function onConfigReloaded(): void {
            root.apply();
        }

        target: Hypr
    }

    PersistentProperties {
        id: props

        property var overrides: ({})

        reloadableId: "inputSettings"
    }
}
