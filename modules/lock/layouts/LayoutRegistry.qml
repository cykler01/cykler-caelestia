pragma Singleton

import QtQuick
import Quickshell

// NOTE(fork): the one list of lock screen layouts (Config.lock.layout) and what each one supports,
// so the lock surface, the settings page, its preview and the picker can't disagree about them.
// Anything not listed falls back to the classic card
Singleton {
    id: root

    // The layouts that span the whole screen instead of sitting in the classic card, in the
    // order the picker shows them
    readonly property list<string> freeStanding: ["split", "sidebar", "minimal", "stage", "curtain", "watch", "band", "console", "fuzzy"]
    // Have a login side (Config.lock.panelSide)
    readonly property list<string> sided: ["split", "sidebar", "band"]
    // Show the side widgets (Config.lock.widgets)
    readonly property list<string> withWidgets: ["card", "split", "sidebar"]

    function resolve(id: string): string {
        return root.freeStanding.includes(id) ? id : "card";
    }

    function isCard(id: string): bool {
        return root.resolve(id) === "card";
    }

    function isSided(id: string): bool {
        return root.sided.includes(id);
    }

    function hasWidgets(id: string): bool {
        return root.withWidgets.includes(root.resolve(id));
    }
}
