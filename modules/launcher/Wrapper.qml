pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components
import qs.modules.launcher.services

Item {
    id: root

    required property ShellScreen screen
    required property ScreenState screenState
    required property var panels

    readonly property bool shouldBeActive: screenState.launcher && Config.launcher.enabled

    readonly property real maxHeight: {
        let max = screen.height - Config.border.thickness * 2 + Tokens.padding.extraLarge;
        if (screenState.dashboard)
            max -= panels.dashboard.nonAnimHeight;
        return max;
    }

    property real offsetScale: shouldBeActive ? 0 : 1

    // Which edge the launcher hangs from and where along it (config launcher.edge / launcher.align)
    readonly property bool atTop: Config.launcher.edge === PanelEdge.Top
    readonly property int align: Config.launcher.align

    onShouldBeActiveChanged: {
        if (shouldBeActive)
            implicitHeight = Qt.binding(() => content.implicitHeight);
        else
            implicitHeight = implicitHeight; // Break binding during close anim
    }

    visible: offsetScale < 1
    // Plain x/y bindings rather than anchors, which don't reset reliably when the edge changes live
    x: align === PanelAlign.Start ? 0 : align === PanelAlign.End ? parent.width - width : (parent.width - width) / 2
    y: atTop ? (-height - 5) * offsetScale : parent.height - height + (height + 5) * offsetScale
    implicitHeight: content.implicitHeight
    implicitWidth: content.implicitWidth || 630 // Hard coded fallback for first open
    opacity: 1 - offsetScale

    Component.onCompleted: Qt.callLater(() => Apps) // Load apps on init

    Behavior on offsetScale {
        Anim {}
    }

    Loader {
        id: content

        x: (parent.width - width) / 2
        // Flush with the wrapper's inner edge: the panel's far side from the screen edge it hangs from
        y: root.atTop ? parent.height - height : 0

        active: root.shouldBeActive || root.visible

        sourceComponent: Content {
            screenState: root.screenState
            panels: root.panels
            maxHeight: root.maxHeight
            flipped: root.atTop
        }
    }
}
