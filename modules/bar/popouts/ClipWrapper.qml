pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components
import qs.modules.bar.popouts // Need to import this module so the Wrapper type is the same as others

Item {
    id: root

    required property ShellScreen screen
    // Inset of the panel area along the bar's long axis (top inset for vertical bars, left inset for horizontal ones)
    required property real alongInset
    required property int barPosition

    readonly property bool onLeft: barPosition === BarPosition.Left
    readonly property bool onRight: barPosition === BarPosition.Right
    readonly property bool onTop: barPosition === BarPosition.Top
    readonly property bool onBottom: barPosition === BarPosition.Bottom
    readonly property bool vertical: onLeft || onRight

    readonly property alias content: content
    property real offsetScale: content.isDetached || content.hasCurrent || (onLeft && x > 0) || (onTop && y > 0) ? 0 : 1

    visible: width > 0 && height > 0
    clip: true

    implicitWidth: vertical ? content.implicitWidth * (1 - offsetScale) : content.implicitWidth
    implicitHeight: vertical ? content.implicitHeight : content.implicitHeight * (1 - offsetScale)

    // Attached to the far edge of the panel area (next to a right/bottom bar); computed rather than
    // anchored, since an x/y binding would override an anchor
    readonly property bool rightAttached: onRight && !content.isDetached
    readonly property bool bottomAttached: onBottom && !content.isDetached

    // Position along the bar's long axis, following the hovered icon and clamped to the panel area
    function alongPos(size: real, available: real): real {
        const off = content.currentCenter - alongInset - size / 2;
        const diff = available - Math.floor(off + size);
        if (diff < 0)
            return off + diff;
        return Math.max(off, 0);
    }

    x: {
        if (content.isDetached)
            return (parent.width - content.nonAnimWidth) / 2;
        if (rightAttached)
            return parent.width - width;
        return vertical ? 0 : alongPos(content.nonAnimWidth, parent.width);
    }
    y: {
        if (content.isDetached)
            return (parent.height - content.nonAnimHeight) / 2;
        if (bottomAttached)
            return parent.height - height;
        return vertical ? alongPos(content.nonAnimHeight, parent.height) : 0;
    }

    Behavior on offsetScale {
        Anim {}
    }

    // Stay glued to the bar edge while the popout resizes; only animate to/from the detached position
    Behavior on x {
        enabled: !root.rightAttached

        Anim {
            duration: content.animLength
            easing: content.animCurve
        }
    }

    Behavior on y {
        enabled: root.offsetScale < 1 && !root.bottomAttached

        Anim {
            duration: content.animLength
            easing: content.animCurve
        }
    }

    Wrapper {
        id: content

        screen: root.screen
        offsetScale: root.offsetScale

        // Centred on the cross axis; on the bar axis it is flush with the bar edge and slid out past it by the offset
        // (plain bindings rather than anchors, which don't reset reliably when the bar edge changes live)
        x: root.vertical ? (root.onRight ? parent.width - width + (width + 5) * root.offsetScale : (-width - 5) * root.offsetScale) : (parent.width - width) / 2
        y: root.vertical ? (parent.height - height) / 2 : (root.onBottom ? parent.height - height + (height + 5) * root.offsetScale : (-height - 5) * root.offsetScale)
    }
}
