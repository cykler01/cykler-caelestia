pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell.Wayland
import Caelestia.Config
import Caelestia.Multimedia
import Caelestia.State
import qs.components
import qs.services
import qs.modules.lock.canvas

WlSessionLockSurface {
    id: root

    required property WlSessionLock lock
    required property Pam pam

    readonly property bool unlocking: altUnlockAnim.running
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
    // HoverHandler rather than a filled MouseArea, so nothing swallows clicks. The position is
    // compared by hand because pointChanged also fires for velocity and timestamp updates while
    // the pointer sits still, which would hold the countdown open for as long as it is anywhere
    // over the screen.
    //
    // This holds everything else rather than sitting on top of it: as an overlay (z: 100) its
    // handlers took the hover from every card and button underneath, so none of their hover
    // states ever showed. Handlers on a parent see the pointer alongside its children instead
    // of in their place
    Item {
        id: activityLayer

        property real lastX: -1
        property real lastY: -1

        anchors.fill: parent

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

        Item {
            id: background

            // NOTE(fork): a wallpaper this heavily blurred holds no fine detail, so the layer is
            // rendered at a fraction of the screen's resolution and scaled back up. Blurring it at
            // full size cost enough GPU time that a 120Hz panel fell back to 60fps whenever the
            // blur was on. The blur's reach is scaled down with it, so the look is the same
            readonly property bool blurred: (Config.lock.blur ?? 1) > 0
            readonly property real layerScale: blurred ? 0.2 : 1

            anchors.fill: parent
            opacity: 0

            layer.enabled: true
            layer.smooth: true
            // Half-float, so the blur's passes don't each round to 8 bits and leave contour lines
            layer.format: ShaderEffectSource.RGBA16F
            layer.textureSize: Qt.size(Math.max(1, Math.round(width * layerScale)), Math.max(1, Math.round(height * layerScale)))
            layer.effect: MultiEffect {
                autoPaddingEnabled: false
                // Off entirely at zero strength rather than running the blur passes for nothing
                blurEnabled: blur > 0
                // NOTE(fork): follows the fade instead of easing on its own, since the blur is only
                // there to hold the wallpaper back from what sits on top of it. Two animations over
                // the same moment drifted against each other and flickered. Scaled by the strength
                // set in Nexus > Lock screen > Background
                blur: lockContent.opacity * Math.max(0, Math.min(1, Config.lock.blur ?? 1))
                // The layer is small, so the full kernel already reaches ~5x as far on screen.
                // The multiplier stays at 1: above it the samples spread wider than the texels
                // and the blur breaks up into blotches instead of a smooth gradient
                blurMax: 64
                blurMultiplier: 1
            }

            Loader {
                anchors.fill: parent
                // A lock-only wallpaper wins over both of the others when one is set
                sourceComponent: (Config.lock.wallpaper ?? "") !== "" ? lockWallpaperBackground : Config.lock.useWallpaper ? wallpaperBackground : screencopyBackground
            }
        }

        // A dark scrim over the blur, so whatever is on screen when it locks (windows, text) is
        // dimmed to shapes and never reads through. Outside the blurred layer on purpose: inside
        // it, darkening the range before the blur made its banding show. Follows the blur in/out
        Rectangle {
            anchors.fill: parent
            color: Colours.palette.m3scrim
            opacity: 0.4 * lockContent.opacity * Math.max(0, Math.min(1, Config.lock.blur ?? 1)) * background.opacity
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
        }

        // NOTE(fork): the lock screen's elements (modules/lock/canvas), arranged in Nexus > Lock
        // screen > Edit layout. Faded with the idle hide
        Item {
            id: altLayer

            anchors.fill: parent
            visible: Config.lock.enabled
            opacity: root.idleHidden ? 0 : 1

            Behavior on opacity {
                Anim {}
            }

            Loader {
                id: altContent

                anchors.fill: parent
                focus: true
                opacity: 0
                scale: 0.94

                sourceComponent: LockCanvas {
                    lock: root
                }
            }
        }
    }

    Connections {
        function onUnlock(): void {
            root.dinoPlaying = false;
            root.idleHidden = false;
            idleTimer.stop();
            altUnlockAnim.start();
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
        id: altUnlockAnim

        ParallelAnimation {
            Anim {
                target: altContent
                property: "opacity"
                to: 0
                type: Anim.StandardSmall
            }
            Anim {
                target: altContent
                property: "scale"
                to: 1.06
            }
            Anim {
                target: background
                property: "opacity"
                to: 0
                type: Anim.StandardLarge
            }
        }
        PropertyAction {
            target: root.lock
            property: "locked"
            value: false
        }
    }

    // The second half of the intro: the icon finishes its turn and its tile blooms and fades as
    // the lock screen comes in
    ParallelAnimation {
        id: altInAnim

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
        // The tile the icon sits on blooms a little as it fades and the layout comes up in its
        // place, so the icon reads as turning into the layout rather than being swapped for it.
        // Kept small and quick: grown to the whole screen it was a dark shape (with its shadow)
        // sweeping out behind the layout, which showed as a black ripple
        Anim {
            target: lockContent
            property: "implicitWidth"
            to: lockContent.size * 1.6
        }
        Anim {
            target: lockContent
            property: "implicitHeight"
            to: lockContent.size * 1.6
        }
        // The tile's own background fades, not lockContent: the wallpaper blur follows
        // lockContent's opacity (see the background layer), so fading that would lose the blur
        Anim {
            type: Anim.StandardSmall
            target: lockBg
            property: "opacity"
            to: 0
        }
        Anim {
            type: Anim.DefaultEffects
            target: altContent
            property: "opacity"
            to: 1
        }
        Anim {
            target: altContent
            property: "scale"
            to: 1
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
            ScriptAction {
                script: altInAnim.start()
            }
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

    Component {
        id: lockWallpaperBackground

        Visual {
            source: Config.lock.wallpaper
            playing: PersistentState.wallpaperPlaying
        }
    }
}
