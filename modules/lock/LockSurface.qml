pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell.Wayland
import Caelestia.Config
import Caelestia.Multimedia
import Caelestia.State
import qs.components
import qs.services

WlSessionLockSurface {
    id: root

    required property WlSessionLock lock
    required property Pam pam

    readonly property alias unlocking: unlockAnim.running
    // The dino game is up in this screen's notifications dock, which takes the keys from the
    // password field for as long as it lasts (see modules/lock/NotifDock.qml)
    property bool dinoPlaying: false

    // NOTE(fork): everything but the background is faded out once the screen has been left
    // alone, so a locked session does not sit there showing the time and a password field. The
    // field keeps focus throughout, so the first key both brings the UI back and still lands in
    // the buffer (modules/lock/center/PasswordInput.qml)
    property bool idleHidden: false

    // GlobalConfig rather than Config for the two settings below: only contentItem is given a
    // screen, so reading Config from out here lands on the defaults and the countdown never starts
    function noteActivity(): void {
        root.idleHidden = false;

        // Not a binding on running: the first restart() would overwrite it anyway
        if (GlobalConfig.lock.hideIdle && !root.unlocking)
            idleTimer.restart();
        else
            idleTimer.stop();
    }

    contentItem.Config.screen: screen.name
    contentItem.Tokens.screen: screen.name

    color: "transparent"

    Component.onCompleted: root.noteActivity()

    Timer {
        id: idleTimer

        interval: Math.max(1, GlobalConfig.lock.hideIdleDelay) * 1000
        repeat: false
        onTriggered: {
            if (GlobalConfig.lock.hideIdle && !root.unlocking)
                root.idleHidden = true;
        }
    }

    // NOTE(fork): a pointer that has actually moved is what counts as the screen being used.
    // HoverHandler rather than a filled MouseArea, so the cards underneath keep their own hover
    // states and nothing swallows clicks. The position is compared by hand because pointChanged
    // also fires for velocity and timestamp updates while the pointer sits still, which would
    // hold the countdown open for as long as it is anywhere over the screen
    Item {
        id: activityLayer

        property real lastX: -1
        property real lastY: -1

        anchors.fill: parent
        z: 100

        // NOTE(fork): takes the pointer away with the rest of it, and is enabled only while
        // hidden so the cursors the cards set for themselves are untouched otherwise
        HoverHandler {
            enabled: root.idleHidden
            cursorShape: Qt.BlankCursor
        }

        HoverHandler {
            id: activityHover

            onPointChanged: {
                const pos = activityHover.point.position;
                if (pos.x === activityLayer.lastX && pos.y === activityLayer.lastY)
                    return;

                activityLayer.lastX = pos.x;
                activityLayer.lastY = pos.y;
                root.noteActivity();
            }
        }
    }

    Connections {
        function onUnlock(): void {
            root.dinoPlaying = false;
            root.idleHidden = false;
            idleTimer.stop();
            unlockAnim.start();
        }

        // The surface outlives any one lock, so the countdown is armed here rather than only
        // in Component.onCompleted, which can run before the config has been read
        function onLockedChanged(): void {
            if (root.lock.locked)
                root.noteActivity();
        }

        target: root.lock
    }

    // So switching it on in the settings takes hold without waiting for the next lock
    Connections {
        function onHideIdleChanged(): void {
            root.noteActivity();
        }

        target: GlobalConfig.lock
    }

    SequentialAnimation {
        id: unlockAnim

        ParallelAnimation {
            Anim {
                target: lockContent
                properties: "implicitWidth,implicitHeight"
                to: lockContent.size
            }
            Anim {
                target: lockBg
                property: "radius"
                to: lockContent.radius
            }
            Anim {
                target: content
                property: "scale"
                to: 0
            }
            Anim {
                target: content
                property: "opacity"
                to: 0
                type: Anim.StandardSmall
            }
            Anim {
                target: lockIcon
                property: "opacity"
                to: 1
                type: Anim.StandardLarge
            }
            Anim {
                target: background
                property: "opacity"
                to: 0
                type: Anim.StandardLarge
            }
            SequentialAnimation {
                PauseAnimation {
                    duration: Tokens.anim.durations.small
                }
                Anim {
                    type: Anim.Standard
                    target: lockContent
                    property: "opacity"
                    to: 0
                }
            }
        }
        PropertyAction {
            target: root.lock
            property: "locked"
            value: false
        }
    }

    ParallelAnimation {
        id: initAnim

        running: true

        Anim {
            target: background
            property: "opacity"
            to: 1
            type: Anim.StandardLarge
        }
        SequentialAnimation {
            ParallelAnimation {
                Anim {
                    target: lockContent
                    property: "scale"
                    to: 1
                    type: Anim.FastSpatial
                }
                Anim {
                    target: lockContent
                    property: "rotation"
                    to: 360
                    duration: Tokens.anim.durations.expressiveFastSpatial
                    easing: Tokens.anim.standardAccel
                }
            }
            ParallelAnimation {
                Anim {
                    target: lockIcon
                    property: "rotation"
                    to: 360
                    easing: Tokens.anim.standardDecel
                }
                Anim {
                    type: Anim.DefaultEffects
                    target: lockIcon
                    property: "opacity"
                    to: 0
                }
                Anim {
                    type: Anim.DefaultEffects
                    target: content
                    property: "opacity"
                    to: 1
                }
                Anim {
                    target: content
                    property: "scale"
                    to: 1
                }
                Anim {
                    target: lockBg
                    property: "radius"
                    to: lockContent.Tokens.rounding.extraLarge * 1.5
                }
                Anim {
                    target: lockContent
                    property: "implicitWidth"
                    to: (root.screen?.height ?? 0) * lockContent.Tokens.sizes.lock.heightMult * lockContent.Tokens.sizes.lock.ratio
                }
                Anim {
                    target: lockContent
                    property: "implicitHeight"
                    to: (root.screen?.height ?? 0) * lockContent.Tokens.sizes.lock.heightMult
                }
            }
        }
    }

    Item {
        id: background

        anchors.fill: parent
        opacity: 0

        layer.enabled: true
        layer.effect: MultiEffect {
            autoPaddingEnabled: false
            blurEnabled: true
            // NOTE(fork): follows the fade instead of easing on its own, since the blur is only
            // there to hold the wallpaper back from what sits on top of it. Two animations over
            // the same moment drifted against each other and flickered
            blur: lockContent.opacity
            blurMax: 64
            blurMultiplier: 1
        }

        Loader {
            anchors.fill: parent
            sourceComponent: Config.lock.useWallpaper ? wallpaperBackground : screencopyBackground
        }
    }

    Component {
        id: screencopyBackground

        ScreencopyView {
            captureSource: root.screen
        }
    }

    Component {
        id: wallpaperBackground

        Visual {
            source: Wallpapers.current
            playing: PersistentState.wallpaperPlaying
        }
    }

    Item {
        id: lockContent

        readonly property int size: lockIcon.implicitHeight + Tokens.padding.large * 4
        readonly property int radius: size / 4 * Tokens.rounding.scale

        anchors.centerIn: parent
        implicitWidth: size
        implicitHeight: size

        visible: Config.lock.enabled
        rotation: 180
        scale: 0
        opacity: root.idleHidden ? 0 : 1

        Behavior on opacity {
            Anim {}
        }

        StyledRect {
            id: lockBg

            anchors.fill: parent
            color: Colours.palette.m3surface
            radius: parent.radius
            opacity: Colours.transparency.enabled ? Colours.transparency.base : 1

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                blurMax: 15
                shadowColor: Qt.alpha(Colours.palette.m3shadow, 0.7)
            }
        }

        MaterialIcon {
            id: lockIcon

            anchors.centerIn: parent
            text: "lock"
            fontStyle: Tokens.font.icon.builders.extraLarge.scale(4).weight(Font.Bold).build()
            rotation: 180
        }

        Content {
            id: content

            anchors.centerIn: parent
            width: (root.screen?.height ?? 0) * Tokens.sizes.lock.heightMult * Tokens.sizes.lock.ratio - Tokens.padding.extraLargeIncreased
            height: (root.screen?.height ?? 0) * Tokens.sizes.lock.heightMult - Tokens.padding.extraLargeIncreased

            lock: root
            opacity: 0
            scale: 0
        }
    }
}
