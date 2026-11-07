pragma Singleton

import QtQuick
import Quickshell
import Caelestia.Config
import qs.services

// NOTE(fork): the notch's Dynamic Island activities - the short lived things it stands up to show
// that are neither the clock nor what is playing: a lock key turning on or off, a notification
// arriving, and (through authActive) the authentication prompt taking its place.
//
// It lives in one service rather than in each screen's notch so every monitor shows the same thing
// at the same instant, and so a notification's popup is claimed exactly once however many notches
// are up (see showNotif).
Singleton {
    id: root

    // Which activity the notch is showing, highest priority first; "" is nothing to show. The
    // notch's own standing content (clock, timer, media) is what it falls back to.
    readonly property string activity: {
        if (root.notifShown)
            return "notif";
        if (root.lockShown)
            return "keylock";
        return "";
    }
    readonly property bool hasActivity: root.activity !== ""

    // Whether the authentication prompt is up. It is a panel of its own (it has to hold the
    // keyboard, which the drawers window cannot), so the notch steps aside for it rather than
    // drawing it: see modules/polkit.
    property bool authActive

    // --- Lock keys ---

    // Which lock key changed and what it changed to
    property string lockKind: "caps"
    property bool lockState
    property bool lockShown

    // Hyprland reports its keyboards a moment after the shell starts, and the notch dropping down
    // to say caps lock is off at login is not news, so the first state to arrive is taken as the
    // state of things rather than as a change
    property bool lockReady

    // --- Notifications ---

    // A snapshot of what arrived rather than the notification itself: a source rule can mean it is
    // dropped (and destroyed) as soon as its popup goes, which here is the moment the island
    // claims it, and the island has to outlive that
    property string notifSummary
    property string notifBody
    property string notifAppName
    property string notifImage
    property string notifAppIcon
    property int notifUrgency
    property bool notifShown

    // Brings the island down to say a lock key changed. Ignored until the first keyboard state has
    // settled, so startup is not mistaken for a keypress.
    function flashLock(kind: string, state: bool): void {
        if (!root.lockReady || !GlobalConfig.notch.enabled || !GlobalConfig.notch.showKeyLocks)
            return;

        root.lockKind = kind;
        root.lockState = state;
        root.lockShown = true;
        lockTimer.restart();
    }

    // Shows a notification as it arrives, and - with notifsTakeOver - claims its popup so the
    // corner does not show the same thing twice. The notification is left in the notification
    // centre either way; only its popup is given up.
    //
    // Nothing is claimed while the notch is covered everywhere (a drawer over it, or the session
    // lock): the corner popup is then the only place the notification would be seen at all.
    function showNotif(notif: var): void {
        if (!GlobalConfig.notch.enabled || !GlobalConfig.notch.showNotifs)
            return;
        if (!notif?.popup || ShellState.notchCovered())
            return;

        root.notifSummary = notif.summary;
        root.notifBody = notif.body;
        root.notifAppName = notif.appName;
        root.notifImage = notif.image;
        root.notifAppIcon = notif.appIcon;
        root.notifUrgency = notif.urgency;
        root.notifShown = true;
        notifTimer.restart();

        // A lock key underneath would otherwise come back for whatever is left of its moment once
        // this one is over
        root.lockShown = false;
        lockTimer.stop();

        if (GlobalConfig.notch.notifsTakeOver)
            notif.popup = false;
    }

    // Takes the island back down early, for whoever has a reason to
    function clear(): void {
        root.lockShown = false;
        root.notifShown = false;
        lockTimer.stop();
        notifTimer.stop();
    }

    // A device refresh can leave Hypr without a main keyboard for a moment, which reads as both
    // locks going off and coming back; with no keyboard there is nothing to report either way, so
    // that pair of changes is ignored rather than flashed twice
    Connections {
        function onCapsLockChanged(): void {
            if (Hypr.keyboard)
                root.flashLock("caps", Hypr.capsLock);
        }

        function onNumLockChanged(): void {
            if (Hypr.keyboard)
                root.flashLock("num", Hypr.numLock);
        }

        target: Hypr
    }

    Connections {
        function onNotified(notif: var): void {
            root.showNotif(notif);
        }

        target: Notifs
    }

    Timer {
        id: lockReadyTimer

        interval: 2000
        running: true
        onTriggered: root.lockReady = true
    }

    Timer {
        id: lockTimer

        interval: GlobalConfig.notch.keyLockDuration
        onTriggered: root.lockShown = false
    }

    Timer {
        id: notifTimer

        interval: GlobalConfig.notch.notifDuration
        onTriggered: root.notifShown = false
    }
}
