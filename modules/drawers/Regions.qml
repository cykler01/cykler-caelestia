pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.modules.bar as Bar

Region {
    id: root

    required property Bar.BarWrapper bar
    required property Panels panels
    required property var win

    x: bar.clampedInsetLeft + win.dragMaskPadding
    y: bar.clampedInsetTop + win.dragMaskPadding
    width: win.width - bar.clampedInsetLeft - bar.clampedInsetRight - win.dragMaskPadding * 2
    height: win.height - bar.clampedInsetTop - bar.clampedInsetBottom - win.dragMaskPadding * 2
    intersection: Intersection.Xor

    R {
        panel: root.panels.dashboard
        y: root.panels.dashboard.atTop ? 0 : root.win.height - height
        height: panel.height * (1 - root.panels.dashboard.offsetScale) + (root.panels.dashboard.atTop ? root.bar.insetTop : root.bar.insetBottom)
    }

    R {
        panel: root.panels.launcher
        y: root.panels.launcher.atTop ? 0 : root.win.height - height
        height: panel.height * (1 - root.panels.launcher.offsetScale) + (root.panels.launcher.atTop ? root.bar.insetTop : root.bar.insetBottom)
    }

    R {
        id: sessionRegion

        panel: root.panels.sessionWrapper
        x: root.panels.sessionLeft ? 0 : root.win.width - width
        width: panel.width * (1 - root.panels.session.offsetScale) + (root.panels.sessionLeft ? root.bar.insetLeft : root.bar.insetRight) + (root.panels.sessionWithStack ? sidebarRegion.width : 0)
    }

    R {
        id: sidebarRegion

        panel: root.panels.sidebar
        x: root.panels.stackLeft ? 0 : root.win.width - width
        width: panel.width * (1 - root.panels.sidebar.offsetScale) + (root.panels.stackLeft ? root.bar.insetLeft : root.bar.insetRight)
    }

    R {
        panel: root.panels.osdWrapper
        x: root.panels.osdLeft ? 0 : root.win.width - width
        width: panel.width * (1 - root.panels.osd.offsetScale) + (root.panels.osdLeft ? root.bar.insetLeft : root.bar.insetRight) + (root.panels.osdWithSession ? sessionRegion.width : root.panels.osdWithStack ? sidebarRegion.width : 0)
    }

    R {
        panel: root.panels.notifications
        y: 0
        height: panel.height + root.bar.insetTop
    }

    R {
        panel: root.panels.utilities
        y: root.win.height - height
        height: panel.height * (1 - root.panels.utilities.offsetScale) + root.bar.insetBottom
    }

    // While a popout is open its input area is its final one, not the one it is animating through, so the pointer
    // can move onto it as soon as it starts to appear
    Region {
        readonly property Item p: root.panels.popoutsWrapper
        readonly property bool open: root.panels.popouts.hasCurrent || root.panels.popouts.isDetached

        x: root.bar.insetLeft + (open ? p.targetX : p.x)
        y: root.bar.insetTop + (open ? p.targetY : p.y)
        width: open ? p.targetW : (root.bar.vertical ? p.width * (1 - p.offsetScale) : p.width)
        height: open ? p.targetH : (root.bar.vertical ? p.height : p.height * (1 - p.offsetScale))
        intersection: Intersection.Subtract
    }

    // NOTE(fork): the notch's side bubbles take the pointer, so they can open on hover and be put
    // away again. The notch pill itself takes it too, for the marks a put-away bubble leaves on it
    // (see modules/notch/Pill.qml) - without that there would be no way to bring one back.
    N {
        item: root.panels.notch
    }

    N {
        item: root.panels.notch.downloadBubble
    }

    N {
        item: root.panels.notch.timerBubble
    }

    N {
        item: root.panels.notch.stopwatchBubble
    }

    // Something inside the notch, placed in the notch's own coordinates. Nothing at all while it is
    // not on screen, so a hidden bubble does not go on swallowing clicks at the top of the screen.
    component N: Region {
        required property Item item

        readonly property Item notch: root.panels.notch
        // The pill only takes the pointer while it is carrying a mark to press; the bubbles always
        // do, since hovering one is the whole point of them
        readonly property bool on: root.panels.notch.visible && item.visible && (item !== notch || notch.hasMarks)

        x: root.bar.insetLeft + notch.x + (item === notch ? 0 : item.x)
        y: root.bar.insetTop + notch.y + (item === notch ? 0 : item.y)
        width: on ? item.width : 0
        height: on ? item.height : 0
        intersection: Intersection.Subtract
    }

    component R: Region {
        required property Item panel

        x: panel.x + root.bar.insetLeft
        y: panel.y + root.bar.insetTop
        width: panel.width
        height: panel.height
        intersection: Intersection.Subtract
    }
}
