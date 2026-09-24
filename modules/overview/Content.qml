pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services

Item {
    id: root

    required property ShellScreen screen
    required property ScreenState screenState
    required property real reveal

    readonly property var monitor: Hypr.monitorFor(screen)
    readonly property int activeWsId: monitor?.activeWorkspace?.id ?? 1

    // 2x5 grid of the ten workspaces around the focused one, centred on the screen
    readonly property int columns: 5
    readonly property int rows: 2
    readonly property int perGroup: columns * rows
    readonly property int groupStart: Math.floor((Math.max(1, activeWsId) - 1) / perGroup) * perGroup + 1
    readonly property var workspaceIds: Array.from({
        length: perGroup
    }, (_, i) => groupStart + i)

    readonly property int gap: Tokens.spacing.large
    // The grid only ever takes a fraction of the screen, so the tiles stay a modest
    // size and there is plenty of room left around them
    readonly property real gridMaxWidth: root.width * 0.8
    readonly property real gridMaxHeight: root.height * 0.7
    // Each tile is a 16:9 representation of one workspace, as large as the grid allows.
    // The window is unmapped between openings, so guard the size against a zero width.
    readonly property real cardWidth: Math.max(1, Math.floor(Math.min((root.gridMaxWidth - root.gap * (root.columns - 1)) / root.columns, ((root.gridMaxHeight - root.gap * (root.rows - 1)) / root.rows) * 16 / 9)))
    readonly property real cardHeight: Math.round(root.cardWidth * 9 / 16)
    readonly property real gridWidth: root.cardWidth * root.columns + root.gap * (root.columns - 1)
    readonly property real gridHeight: root.cardHeight * root.rows + root.gap * (root.rows - 1)

    function close(): void {
        root.screenState.overview = false;
    }

    focus: true

    onRevealChanged: {
        if (root.reveal > 0)
            root.forceActiveFocus();
    }

    Connections {
        function onOverviewChanged(): void {
            if (root.screenState.overview)
                root.forceActiveFocus();
        }

        target: root.screenState
    }

    Keys.onEscapePressed: root.close()
    Keys.onPressed: event => {
        // 1-9 jump within the group, 0 is the tenth
        let position = -1;
        if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9)
            position = event.key - Qt.Key_0;
        else if (event.key === Qt.Key_0)
            position = 10;

        if (position > 0 && position <= root.perGroup) {
            Hypr.focusWorkspace(root.groupStart + position - 1);
            root.close();
            event.accepted = true;
        }
    }

    StyledRect {
        anchors.fill: parent
        color: Qt.alpha(Colours.palette.m3scrim, 0.55)

        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }
    }

    StyledRect {
        id: panel

        anchors.centerIn: parent
        implicitWidth: root.gridWidth + Tokens.padding.extraLarge * 2
        implicitHeight: root.gridHeight + Tokens.padding.extraLarge * 2
        radius: Tokens.rounding.extraLarge
        color: Colours.tPalette.m3surfaceContainerLow
        border.width: 1
        border.color: Colours.tPalette.m3outlineVariant

        // Keeps clicks that land between the tiles from closing the overview
        MouseArea {
            anchors.fill: parent
        }

        Grid {
            anchors.centerIn: parent
            columns: root.columns
            rowSpacing: root.gap
            columnSpacing: root.gap

            Repeater {
                model: ScriptModel {
                    values: root.workspaceIds
                }

                WorkspaceCard {
                    required property int modelData

                    wsId: modelData
                    active: root.activeWsId === modelData
                    cardWidth: root.cardWidth
                    cardHeight: root.cardHeight
                    screenState: root.screenState
                }
            }
        }
    }

    StyledText {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: panel.bottom
        anchors.topMargin: Tokens.padding.large
        text: Tr.tr("Click a window to jump to it · Esc to close")
        color: Qt.alpha(Colours.palette.m3onSurfaceVariant, 0.8)
    }
}
