import QtQuick
import Quickshell
import Caelestia.Config
import qs.components
import qs.modules.bar as Bar
import qs.modules.dashboard as Dashboard
import qs.modules.launcher as Launcher
import qs.modules.notch as Notch
import qs.modules.notifications as Notifications
import qs.modules.osd as Osd
import qs.modules.session as Session
import qs.modules.sidebar as Sidebar
import qs.modules.utilities as Utilities
import qs.modules.bar.popouts as BarPopouts
import qs.modules.utilities.toasts as Toasts

Item {
    id: root

    required property ShellScreen screen
    required property ScreenState screenState
    required property Bar.BarWrapper bar
    required property real borderThickness

    readonly property alias osd: osd
    readonly property alias osdWrapper: osdWrapper
    readonly property alias notifications: notifications
    readonly property alias session: session
    readonly property alias sessionWrapper: sessionWrapper
    readonly property alias launcher: launcher
    readonly property alias dashboard: dashboard
    readonly property alias notch: notch
    readonly property alias popouts: popoutsWrapper.content
    readonly property alias popoutsWrapper: popoutsWrapper
    readonly property alias utilities: utilities
    readonly property alias toasts: toasts
    readonly property alias sidebar: sidebar

    // Which side edge each group of panels opens from. Every panel has its own setting (right by default); with
    // the bar on the right and bar.mirrorPanels on, all of them flip to the opposite side.
    readonly property bool flipSides: bar.onRight && Config.bar.mirrorPanels
    readonly property bool osdLeft: (Config.osd.side === PanelSide.Left) !== flipSides
    readonly property bool sessionLeft: (Config.session.side === PanelSide.Left) !== flipSides
    // The sidebar, notifications, utilities and toasts stack together, so they share one side
    readonly property bool stackLeft: (Config.sidebar.side === PanelSide.Left) !== flipSides
    readonly property bool notifsLeft: (Config.notifs.side === PanelSide.Left) !== flipSides
    readonly property bool toastsLeft: (GlobalConfig.utilities.toasts.side === PanelSide.Left) !== flipSides
    readonly property bool notifsTop: Config.notifs.edge === PanelEdge.Top
    readonly property bool toastsTop: GlobalConfig.utilities.toasts.edge === PanelEdge.Top
    // Popups and toasts in the same corner form one column: popups against the screen edge they grow from (top:
    // popups first, bottom: toasts nearest the corner), the toasts next to them
    readonly property bool notifsToastsShared: notifsLeft === toastsLeft && notifsTop === toastsTop
    readonly property bool notifsWithStack: notifsLeft === stackLeft
    readonly property bool toastsWithStack: toastsLeft === stackLeft
    readonly property bool notifPopoutLeft: (GlobalConfig.notifPopout.side === PanelSide.Left) !== flipSides

    // Panels on the same side sit beside each other; panels on different sides don't affect each other
    readonly property bool osdWithSession: osdLeft === sessionLeft
    readonly property bool osdWithStack: osdLeft === stackLeft
    readonly property bool sessionWithStack: sessionLeft === stackLeft

    anchors.fill: parent
    anchors.leftMargin: bar.insetLeft
    anchors.rightMargin: bar.insetRight
    anchors.topMargin: bar.insetTop
    anchors.bottomMargin: bar.insetBottom

    Item {
        id: osdWrapper

        // Opens from the left edge when this panel's side is Left (see the side flags above)
        LayoutMirroring.enabled: root.osdLeft
        LayoutMirroring.childrenInherit: true

        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: (root.osdWithSession ? session.width * (1 - session.offsetScale) : 0) + (root.osdWithStack ? sidebar.width * (1 - sidebar.offsetScale) : 0)
        clip: (root.osdWithStack && sidebar.visible) || (root.osdWithSession && session.visible)

        implicitWidth: osd.implicitWidth * (1 - osd.offsetScale)
        implicitHeight: osd.implicitHeight

        Osd.Wrapper {
            id: osd

            screen: root.screen
            screenState: root.screenState
            sidebarOrSessionVisible: (root.osdWithStack && sidebar.visible) || (root.osdWithSession && session.visible)

            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
        }
    }

    Notifications.Wrapper {
        id: notifications

        LayoutMirroring.enabled: root.notifsLeft
        LayoutMirroring.childrenInherit: true

        screenState: root.screenState
        sidebarPanel: sidebar
        osdPanel: osdWrapper
        sessionPanel: sessionWrapper
        utilitiesPanel: utilities
        osdSame: root.osdLeft === root.notifsLeft
        sessionSame: root.sessionLeft === root.notifsLeft
        utilitiesSame: root.stackLeft === root.notifsLeft
        stackSame: root.notifsWithStack
        atLeft: root.notifsLeft
        atBottom: !root.notifsTop

        // Plain x/y bindings so it can change corner while running. In the top corners it starts just above the
        // panel area (the -5 lets it blend into the frame); at the bottom it sits above whatever holds the corner:
        // the toasts sharing it, or the utilities panel when it is in the sidebar stack.
        readonly property real floorY: root.notifsToastsShared ? toasts.y - (toasts.height > 0 ? toasts.gap : 0) : (root.notifsWithStack ? utilities.y : parent.height)
        x: root.notifsLeft ? 0 : parent.width - width
        y: root.notifsTop ? anchors.topMargin : floorY - height
    }

    Item {
        id: sessionWrapper

        LayoutMirroring.enabled: root.sessionLeft
        LayoutMirroring.childrenInherit: true

        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: root.sessionWithStack ? sidebar.width * (1 - sidebar.offsetScale) : 0
        clip: root.sessionWithStack && sidebar.visible

        implicitWidth: session.implicitWidth * (1 - session.offsetScale)
        implicitHeight: session.implicitHeight

        Session.Wrapper {
            id: session

            screenState: root.screenState
            sidebarVisible: root.sessionWithStack && sidebar.visible

            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
        }
    }

    Launcher.Wrapper {
        id: launcher

        screen: root.screen
        screenState: root.screenState
        panels: root
    }

    Dashboard.Wrapper {
        id: dashboard

        screenState: root.screenState
    }

    Notch.Wrapper {
        id: notch

        screen: root.screen
        screenState: root.screenState
    }

    BarPopouts.ClipWrapper {
        id: popoutsWrapper

        screen: root.screen
        alongInset: root.bar.vertical ? root.bar.insetTop : root.bar.insetLeft
        barPosition: root.bar.position
    }

    Utilities.Wrapper {
        id: utilities

        LayoutMirroring.enabled: root.stackLeft
        LayoutMirroring.childrenInherit: true

        screenState: root.screenState
        sidebar: sidebar
        popouts: popoutsWrapper.content

        anchors.bottom: parent.bottom
        anchors.right: parent.right
    }

    Toasts.Toasts {
        id: toasts

        // Plain x/y bindings, so it can move to the other side (or leave the sidebar stack) while running.
        // Next to the sidebar stack it sits beside the sidebar and above the utilities panel; on its own side
        // it sits in the corner.
        readonly property real gap: Tokens.padding.medium
        // When it shares a top corner it goes below the popups; a bottom corner it holds itself
        fromTop: root.toastsTop
        x: root.toastsWithStack ? (root.stackLeft ? sidebar.x + sidebar.width + gap : sidebar.x - width - gap) : (root.toastsLeft ? gap : parent.width - width - gap)
        y: root.toastsTop ? (root.notifsToastsShared ? notifications.y + notifications.height + (notifications.height > 0 ? gap : 0) : gap) : (root.toastsWithStack && !sidebar.visible ? utilities.y : parent.height) - Math.max(0, height) - gap
    }

    Sidebar.Wrapper {
        id: sidebar

        LayoutMirroring.enabled: root.stackLeft
        LayoutMirroring.childrenInherit: true

        screenState: root.screenState

        anchors.top: root.notifsWithStack && root.notifsTop ? notifications.bottom : parent.top
        anchors.bottom: utilities.top
        anchors.right: parent.right
        anchors.topMargin: root.notifsWithStack && root.notifsTop ? -notifications.anchors.topMargin : 0
    }
}
