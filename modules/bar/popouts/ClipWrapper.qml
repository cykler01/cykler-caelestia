pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.components
import qs.modules.bar.popouts // Need to import this module so the Wrapper type is the same as others

Item {
    id: root

    required property ShellScreen screen
    required property real borderThickness
    // Attach to the right edge of the panel area instead of the left
    required property bool barOnRight

    readonly property alias content: content
    property real offsetScale: content.isDetached || content.hasCurrent || (!barOnRight && x > 0) ? 0 : 1

    visible: width > 0 && height > 0
    clip: true

    implicitWidth: content.implicitWidth * (1 - offsetScale)
    implicitHeight: content.implicitHeight

    // Anchors keep the right-attached popout flush with the bar; they are dropped while detached so x can animate
    anchors.right: barOnRight && !content.isDetached ? parent.right : undefined

    x: content.isDetached ? (parent.width - content.nonAnimWidth) / 2 : 0
    y: {
        if (content.isDetached)
            return (parent.height - content.nonAnimHeight) / 2;

        const off = content.currentCenter - borderThickness - content.nonAnimHeight / 2;
        const diff = parent.height - Math.floor(off + content.nonAnimHeight);
        if (diff < 0)
            return off + diff;
        return Math.max(off, 0);
    }

    Behavior on offsetScale {
        Anim {}
    }

    Behavior on x {
        Anim {
            duration: content.animLength
            easing: content.animCurve
        }
    }

    Behavior on y {
        enabled: root.offsetScale < 1

        Anim {
            duration: content.animLength
            easing: content.animCurve
        }
    }

    Wrapper {
        id: content

        screen: root.screen
        offsetScale: root.offsetScale

        anchors.verticalCenter: parent.verticalCenter
        anchors.left: root.barOnRight ? undefined : parent.left
        anchors.right: root.barOnRight ? parent.right : undefined
        anchors.leftMargin: (-implicitWidth - 5) * root.offsetScale
        anchors.rightMargin: (-implicitWidth - 5) * root.offsetScale
    }
}
