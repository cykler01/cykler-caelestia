import QtQuick
import Quickshell
import Caelestia.Config
import qs.services

Scope {
    Component.onCompleted: {
        // Force certain singletons to load on shell init instead of lazily

        IdleInhibitor;
        DiscordPresence;
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

        // Starts kdeconnectd on shell start when the phone share card is enabled
        if (GlobalConfig.utilities.cards.phoneShare)
            KdeConnect;
    }
}
