pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Caelestia.Blobs
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.services
import qs.modules.bar

StyledWindow {
    id: root

    readonly property alias bar: bar
    readonly property alias interactionWrapper: interactions

    readonly property ScreenState screenState: ShellState.forScreen(screen)

    readonly property HyprlandMonitor monitor: Hypr.monitorFor(screen)
    readonly property bool hasSpecialWorkspace: (monitor?.lastIpcObject.specialWorkspace?.name.length ?? 0) > 0
    readonly property bool hasFullscreenOnNormalWs: monitor?.activeWorkspace?.toplevels.values.some(t => t.lastIpcObject.fullscreen > 1) ?? false
    readonly property bool hasFullscreen: {
        if (hasSpecialWorkspace) {
            const specialName = monitor?.lastIpcObject.specialWorkspace?.name;
            if (!specialName)
                return false;
            const specialWs = Hypr.workspaces.values.find(ws => ws.name === specialName);
            return specialWs?.toplevels.values.some(t => t.lastIpcObject.fullscreen > 1) ?? false;
        }
        return hasFullscreenOnNormalWs;
    }

    // On an empty workspace the bar's middle stretch can be dropped so the wallpaper shows through
    // (config bar.hideMiddleOnDesktop). Floating windows don't count as covering the desktop.
    readonly property bool desktopEmpty: monitor?.activeWorkspace?.toplevels?.values.every(t => t.lastIpcObject?.floating) ?? true
    readonly property bool middleHidden: contentItem.Config.bar.hideMiddleOnDesktop && desktopEmpty && bar.hasMiddle && !hasFullscreen
    property real middleProg: middleHidden ? 1 : 0
    // Vertical offset for a panel hanging from the top or bottom edge: while the bar's middle is cut away the
    // frame is thinner there, so a panel sitting in that stretch moves back towards the screen edge to stay
    // attached to it. A panel over one of the bar's ends (or overlapping them) stays where it is.
    function shiftFor(panel: Item, atTop: bool): real {
        if (!(atTop ? bar.onTop : bar.onBottom))
            return 0;

        const left = panel.x + bar.insetLeft;
        if (left < bar.middleStart || left + panel.width > bar.middleEnd)
            return 0;

        return (atTop ? -1 : 1) * bar.cutDepth * middleProg;
    }

    readonly property real dashboardShift: shiftFor(panels.dashboard, panels.dashboard.atTop)
    readonly property real launcherShift: shiftFor(panels.launcher, panels.launcher.atTop)
    readonly property real notchShift: shiftFor(panels.notch, true)

    property real fsTransitionProg: hasFullscreen ? 1 : 0
    readonly property real sdfBorderOffset: 2 * fsTransitionProg // SDFs joins are not exact, so offset by 2px to ensure nothing shows
    readonly property real borderThickness: contentItem.Config.border.thickness * (1 - fsTransitionProg)
    readonly property real borderRounding: contentItem.Config.border.rounding * (1 - fsTransitionProg)
    readonly property real shadowOpacity: 0.7 * (1 - fsTransitionProg)
    readonly property real borderLayoutThickness: hasFullscreen ? 0 : contentItem.Config.border.thickness

    property color surfaceColour: Colours.tPalette.m3surface

    readonly property int dragMaskPadding: {
        if (focusGrab.active || panels.popouts.isDetached)
            return 0;

        if (monitor?.lastIpcObject.specialWorkspace?.name || monitor?.activeWorkspace?.lastIpcObject.windows > 0)
            return 0;

        const thresholds = [];
        for (const panel of ["dashboard", "launcher", "session", "sidebar"])
            if (contentItem.Config[panel].enabled)
                thresholds.push(contentItem.Config[panel].dragThreshold);
        return Math.max(...thresholds);
    }

    onHasFullscreenChanged: {
        screenState.launcher = false;
        screenState.session = false;
        screenState.dashboard = false;
        panels.popouts.close();
    }

    name: "drawers"
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: (fsTransitionProg > 0 && contentItem.Config.general.showOverFullscreen) || (hasSpecialWorkspace && hasFullscreenOnNormalWs) ? WlrLayer.Overlay : WlrLayer.Top
    // The library search field this used to need focus for lives in the popout now, which has
    // its own layer window and takes focus on demand while its library tab is up
    WlrLayershell.keyboardFocus: screenState.launcher || screenState.session ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    mask: hasFullscreen ? emptyRegion : regions

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    Behavior on fsTransitionProg {
        Anim {}
    }

    Behavior on middleProg {
        Anim {}
    }

    Behavior on surfaceColour {
        CAnim {}
    }

    Region {
        id: emptyRegion

        x: panels.notifications.x + bar.insetLeft
        y: panels.notifications.y + bar.insetTop
        width: panels.notifications.width
        height: panels.notifications.height

        Region {
            x: root.width - width
            y: panels.osdWrapper.y + bar.insetTop
            width: panels.osdWrapper.width * (1 - panels.osd.offsetScale) + bar.insetRight
            height: panels.osd.height
        }
    }

    Regions {
        id: regions

        bar: bar
        panels: panels
        win: root
    }

    HyprlandFocusGrab {
        id: focusGrab

        active: {
            const s = root.screenState;
            const conf = root.contentItem.Config;
            if ((s.launcher && conf.launcher.enabled) || (s.session && conf.session.enabled) || (s.sidebar && conf.sidebar.enabled))
                return true;
            if (!conf.dashboard.showOnHover && s.dashboard && conf.dashboard.enabled)
                return true;
            if (panels.popouts.currentName.startsWith("traymenu") && (panels.popouts.current as StackView)?.depth > 1)
                return true;
            return false;
        }
        windows: [root]
        onCleared: {
            root.screenState.launcher = false;
            root.screenState.session = false;
            root.screenState.sidebar = false;
            root.screenState.dashboard = false;
            panels.popouts.hasCurrent = false;
            bar.closeTray();
        }
    }

    StyledRect {
        anchors.fill: parent
        opacity: (root.screenState.session && Config.session.enabled) || panels.popouts.detachedMode !== "" ? 0.5 : 0
        color: Colours.palette.m3scrim

        Behavior on opacity {
            Anim {
                type: Anim.SlowEffects
            }
        }
    }

    Item {
        anchors.fill: parent
        opacity: root.surfaceColour.a
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            blurMax: 15
            shadowColor: Qt.alpha(Colours.palette.m3shadow, Math.max(0, root.shadowOpacity))
        }

        BlobGroup {
            id: blobGroup

            color: root.surfaceColour
            smoothing: root.contentItem.Config.border.smoothing
        }

        BlobInvertedRect {
            anchors.fill: parent
            anchors.margins: -50 // Make border thicker to smooth out bulge from closed drawers
            group: blobGroup
            radius: root.borderRounding
            // Along the bar's edge the frame thins back to the plain border while the middle is hidden;
            // the two capsules below then carry the ends of the bar
            borderLeft: bar.insetLeft - (bar.onLeft ? bar.cutDepth * root.middleProg : 0) - anchors.margins - root.sdfBorderOffset
            borderRight: bar.insetRight - (bar.onRight ? bar.cutDepth * root.middleProg : 0) - anchors.margins - root.sdfBorderOffset
            borderTop: bar.insetTop - (bar.onTop ? bar.cutDepth * root.middleProg : 0) - anchors.margins - root.sdfBorderOffset
            borderBottom: bar.insetBottom - (bar.onBottom ? bar.cutDepth * root.middleProg : 0) - anchors.margins - root.sdfBorderOffset
        }

        // The two ends of the bar while its middle is hidden. Overshoot the screen edge so only the inner
        // corners are rounded, and they join the thin frame like any other hanging panel.
        BlobRect {
            group: blobGroup
            radius: Tokens.rounding.extraLarge
            x: bar.vertical ? (bar.onLeft ? -radius : root.width - bar.thickness) : -radius
            y: bar.vertical ? -radius : (bar.onTop ? -radius : root.height - bar.thickness)
            implicitWidth: root.middleProg <= 0.01 ? 0 : bar.vertical ? bar.thickness + radius : bar.middleStart + radius
            implicitHeight: root.middleProg <= 0.01 ? 0 : bar.vertical ? bar.middleStart + radius : bar.thickness + radius
        }

        BlobRect {
            group: blobGroup
            radius: Tokens.rounding.extraLarge
            x: bar.vertical ? (bar.onLeft ? -radius : root.width - bar.thickness) : bar.middleEnd
            y: bar.vertical ? bar.middleEnd : (bar.onTop ? -radius : root.height - bar.thickness)
            implicitWidth: root.middleProg <= 0.01 ? 0 : bar.vertical ? bar.thickness + radius : root.width - bar.middleEnd + radius
            implicitHeight: root.middleProg <= 0.01 ? 0 : bar.vertical ? root.height - bar.middleEnd + radius : bar.thickness + radius
        }

        PanelBg {
            id: dashBg

            panel: panels.dashboard
            deformAmount: 0.1
            y: panels.dashboard.y + bar.insetTop + root.dashboardShift
        }

        PanelBg {
            id: notchBg

            panel: panels.notch
            deformAmount: 0.1
            y: panels.notch.y + bar.insetTop + root.notchShift
        }

        PanelBg {
            id: launcherBg

            panel: panels.launcher
            deformAmount: 0.1
            y: panels.launcher.y + bar.insetTop + root.launcherShift
        }

        PanelBg {
            id: sessionBg

            panel: panels.sessionWrapper
            deformAmount: 0.2
            x: panels.sessionWrapper.x + panels.session.x + bar.insetLeft
            // Closed panels hide under the frame; with the bar's middle cut away that can be uncovered, so a
            // closed panel gets no size at all (the blob renderer skips empty shapes)
            implicitWidth: panels.session.offsetScale < 0.999 ? panels.session.width : 0
        }

        PanelBg {
            id: sidebarBg

            panel: panels.sidebar
            deformAmount: 0.03
            implicitWidth: panels.sidebar.offsetScale < 0.999 ? panel.width : 0
            implicitHeight: panel.height * (1 / rawDeformMatrix.m22) + 2
            exclude: panels.sidebar.offsetScale > 0.08 ? [] : [utilsBg]
            bottomLeftRadius: Math.max(0, Math.min(1, panels.sidebar.offsetScale / 0.3)) * radius
        }

        PanelBg {
            id: osdBg

            panel: panels.osdWrapper
            deformAmount: 0.25
            x: panels.osdWrapper.x + panels.osd.x + bar.insetLeft
            implicitWidth: panels.osd.offsetScale < 0.999 ? panels.osd.width : 0
        }

        PanelBg {
            id: notifsBg

            panel: panels.notifications
        }

        PanelBg {
            id: utilsBg

            panel: panels.utilities
            deformAmount: panels.sidebar.visible ? 0.1 : 0.15
            implicitWidth: panels.utilities.offsetScale < 0.999 ? panel.width : 0
            exclude: panels.sidebar.offsetScale > 0.08 ? [] : [sidebarBg]
            topLeftRadius: Math.max(0, Math.min(1, panels.sidebar.offsetScale / 0.3)) * radius
        }

        PanelBg {
            id: popoutBg

            // Extra width to prevent vertical movement deformation partially detaching panel from bar
            property real extraWidth: panels.popouts.isDetached ? 0 : 0.2
            // The extra size is tucked under the bar, so it grows towards the bar's side
            readonly property real extraOffset: (bar.onRight || bar.onBottom) && !panels.popouts.isDetached ? 0 : (bar.vertical ? panels.popouts.width : panels.popouts.height) * extraWidth

            // A closed popout tucks itself under the bar band; with the bar's middle cut away nothing covers that
            // spot any more, so the box is given no size at all while the popout is closed (the blob renderer skips
            // empty shapes, it does not look at `visible`)
            readonly property bool open: panels.popoutsWrapper.offsetScale < 0.999

            panel: panels.popoutsWrapper
            deformAmount: panels.popouts.isDetached ? 0.05 : panels.popouts.hasCurrent ? 0.15 : 0.1
            x: bar.vertical ? panels.popoutsWrapper.x + panels.popouts.x + bar.insetLeft - extraOffset : panels.popoutsWrapper.x + bar.insetLeft
            y: bar.vertical ? panels.popoutsWrapper.y + bar.insetTop : panels.popoutsWrapper.y + panels.popouts.y + bar.insetTop - extraOffset
            implicitWidth: !open ? 0 : bar.vertical ? panels.popouts.width * (1 + extraWidth) : panels.popoutsWrapper.width
            implicitHeight: !open ? 0 : bar.vertical ? panels.popoutsWrapper.height : panels.popouts.height * (1 + extraWidth)

            Behavior on extraWidth {
                Anim {}
            }
        }
    }

    Interactions {
        id: interactions

        screen: root.screen
        popouts: panels.popouts
        screenState: root.screenState
        panels: panels
        bar: bar
        borderThickness: root.borderLayoutThickness
        fullscreen: root.hasFullscreen

        Panels {
            id: panels

            screen: root.screen
            screenState: root.screenState
            bar: bar
            borderThickness: root.borderThickness

            utilities.horizontalStretch: (sidebarBg.rawDeformMatrix.m11 - 1) / 2 + 1
            utilities.deformMatrix: utilsBg.rawDeformMatrix

            dashboard.transform: [
                Matrix4x4 {
                    matrix: dashBg.deformMatrix
                },
                Translate {
                    y: root.dashboardShift
                }
            ]
            launcher.transform: [
                Matrix4x4 {
                    matrix: launcherBg.deformMatrix
                },
                Translate {
                    y: root.launcherShift
                }
            ]
            notch.transform: Translate {
                y: root.notchShift
            }
            session.transform: Matrix4x4 {
                matrix: sessionBg.deformMatrix
            }
            sidebar.transform: Matrix4x4 {
                matrix: sidebarBg.deformMatrix
            }
            osd.transform: Matrix4x4 {
                matrix: osdBg.deformMatrix
            }
            notifications.transform: Matrix4x4 {
                matrix: notifsBg.deformMatrix
            }
            utilities.transform: Matrix4x4 {
                matrix: utilsBg.deformMatrix
            }
            popouts.transform: Matrix4x4 {
                matrix: popoutBg.deformMatrix
            }
        }

        BarWrapper {
            id: bar

            // Spans the frame; the bar positions its own strip on the configured edge
            anchors.fill: parent

            screen: root.screen
            screenState: root.screenState
            popouts: panels.popouts

            fullscreen: root.hasFullscreen
            borderThickness: root.borderThickness
        }
    }

    ShellState.ComponentRef {
        screen: root.screen
        slot: "rootWindow"
        component: root
    }

    ShellState.ComponentRef {
        screen: root.screen
        slot: "interactionWrapper"
        component: interactions
    }

    ShellState.ComponentRef {
        screen: root.screen
        slot: "bar"
        component: bar
    }

    ShellState.ComponentRef {
        screen: root.screen
        slot: "panels"
        component: panels
    }

    component PanelBg: BlobRect {
        required property Item panel
        property real deformAmount: 0.15

        group: blobGroup
        x: panel.x + bar.insetLeft
        y: panel.y + bar.insetTop
        implicitWidth: panel.width
        implicitHeight: panel.height
        radius: Tokens.rounding.extraLarge
        deformScale: (deformAmount * Config.appearance.deformScale) / 10000
    }
}
