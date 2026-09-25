import QtQuick
import QtQuick.Controls
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.modules.bar as Bar
import qs.modules.bar.popouts as BarPopouts

CustomMouseArea {
    id: root

    required property ShellScreen screen
    required property BarPopouts.Wrapper popouts
    required property ScreenState screenState
    required property Panels panels
    required property Bar.BarWrapper bar
    required property real borderThickness
    required property bool fullscreen

    property point dragStart
    property bool dashboardShortcutActive
    property bool osdShortcutActive
    property bool utilitiesShortcutActive

    // Top-left hot corner, opens the window overview (see the overview module)
    readonly property bool overviewHotCorner: Config.overview.enabled && Config.overview.hotCorner && !fullscreen
    readonly property int hotCornerSize: GlobalConfig.overview.hotCornerSize
    property bool inHotCorner

    function updateHotCorner(x: real, y: real): void {
        if (!root.overviewHotCorner) {
            root.inHotCorner = false;
            hotCornerTimer.stop();
            return;
        }

        const inCorner = x <= root.hotCornerSize && y <= root.hotCornerSize;
        if (inCorner === root.inHotCorner)
            return;

        root.inHotCorner = inCorner;
        if (inCorner)
            hotCornerTimer.restart();
        else
            hotCornerTimer.stop();
    }

    function withinPanelHeight(panel: Item, x: real, y: real): bool {
        const panelY = bar.insetTop + panel.y;
        return y >= panelY - Config.border.rounding && y <= panelY + panel.height + Config.border.rounding;
    }

    function withinPanelWidth(panel: Item, x: real, y: real): bool {
        const panelX = bar.insetLeft + panel.x;
        return x >= panelX - Config.border.rounding && x <= panelX + panel.width + Config.border.rounding;
    }

    function inLeftPanel(panel: Item, x: real, y: real): bool {
        return x < bar.insetLeft + panel.x + panel.width && withinPanelHeight(panel, x, y);
    }

    function inRightPanel(panel: Item, x: real, y: real): bool {
        // A bar on this edge takes priority over panels that would otherwise be triggered from it
        if (bar.onRight && x > width - bar.clampedThickness)
            return false;
        return x > Math.min(width - Config.border.minThickness, bar.insetLeft + panel.x) && withinPanelHeight(panel, x, y);
    }

    // Whether the pointer is over the bar popout's final area, or the gap between it and the bar. Uses the popout's
    // target geometry rather than its animated one, so it can be reached while it is still opening.
    function inPopout(x: real, y: real): bool {
        const w = panels.popoutsWrapper;
        const m = Config.border.rounding;
        let l = bar.insetLeft + w.targetX - m;
        let r = bar.insetLeft + w.targetX + w.targetW + m;
        let t = bar.insetTop + w.targetY - m;
        let b = bar.insetTop + w.targetY + w.targetH + m;
        if (bar.onLeft)
            l = 0;
        else if (bar.onRight)
            r = width;
        else if (bar.onTop)
            t = 0;
        else
            b = height;
        return x >= l && x <= r && y >= t && y <= b;
    }

    // The empty stretch of the bar between its two ends: panels on the bar's own edge can still be reached from it
    function inBarMiddle(x: real): bool {
        return bar.hasMiddle && x >= bar.middleStart && x <= bar.middleEnd;
    }

    function inTopPanel(panel: Item, x: real, y: real): bool {
        const panelHeight = panel.height * (1 - (panel.offsetScale ?? 0)); // qmllint disable missing-property
        if (bar.onTop && y < bar.clampedThickness && !inBarMiddle(x))
            return false;
        return y < Math.max(Config.border.minThickness, bar.insetTop + panelHeight) && withinPanelWidth(panel, x, y);
    }

    function inBottomPanel(panel: Item, x: real, y: real, isCorner = false): bool {
        const panelHeight = panel.height * (1 - (panel.offsetScale ?? 0)); // qmllint disable missing-property
        if (bar.onBottom && y > height - bar.clampedThickness && !inBarMiddle(x))
            return false;
        return y > height - Math.max(Config.border.minThickness, bar.insetBottom + panelHeight) - (isCorner ? Config.border.rounding : 0) && withinPanelWidth(panel, x, y);
    }

    // Panels that open from a side edge (OSD, session menu, sidebar) can each be on the left or the right
    function inSidePanel(panel: Item, left: bool, x: real, y: real): bool {
        return left ? inLeftPanel(panel, x, y) : inRightPanel(panel, x, y);
    }

    // Whether px is at the screen edge such a panel comes from (or over the panel itself)
    function atSideEdge(px: real, panel: Item, left: bool): bool {
        if (left)
            return px < Math.max(Config.border.minThickness, bar.insetLeft + panel.x + panel.width);
        return px > Math.min(width - Config.border.minThickness, bar.insetLeft + panel.x);
    }

    // Positive when a drag moves away from the edge such a panel comes from (into the screen)
    function inward(dx: real, left: bool): real {
        return left ? dx : -dx;
    }

    // Whether px is clear of the open sidebar, if the panel in question sits on the sidebar's side
    function outOfSidebar(px: real, left: bool): bool {
        if (left !== panels.stackLeft)
            return true;
        const w = panels.sidebar.width * (1 - panels.sidebar.offsetScale);
        return left ? px > w : px < width - w;
    }

    // Whether the pointer is in the trigger zone of a panel hanging from the top or bottom edge
    function inEdgePanel(panel: Item, atTop: bool, x: real, y: real, isCorner = false): bool {
        return atTop ? inTopPanel(panel, x, y) : inBottomPanel(panel, x, y, isCorner);
    }

    function onWheel(event: WheelEvent): void {
        if (fullscreen)
            return;
        if (bar.isOver(event.x, event.y, width, height)) {
            bar.handleWheel(bar.vertical ? event.y : event.x, event.angleDelta);
        }
    }

    // Short dwell so brushing past the corner doesn't open the overview
    Timer {
        id: hotCornerTimer

        interval: 150
        onTriggered: {
            if (root.inHotCorner)
                root.screenState.overview = true;
        }
    }

    anchors.fill: parent
    acceptedButtons: fullscreen ? Qt.NoButton : Qt.AllButtons
    hoverEnabled: true

    onPressed: event => dragStart = Qt.point(event.x, event.y)
    onContainsMouseChanged: {
        if (!containsMouse) {
            root.inHotCorner = false;
            hotCornerTimer.stop();

            // Only hide if not activated by shortcut
            if (!osdShortcutActive) {
                screenState.osd = false;
                root.panels.osd.hovered = false;
            }

            if (!dashboardShortcutActive)
                screenState.dashboard = false;

            if (!utilitiesShortcutActive)
                screenState.utilities = false;

            if (!popouts.currentName.startsWith("traymenu") || ((popouts.current as StackView)?.depth ?? 0) <= 1) {
                popouts.hasCurrent = false;
                bar.closeTray();
            }

            if (Config.bar.showOnHover)
                bar.isHovered = false;

            if (Config.sidebar.showOnHover)
                screenState.sidebar = false;
        }
    }

    onPositionChanged: event => {
        root.updateHotCorner(event.x, event.y);

        if (popouts.isDetached)
            return;

        const x = event.x;
        const y = event.y;
        const dragX = x - dragStart.x;
        const dragY = y - dragStart.y;

        if (fullscreen) {
            root.panels.osd.hovered = inSidePanel(panels.osdWrapper, panels.osdLeft, x, y);
            return;
        }

        // Show bar in non-exclusive mode on hover
        if (!screenState.bar && Config.bar.showOnHover && bar.isOver(x, y, width, height, true))
            bar.isHovered = true;

        // Show/hide bar on drag (dragging away from its edge reveals it)
        if (pressed && bar.isOver(dragStart.x, dragStart.y, width, height, true)) {
            const barDrag = bar.onLeft ? dragX : bar.onRight ? -dragX : bar.onTop ? dragY : -dragY;
            if (barDrag > Config.bar.dragThreshold)
                screenState.bar = true;
            else if (barDrag < -Config.bar.dragThreshold)
                screenState.bar = false;
        }

        if (panels.sidebar.offsetScale === 1) {
            // Show osd on hover
            const showOsd = inSidePanel(panels.osdWrapper, panels.osdLeft, x, y);

            // Always update visibility based on hover if not in shortcut mode
            if (!osdShortcutActive) {
                screenState.osd = showOsd;
                root.panels.osd.hovered = showOsd;
            } else if (showOsd) {
                // If hovering over OSD area while in shortcut mode, transition to hover control
                osdShortcutActive = false;
                root.panels.osd.hovered = true;
            }

            const showSidebar = pressed && atSideEdge(dragStart.x, panels.sidebar, panels.stackLeft);

            // Show sidebar on hover (top-right corner, bounded by notification panel height)
            if (Config.sidebar.showOnHover) {
                const sidebarTriggerY = Math.max(Config.sidebar.minHoverThreshold, panels.notifsWithStack ? panels.notifications.y + panels.notifications.height + borderThickness : 0);
                const showSidebarHover = atSideEdge(x, panels.sidebar, panels.stackLeft) && y <= sidebarTriggerY;
                if (showSidebarHover && !screenState.sidebar)
                    screenState.sidebar = true;
            }

            // Show/hide session on drag
            if (pressed && inSidePanel(panels.sessionWrapper, panels.sessionLeft, dragStart.x, dragStart.y) && withinPanelHeight(panels.sessionWrapper, x, y)) {
                const sessionInward = inward(dragX, panels.sessionLeft);
                if (sessionInward > Config.session.dragThreshold)
                    screenState.session = true;
                else if (sessionInward < -Config.session.dragThreshold)
                    screenState.session = false;

                // Show sidebar on drag if in session area and session is nearly fully visible
                if (showSidebar && panels.session.offsetScale <= 0 && inward(dragX, panels.stackLeft) > Config.sidebar.dragThreshold)
                    screenState.sidebar = true;
            } else if (showSidebar && inward(dragX, panels.stackLeft) > Config.sidebar.dragThreshold) {
                // Show sidebar on drag if not in session area
                screenState.sidebar = true;
            }
        } else {
            // Show osd on hover
            const showOsd = outOfSidebar(x, panels.osdLeft) && inSidePanel(panels.osdWrapper, panels.osdLeft, x, y);

            // Always update visibility based on hover if not in shortcut mode
            if (!osdShortcutActive) {
                screenState.osd = showOsd;
                root.panels.osd.hovered = showOsd;
            } else if (showOsd) {
                // If hovering over OSD area while in shortcut mode, transition to hover control
                osdShortcutActive = false;
                root.panels.osd.hovered = true;
            }

            // Show/hide session on drag
            if (pressed && outOfSidebar(x, panels.sessionLeft) && inSidePanel(panels.sessionWrapper, panels.sessionLeft, dragStart.x, dragStart.y) && withinPanelHeight(panels.sessionWrapper, x, y)) {
                const sessionInward = inward(dragX, panels.sessionLeft);
                if (sessionInward > Config.session.dragThreshold)
                    screenState.session = true;
                else if (sessionInward < -Config.session.dragThreshold)
                    screenState.session = false;
            }

            // Show/hide sidebar on hover
            if (Config.sidebar.showOnHover && !pressed) {
                const sidebarTriggerY = Math.max(Config.sidebar.minHoverThreshold, panels.notifsWithStack ? panels.notifications.y + panels.notifications.height + borderThickness : 0);
                const showSidebarHover = atSideEdge(x, panels.sidebar, panels.stackLeft) && y <= sidebarTriggerY;
                if (showSidebarHover && !screenState.sidebar) {
                    screenState.sidebar = true;
                } else {
                    const inSidebarArea = inSidePanel(panels.sidebar, panels.stackLeft, x, y) || (panels.sessionWithStack && inSidePanel(panels.sessionWrapper, panels.sessionLeft, x, y));
                    if (!inSidebarArea)
                        screenState.sidebar = false;
                }
            }

            // Hide sidebar on drag
            if (pressed && inSidePanel(panels.sidebar, panels.stackLeft, dragStart.x, 0) && inward(dragX, panels.stackLeft) < -Config.sidebar.dragThreshold)
                screenState.sidebar = false;
        }

        // Show launcher on hover, or show/hide on drag if hover is disabled
        if (Config.launcher.showOnHover) {
            if (!screenState.launcher && inEdgePanel(panels.launcher, panels.launcher.atTop, x, y))
                screenState.launcher = true;
        } else if (pressed && inEdgePanel(panels.launcher, panels.launcher.atTop, dragStart.x, dragStart.y) && withinPanelWidth(panels.launcher, x, y)) {
            // Dragging away from the edge it hangs from opens it
            const launcherDrag = panels.launcher.atTop ? dragY : -dragY;
            if (launcherDrag > Config.launcher.dragThreshold)
                screenState.launcher = true;
            else if (launcherDrag < -Config.launcher.dragThreshold)
                screenState.launcher = false;
        }

        // Show dashboard on hover
        const showDashboard = Config.dashboard.showOnHover && inEdgePanel(panels.dashboard, panels.dashboard.atTop, x, y);

        // Always update visibility based on hover if not in shortcut mode
        if (!dashboardShortcutActive) {
            screenState.dashboard = showDashboard;
        } else if (showDashboard) {
            // If hovering over dashboard area while in shortcut mode, transition to hover control
            dashboardShortcutActive = false;
        }

        // Show/hide dashboard on drag (for touchscreen devices)
        if (pressed && inEdgePanel(panels.dashboard, panels.dashboard.atTop, dragStart.x, dragStart.y) && withinPanelWidth(panels.dashboard, x, y)) {
            const dashboardDrag = panels.dashboard.atTop ? dragY : -dragY;
            if (dashboardDrag > Config.dashboard.dragThreshold)
                screenState.dashboard = true;
            else if (dashboardDrag < -Config.dashboard.dragThreshold)
                screenState.dashboard = false;
        }

        // Show utilities on hover
        const showUtilities = inBottomPanel(panels.utilities, x, y, true);

        // Always update visibility based on hover if not in shortcut mode
        if (!utilitiesShortcutActive) {
            screenState.utilities = showUtilities;
        } else if (showUtilities) {
            // If hovering over utilities area while in shortcut mode, transition to hover control
            utilitiesShortcutActive = false;
        }

        // Show popouts on hover
        if (bar.isOver(x, y, width, height)) {
            bar.checkPopout(bar.vertical ? y : x);
        } else if ((!popouts.currentName.startsWith("traymenu") || ((popouts.current as StackView)?.depth ?? 0) <= 1) && !inPopout(x, y)) {
            popouts.hasCurrent = false;
            bar.closeTray();
        }
    }

    // Monitor individual visibility changes
    Connections {
        function onLauncherChanged() {
            // If launcher is hidden, clear shortcut flags for dashboard and OSD
            if (!root.screenState.launcher) {
                root.dashboardShortcutActive = false;
                root.osdShortcutActive = false;
                root.utilitiesShortcutActive = false;

                // Also hide dashboard and OSD if they're not being hovered
                const inDashboardArea = root.inEdgePanel(root.panels.dashboard, root.panels.dashboard.atTop, root.mouseX, root.mouseY);
                const inOsdArea = root.inSidePanel(root.panels.osdWrapper, root.panels.osdLeft, root.mouseX, root.mouseY);

                if (!inDashboardArea) {
                    root.screenState.dashboard = false;
                }
                if (!inOsdArea) {
                    root.screenState.osd = false;
                    root.panels.osd.hovered = false;
                }
            }
        }

        function onDashboardChanged() {
            if (root.screenState.dashboard) {
                // Dashboard became visible, immediately check if this should be shortcut mode
                const inDashboardArea = root.inEdgePanel(root.panels.dashboard, root.panels.dashboard.atTop, root.mouseX, root.mouseY);
                if (!inDashboardArea) {
                    root.dashboardShortcutActive = true;
                }
            } else {
                // Dashboard hidden, clear shortcut flag
                root.dashboardShortcutActive = false;
            }
        }

        function onOsdChanged() {
            if (root.screenState.osd) {
                // OSD became visible, immediately check if this should be shortcut mode
                const inOsdArea = root.inSidePanel(root.panels.osdWrapper, root.panels.osdLeft, root.mouseX, root.mouseY);
                if (!inOsdArea) {
                    root.osdShortcutActive = true;
                }
            } else {
                // OSD hidden, clear shortcut flag
                root.osdShortcutActive = false;
            }
        }

        function onUtilitiesChanged() {
            if (root.screenState.utilities) {
                // Utilities became visible, immediately check if this should be shortcut mode
                const inUtilitiesArea = root.inBottomPanel(root.panels.utilities, root.mouseX, root.mouseY);
                if (!inUtilitiesArea) {
                    root.utilitiesShortcutActive = true;
                }
            } else {
                // Utilities hidden, clear shortcut flag
                root.utilitiesShortcutActive = false;
            }
        }

        target: root.screenState
    }
}
