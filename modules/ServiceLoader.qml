import QtQuick
import Quickshell
import Caelestia.Config
import qs.services

Scope {
    Component.onCompleted: {
        // Force certain singletons to load on shell init instead of lazily

        IdleInhibitor;
        GameMode;
        InputSettings;
        Notifs;
        Players;
        Brightness;
        UpdateChecker;
        SpecialWorkspaceGuard;
        ResourceHistory;
        Weather.reload();

        if (GlobalConfig.utilities.vpn.enabled)
            VPN;
    }
}
