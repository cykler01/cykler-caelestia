pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import qs.services
import qs.utils

QtObject {
    id: notif

    property bool popup
    // NOTE(fork): whether this notification belongs to the history. A source rule that discards or
    // silences an app leaves it false, so it is only ever as long lived as its popup
    property bool keep: true
    property bool closed
    property var locks: new Set()

    property date time: new Date()
    property int ageMins: 0
    readonly property string timeStr: {
        if (ageMins < 1)
            return Tr.tr("now");

        const h = Math.floor(ageMins / 60);
        const d = Math.floor(h / 24);

        if (d > 0)
            return Tr.trCtx("%1d", "abbreviated notification age, days").arg(d);
        if (h > 0)
            return Tr.trCtx("%1h", "abbreviated notification age, hours").arg(h);
        return Tr.trCtx("%1m", "abbreviated notification age, minutes").arg(ageMins);
    }

    readonly property Timer timeStrTimer: Timer {
        running: !notif.closed
        repeat: true
        interval: 5000
        onTriggered: notif.updateTimeStr()
    }

    property Notification notification
    property string notificationId
    property string summary
    property string body
    property string appIcon
    property string appName
    // The app's desktop file id, when it sent one: the surest way back to its window
    property string desktopEntry
    property string image
    property var hints // Hints are not persisted across restarts
    property real expireTimeout: GlobalConfig.notifs.defaultExpireTimeout
    property int urgency: NotificationUrgency.Normal
    property bool resident
    property bool hasActionIcons
    property list<var> actions

    // NOTE(fork): set while a replacement's changes are arriving, so a message is only kept once
    // even though its summary, body and image change signals come in separately
    property bool replacing

    readonly property bool hasFullscreen: {
        const monitor = Hypr.focusedMonitor;
        const specialName = monitor?.lastIpcObject.specialWorkspace?.name;
        if (specialName) {
            const specialWs = Hypr.workspaces.values.find(ws => ws.name === specialName);
            return specialWs?.toplevels.values.some(t => t.lastIpcObject.fullscreen > 1) ?? false;
        }
        return monitor?.activeWorkspace?.toplevels.values.some(t => t.lastIpcObject.fullscreen > 1) ?? false;
    }

    readonly property Timer timer: Timer {
        running: true
        interval: notif.expireTimeout > 0 ? notif.expireTimeout : notif.hasFullscreen ? GlobalConfig.notifs.fullscreenExpireTimeout : GlobalConfig.notifs.defaultExpireTimeout
        onTriggered: {
            // Always expire if the active workspace has a fullscreen window
            if (GlobalConfig.notifs.expire || notif.hasFullscreen)
                notif.popup = false;
        }
    }

    // Closes a notification that is not meant to be kept once it has no popup left, giving the
    // popup's exit animation time to run first; one that never popped up (a silenced source) has
    // no popup at all, so it is dropped shortly after it arrives
    readonly property Timer dropTimer: Timer {
        running: !notif.keep && !notif.popup
        interval: Tokens.anim.durations.expressiveDefaultSpatial + 150
        onTriggered: notif.close()
    }

    readonly property LazyLoader dummyImageLoader: LazyLoader {
        active: false

        // qmllint disable uncreatable-type
        PanelWindow {
            // qmllint enable uncreatable-type
            implicitWidth: TokenConfig.sizes.notifs.image
            implicitHeight: TokenConfig.sizes.notifs.image
            color: "transparent"
            mask: Region {}

            Image {
                function tryCache(): void {
                    if (status !== Image.Ready || width != TokenConfig.sizes.notifs.image || height != TokenConfig.sizes.notifs.image)
                        return;

                    const cacheKey = notif.appName + notif.summary + notif.notificationId + notif.image;
                    let h1 = 0xdeadbeef, h2 = 0x41c6ce57, ch;
                    for (let i = 0; i < cacheKey.length; i++) {
                        ch = cacheKey.charCodeAt(i);
                        h1 = Math.imul(h1 ^ ch, 2654435761);
                        h2 = Math.imul(h2 ^ ch, 1597334677);
                    }
                    h1 = Math.imul(h1 ^ (h1 >>> 16), 2246822507);
                    h1 ^= Math.imul(h2 ^ (h2 >>> 13), 3266489909);
                    h2 = Math.imul(h2 ^ (h2 >>> 16), 2246822507);
                    h2 ^= Math.imul(h1 ^ (h1 >>> 13), 3266489909);
                    const hash = (h2 >>> 0).toString(16).padStart(8, 0) + (h1 >>> 0).toString(16).padStart(8, 0);

                    const cache = `${Paths.notifimagecache}/${hash}.png`;
                    CUtils.saveItem(this, Qt.resolvedUrl(cache), () => {
                        notif.image = cache;
                        notif.dummyImageLoader.active = false;
                    });
                }

                anchors.fill: parent
                source: Qt.resolvedUrl(notif.image)
                fillMode: Image.PreserveAspectCrop
                cache: false
                asynchronous: true
                opacity: 0

                onStatusChanged: tryCache()
                onWidthChanged: tryCache()
                onHeightChanged: tryCache()
            }
        }
    }

    readonly property Connections conn: Connections {
        function onClosed(): void {
            notif.close();
        }

        function onSummaryChanged(): void {
            notif.beginReplace();
            notif.summary = notif.notification.summary;
        }

        function onBodyChanged(): void {
            notif.beginReplace();
            notif.body = notif.notification.body;
        }

        function onAppIconChanged(): void {
            notif.appIcon = notif.notification.appIcon;
        }

        function onAppNameChanged(): void {
            notif.appName = notif.notification.appName;
        }

        function onImageChanged(): void {
            notif.beginReplace();
            notif.image = notif.notification.image;
            notif.maybeTriggerDummyImageLoader();
        }

        function onExpireTimeoutChanged(): void {
            notif.expireTimeout = notif.notification.expireTimeout;
        }

        function onUrgencyChanged(): void {
            notif.urgency = notif.notification.urgency;
        }

        function onResidentChanged(): void {
            notif.resident = notif.notification.resident;
        }

        function onHasActionIconsChanged(): void {
            notif.hasActionIcons = notif.notification.hasActionIcons;
        }

        function onActionsChanged(): void {
            notif.actions = (notif.notification.actions as Array).map(a => ({
                        identifier: a.identifier,
                        text: a.text,
                        label: notif.actionLabel(a.identifier, a.text),
                        invoke: () => notif.invokeAction(a.identifier, a.text, () => a.invoke())
                    }));
        }

        function onHintsChanged(): void {
            notif.hints = notif.notification.hints;
        }

        function onDesktopEntryChanged(): void {
            notif.desktopEntry = notif.notification.desktopEntry;
        }

        target: notif.notification
    }

    // NOTE(fork): a chat app replacing this notification with a new message. Snapshot the old
    // message before any field changes, then once every change has arrived keep the snapshot as
    // its own notification and show this one again as a new message.
    function beginReplace(): void {
        if (replacing || closed || !Notifs.keepsHistory(appName))
            return;

        replacing = true;
        const previous = {
            time: time,
            summary: summary,
            body: body,
            appIcon: appIcon,
            appName: appName,
            // An unsaved image:// pixmap belongs to the live notification and goes with it
            image: image.startsWith(Paths.notifimagecache) || !image.startsWith("image://") ? image : "",
            urgency: urgency,
            expireTimeout: expireTimeout
        };

        Qt.callLater(() => {
            replacing = false;
            if (previous.summary === summary && previous.body === body)
                return; // Only the image changed, e.g. an avatar finished loading

            Notifs.keepReplaced(notif, previous);
            time = new Date();
            updateTimeStr();
            popup = Notifs.canPopup(appName);
            timer.restart();
            // NOTE(fork): a new message, so the notch's island gets to show it like any other
            Notifs.notified(notif);
        });
    }

    function updateTimeStr(): void {
        const diff = Date.now() - time.getTime();
        const m = Math.floor(diff / 60000);
        ageMins = m;

        if (m < 1) {
            timeStrTimer.interval = 5000;
        } else {
            const h = Math.floor(m / 60);
            const d = Math.floor(h / 24);

            if (d > 0)
                timeStrTimer.interval = 3600000;
            else if (h > 0)
                timeStrTimer.interval = 300000;
            else
                timeStrTimer.interval = m < 10 ? 30000 : 60000;
        }
    }

    function maybeTriggerDummyImageLoader(): void {
        if (image && !image.startsWith("image://icon/") && !image.startsWith(Paths.notifimagecache))
            dummyImageLoader.active = true;
    }

    // The action a notification's own "click me" button is. Apps label it anything or nothing,
    // but they all give it the same identifier
    function isDefaultAction(identifier: string, text: string): bool {
        return identifier === "default" || ["activate", "default"].includes(text.trim().toLowerCase());
    }

    // "Activate" is what the spec calls it; what it does is show you the thing
    function actionLabel(identifier: string, text: string): string {
        return notif.isDefaultAction(identifier, text) ? Tr.tr("View") : (text || Tr.tr("View"));
    }

    // An app id, a window class and a desktop file id are the same name in three dresses
    // ("org.mozilla.firefox", "firefox", "Firefox"), so they are compared stripped down
    function normalise(name: string): string {
        const base = name.includes(".") ? name.slice(name.lastIndexOf(".") + 1) : name;
        return base.toLowerCase().replace(/[^a-z0-9]/g, "");
    }

    function namesMatch(a: string, b: string): bool {
        if (!a || !b)
            return false;
        if (a === b)
            return true;
        // "vesktop" against "discord" is not a match, but "firefox" against "firefoxdeveloperedition" is
        return a.length >= 3 && b.length >= 3 && (a.includes(b) || b.includes(a));
    }

    // The window this notification came from, or null. The most recently focused one when the app
    // has several, so a reply lands in the conversation you were last in
    function toplevel(): var {
        const names = [notif.desktopEntry, notif.appName].map(n => notif.normalise(n ?? "")).filter(n => n.length > 0);
        if (names.length === 0)
            return null;

        const matches = Hypr.toplevels.values.filter(t => {
            const ipc = t.lastIpcObject;
            if (!ipc?.class)
                return false;
            const classes = [ipc.class, ipc.initialClass ?? ""].map(c => notif.normalise(c));
            return names.some(n => classes.some(c => notif.namesMatch(n, c)));
        });
        if (matches.length === 0)
            return null;

        return matches.reduce((best, t) => (t.lastIpcObject.focusHistoryID ?? 99) < (best.lastIpcObject.focusHistoryID ?? 99) ? t : best);
    }

    // Invoking the default action is meant to bring the app up, and most apps do raise their
    // window - but raising it does nothing for you while it sits on a workspace you are not
    // looking at, which is why clicking "View" so often appeared to do nothing at all. So the
    // shell goes to the window itself; focusing it is what switches the workspace
    function invokeAction(identifier: string, text: string, invoke: var): void {
        invoke();

        if (!notif.isDefaultAction(identifier, text))
            return;

        const window = notif.toplevel();
        if (window)
            Hypr.focusWindow(window.address);
    }

    function lock(item: Item): void {
        locks.add(item);
    }

    function unlock(item: Item): void {
        locks.delete(item);
        if (closed)
            close();
    }

    function close(): void {
        closed = true;
        if (locks.size === 0 && Notifs.list.includes(this)) {
            Notifs.list = Notifs.list.filter(n => n !== this);
            notification?.dismiss();
            destroy();
        }
    }

    Component.onCompleted: {
        if (!notification)
            return;

        notificationId = notification.id;
        summary = notification.summary;
        body = notification.body;
        appIcon = notification.appIcon;
        appName = notification.appName;
        desktopEntry = notification.desktopEntry;
        image = notification.image;
        maybeTriggerDummyImageLoader();
        expireTimeout = notification.expireTimeout;
        hints = notification.hints;
        urgency = notification.urgency;
        resident = notification.resident;
        hasActionIcons = notification.hasActionIcons;

        actions = (notification.actions as Array).map(a => ({
                    identifier: a.identifier,
                    text: a.text,
                    label: notif.actionLabel(a.identifier, a.text),
                    invoke: () => notif.invokeAction(a.identifier, a.text, () => a.invoke())
                }));
    }
}
