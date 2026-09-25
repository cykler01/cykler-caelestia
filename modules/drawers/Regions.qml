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
        panel: root.panels.notch
        y: panel.y + root.bar.insetTop + root.win.notchShift
        height: panel.height * (1 - root.panels.notch.offsetScale)
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

    R {
        panel: root.panels.popoutsWrapper
        width: root.bar.vertical ? panel.width * (1 - root.panels.popoutsWrapper.offsetScale) : panel.width
        height: root.bar.vertical ? panel.height : panel.height * (1 - root.panels.popoutsWrapper.offsetScale)
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
