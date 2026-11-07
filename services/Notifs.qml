pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import Caelestia.State
import qs.components.misc
import qs.services
import qs.utils

Singleton {
    id: root

    property list<NotifData> list: []
    // What is left in the notification centre: everything still open that is also meant to be
    // kept. Notifications a source rule discards or silences live only as long as their popup
    readonly property list<NotifData> notClosed: list.filter(n => !n.closed && n.keep)
    readonly property list<NotifData> popups: list.filter(n => n.popup)

    property bool loaded

    // NOTE(fork): emitted once a notification has arrived and been wrapped, and again whenever a
    // chat app replaces one with a new message (see NotifData.beginReplace). The notch's island
    // listens for it so it can show the notification - and claim its popup - without the server
    // having to know the notch exists; see services/NotchIsland.qml.
    signal notified(notif: var)

    function hasFullscreen(): bool {
        for (const monitor of Hypr.monitors.values) {
            if (monitor?.activeWorkspace?.toplevels.values.some(t => t.lastIpcObject.fullscreen > 1))
                return true;
        }
        return false;
    }

    // NOTE(fork): whether replaced notifications from this app are kept as separate messages
    function keepsHistory(appName: string): bool {
        if (!GlobalConfig.notifs.keepChatHistory)
            return false;
        const name = appName.toLowerCase();
        return GlobalConfig.notifs.chatApps.some(app => name.includes(app.toLowerCase()));
    }

    // NOTE(fork): called when a chat app replaces `live` with a new message. Keeps the previous
    // message as its own (non-popup) notification just below it, and moves `live` to the top
    // since it now holds the newest message.
    function keepReplaced(live: NotifData, previous: var): void {
        const kept = notifComp.createObject(root, Object.assign({
                keep: root.sourceAction(previous.appName) === NotifSourceAction.Allow
            }, previous));
        const rest = root.list.filter(n => n !== live);
        root.list = [live, kept, ...rest];
    }

    // NOTE(fork): matched case-insensitively by substring, the same way keepsHistory() matches
    // chatApps - an app listed here never pops up, regardless of do not disturb
    function isSilenced(appName: string): bool {
        const name = appName.toLowerCase();
        return GlobalConfig.notifs.silencedApps.some(app => name.includes(app.toLowerCase()));
    }

    // NOTE(fork): what a notification source rule says to do with this app, from the notification
    // sources page in settings. The first rule whose source is a case-insensitive substring of the
    // app name wins, and anything unmatched is allowed.
    function sourceAction(appName: string): int {
        const name = appName.toLowerCase();
        if (!name)
            return NotifSourceAction.Allow;

        const rule = GlobalConfig.notifs.sourceRules.values.find(r => r.match && name.includes(r.match.toLowerCase()));
        return rule ? rule.action : NotifSourceAction.Allow;
    }

    // Silenced sources never pop up, so ask this rather than shouldShowPopup() wherever a popup
    // is about to be shown - a chat app replacing its notification asks for one of its own
    function canPopup(appName: string): bool {
        return root.sourceAction(appName) !== NotifSourceAction.Silence && root.shouldShowPopup(appName);
    }

    function shouldShowPopup(appName: string): bool {
        if (PersistentState.doNotDisturb || ShellState.anySidebarOpen())
            return false;
        if (GlobalConfig.notifs.fullscreen === NotifsFullscreen.Off && hasFullscreen())
            return false;
        if (root.isSilenced(appName))
            return false;
        return true;
    }

    onListChanged: {
        if (loaded)
            saveTimer.restart();
    }

    Connections {
        function onDoNotDisturbChanged(): void {
            if (!GlobalConfig.utilities.toasts.dndChanged)
                return;

            if (PersistentState.doNotDisturb)
                Toaster.toast(Tr.tr("Do not disturb enabled"), Tr.tr("Popup notifications are now disabled"), "do_not_disturb_on");
            else
                Toaster.toast(Tr.tr("Do not disturb disabled"), Tr.tr("Popup notifications are now enabled"), "do_not_disturb_off");
        }

        target: PersistentState
    }

    Timer {
        id: saveTimer

        interval: 1000
        onTriggered: storage.setText(JSON.stringify(root.notClosed.map(n => ({
                    time: n.time,
                    id: n.id,
                    summary: n.summary,
                    body: n.body,
                    appIcon: n.appIcon,
                    appName: n.appName,
                    image: n.image,
                    expireTimeout: n.expireTimeout,
                    urgency: n.urgency,
                    resident: n.resident,
                    hasActionIcons: n.hasActionIcons,
                    actions: n.actions
                }))))
    }

    NotificationServer {
        id: server

        keepOnReload: false
        actionsSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: true
        bodyMarkupSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: notif => {
            notif.tracked = true;

            const action = root.sourceAction(notif.appName);
            const comp = notifComp.createObject(root, {
                popup: action !== NotifSourceAction.Silence && root.shouldShowPopup(notif.appName),
                keep: action === NotifSourceAction.Allow,
                notification: notif
            });
            root.list = [comp, ...root.list];
            root.notified(comp);
        }
    }

    FileView {
        id: storage

        printErrors: false
        path: `${Paths.state}/notifs.json`
        onLoaded: {
            const data = JSON.parse(text());
            for (const notif of data) {
                const properties = Object.assign({}, notif);

                // Backwards compatibility for old notifications
                if (properties.notificationId === undefined && properties.id !== undefined)
                    properties.notificationId = properties.id;

                delete properties.id;
                root.list.push(notifComp.createObject(root, properties));
            }
            root.list.sort((a, b) => b.time - a.time);
            root.loaded = true;
        }
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound) {
                root.loaded = true;
                Qt.callLater(() => setText("[]"));
            }
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "clearNotifs"
        description: "Clear all notifications"
        onPressed: {
            for (const notif of root.list.slice())
                notif.close();
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "toggleDnd"
        description: "Toggle do not disturb"
        onPressed: {
            PersistentState.doNotDisturb = !PersistentState.doNotDisturb;
        }
    }

    IpcHandler {
        function clear(): void {
            for (const notif of root.list.slice())
                notif.close();
        }

        function isDndEnabled(): bool {
            return PersistentState.doNotDisturb;
        }

        function toggleDnd(): void {
            PersistentState.doNotDisturb = !PersistentState.doNotDisturb;
        }

        function enableDnd(): void {
            PersistentState.doNotDisturb = true;
        }

        function disableDnd(): void {
            PersistentState.doNotDisturb = false;
        }

        target: "notifs"
    }

    Component {
        id: notifComp

        NotifData {}
    }
}
