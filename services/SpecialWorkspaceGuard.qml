pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Caelestia.Config
import qs.services

// Hyprland always has special workspaces, so "off" (Workspaces > Special workspaces) is
// enforced here instead of in anyone's Hyprland config: whatever opens one, be it a keybind,
// a gesture or a dispatch, gets undone by moving its windows to the current workspace and
// closing it. That works with any config, at the cost of the workspace flashing open briefly.
Singleton {
    id: root

    readonly property bool enabled: !GlobalConfig.bar.workspaces.specialWorkspaces

    function isSpecial(name: string): bool {
        return name.startsWith("special:");
    }

    function moveWindow(address: string, workspaceId: int): void {
        Hypr.dispatch(Hypr.usingLua ? `hl.dsp.window.move({ window = "address:${address}", workspace = ${workspaceId}, follow = false })` : `movetoworkspacesilent ${workspaceId},address:${address}`);
    }

    // The workspace a window pulled out of a special workspace should land on
    function regularWorkspaceOn(monitor: HyprlandMonitor): int {
        const id = monitor?.activeWorkspace?.id ?? -1;
        return id > 0 ? id : -1;
    }

    function evacuate(name: string, monitor: HyprlandMonitor): void {
        const target = regularWorkspaceOn(monitor);
        if (target < 0)
            return;

        for (const t of Hypr.toplevels.values) {
            if (t.workspace?.name === name && t.lastIpcObject?.address)
                moveWindow(t.lastIpcObject.address, target);
        }
        Hypr.toggleSpecial(name.slice("special:".length));
    }

    // Covers a special workspace already open when the setting is switched off
    onEnabledChanged: {
        if (!enabled)
            for (const m of Hypr.monitors.values) {
                const name = m.lastIpcObject?.specialWorkspace?.name ?? "";
                if (isSpecial(name))
                    evacuate(name, m);
            }
    }

    Connections {
        function onRawEvent(event: HyprlandEvent): void {
            if (!root.enabled)
                return;

            const parts = event.data.split(",");

            if (event.name === "activespecial") {
                // "special:name,monitor" when one opens, ",monitor" when it closes
                if (root.isSpecial(parts[0]))
                    root.evacuate(parts[0], Hypr.monitors.values.find(m => m.name === parts[1]) ?? Hypr.focusedMonitor);
            } else if (event.name === "openwindow" || event.name === "movewindow") {
                // "address,workspace,..." (a window opening or being moved onto a special workspace)
                if (root.isSpecial(parts[1] ?? "")) {
                    const target = root.regularWorkspaceOn(Hypr.focusedMonitor);
                    if (target > 0)
                        root.moveWindow(`0x${parts[0]}`, target);
                }
            }
        }

        target: Hyprland
    }
}
