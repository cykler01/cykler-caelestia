pragma Singleton

import Quickshell
import Caelestia.Config

// The sidebar's tabs, in the order its tab bar shows them. The notification dock is always the
// first tab; the others are on unless turned off in the settings
// (see modules/notifpopout/Content.qml)
Singleton {
    id: root

    readonly property var keys: {
        const tabs = ["notifications"];
        if (Config.sidebar.music ?? true)
            tabs.push("music");
        if (Config.sidebar.todo ?? true)
            tabs.push("todo");
        if (Config.sidebar.notes ?? true)
            tabs.push("notes");
        if (Config.sidebar.aiChat ?? false)
            tabs.push("aiChat");
        return tabs;
    }

    function indexOf(key: string): int {
        return root.keys.indexOf(key);
    }

    function isEnabled(key: string): bool {
        return root.indexOf(key) !== -1;
    }
}
