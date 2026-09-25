pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components
import qs.utils
import qs.modules.bar.popouts as BarPopouts

Item {
    id: root

    required property ShellScreen screen
    required property ScreenState screenState
    required property BarPopouts.Wrapper popouts
    required property bool fullscreen
    // Screen border thickness (animated by the drawers window while fullscreen)
    required property real borderThickness

    readonly property int position: Config.bar.position
    readonly property bool onLeft: position === BarPosition.Left
    readonly property bool onRight: position === BarPosition.Right
    readonly property bool onTop: position === BarPosition.Top
    readonly property bool onBottom: position === BarPosition.Bottom
    readonly property bool vertical: onLeft || onRight

    readonly property bool disabled: Strings.testRegexList(Config.bar.excludedScreens, screen.name)

    // How far the bar reaches in from its screen edge; animates between the border thickness and the full bar
    property real thickness: fullscreen ? 0 : Config.border.thickness
    readonly property real clampedThickness: Math.max(Config.border.minThickness, thickness)
    readonly property int padding: Math.max(Tokens.padding.small, Config.border.thickness)
    readonly property int contentThickness: Tokens.sizes.bar.innerWidth + padding * 2
    readonly property int exclusiveZone: !disabled && (Config.bar.persistent || screenState.bar) ? contentThickness : Config.border.thickness
    readonly property bool shouldBeVisible: !fullscreen && !disabled && (Config.bar.persistent || screenState.bar || isHovered)
    property bool isHovered

    // Space taken from each screen edge, used to position everything that lives inside the frame
    readonly property real insetLeft: onLeft ? thickness : borderThickness
    readonly property real insetRight: onRight ? thickness : borderThickness
    readonly property real insetTop: onTop ? thickness : borderThickness
    readonly property real insetBottom: onBottom ? thickness : borderThickness

    // Same as above but never below the minimum hover thickness (for input regions)
    readonly property real clampedInsetLeft: onLeft ? clampedThickness : Config.border.clampedThickness
    readonly property real clampedInsetRight: onRight ? clampedThickness : Config.border.clampedThickness
    readonly property real clampedInsetTop: onTop ? clampedThickness : Config.border.clampedThickness
    readonly property real clampedInsetBottom: onBottom ? clampedThickness : Config.border.clampedThickness

    // The loaded item is a Bar (vertical) or an HBar (horizontal); both expose the same functions
    function closeTray(): void {
        content.item?.closeTray();
    }

    // pos is the coordinate along the bar's long axis (y for vertical bars, x for horizontal ones)
    function checkPopout(pos: real): void {
        content.item?.checkPopout(pos);
    }

    function handleWheel(pos: real, angleDelta: point): void {
        content.item?.handleWheel(pos, angleDelta);
    }

    // Whether a point (in drawers window coordinates) is over the bar strip
    function isOver(x: real, y: real, winWidth: real, winHeight: real, clamped = false): bool {
        const t = clamped ? clampedThickness : thickness;
        if (onLeft)
            return x < t;
        if (onRight)
            return x > winWidth - t;
        if (onTop)
            return y < t;
        return y > winHeight - t;
    }

    // The wrapper spans the whole frame (the parent sets anchors.fill) and the visible strip is placed
    // with plain bindings below. Conditional anchors don't reset reliably when the edge changes live.

    states: State {
        name: "visible"
        when: root.shouldBeVisible

        PropertyChanges {
            root.thickness: root.contentThickness
        }
    }

    transitions: [
        Transition {
            from: ""
            to: "visible"

            Anim {
                target: root
                property: "thickness"
            }
        },
        Transition {
            from: "visible"
            to: ""

            Anim {
                target: root
                property: "thickness"
                type: Anim.Emphasized
            }
        }
    ]

    // The strip is the part of the bar currently revealed; it grows from the border thickness to the full bar
    Item {
        id: strip

        clip: true
        visible: root.thickness > Config.border.thickness

        x: root.onRight ? root.width - root.thickness : 0
        y: root.onBottom ? root.height - root.thickness : 0
        width: root.vertical ? root.thickness : root.width
        height: root.vertical ? root.height : root.thickness

        Loader {
            id: content

            // Stay flush against the inner edge of the frame while the strip clips the bar in and out
            x: root.onLeft ? strip.width - width : 0
            y: root.onTop ? strip.height - height : 0
            width: root.vertical ? root.contentThickness : strip.width
            height: root.vertical ? strip.height : root.contentThickness

            active: root.shouldBeVisible

            sourceComponent: root.vertical ? verticalBar : horizontalBar
        }
    }

    Component {
        id: verticalBar

        Bar {
            screen: root.screen
            screenState: root.screenState
            popouts: root.popouts // qmllint disable incompatible-type
            fullscreen: root.fullscreen
        }
    }

    Component {
        id: horizontalBar

        HBar {
            screen: root.screen
            screenState: root.screenState
            popouts: root.popouts // qmllint disable incompatible-type
            fullscreen: root.fullscreen
        }
    }
}
