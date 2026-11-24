pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import Caelestia.State
import qs.services

Singleton {
    id: root

    // Kept in the shell's persistent state so game mode survives a restart or reboot, not just a
    // reload. Persistence is the state file's job; this is only a read of it until the user
    // switches game mode, which writes back below
    property bool enabled: PersistentState.gameMode
    // Whether the stored value has been picked up yet. Restoring game mode at startup should apply
    // its options without popping the "enabled" toast as if it had just been turned on
    property bool initialised: false

    function setDynamicConfs(): void {
        Hypr.extras.applyOptions(GlobalConfig.utilities.gameMode.options);
    }

    onEnabledChanged: {
        PersistentState.gameMode = enabled;

        if (!initialised)
            return;

        if (enabled) {
            setDynamicConfs();
            if (GlobalConfig.utilities.toasts.gameModeChanged)
                Toaster.toast(Tr.tr("Game mode enabled"), Tr.tr("Disabled Hyprland animations, blur, gaps, shadows and mouse acceleration"), "gamepad");
        } else {
            // A reload drops every runtime `keyword monitor`; Monitors puts them back
            Monitors.rememberForReload();
            Hypr.extras.message("reload");
            if (GlobalConfig.utilities.toasts.gameModeChanged)
                Toaster.toast(Tr.tr("Game mode disabled"), Tr.tr("Hyprland settings restored"), "gamepad");
        }
    }

    Component.onCompleted: {
        if (enabled)
            setDynamicConfs();
        initialised = true;
    }

    Connections {
        function onConfigReloaded(): void {
            if (root.enabled)
                root.setDynamicConfs();
        }

        target: Hypr
    }

    IpcHandler {
        function isEnabled(): bool {
            return root.enabled;
        }

        function toggle(): void {
            root.enabled = !root.enabled;
        }

        function enable(): void {
            root.enabled = true;
        }

        function disable(): void {
            root.enabled = false;
        }

        target: "gameMode"
    }
}
