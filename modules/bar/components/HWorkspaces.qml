pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Caelestia.Config
import qs.components
import qs.services

// Horizontal workspace strip used by top/bottom bars
StyledRect {
    id: root

    required property ShellScreen screen
    required property bool fullscreen

    readonly property HyprlandMonitor monitor: Hypr.monitorFor(screen)
    readonly property int activeWsId: monitor?.activeWorkspace?.id ?? 1
    readonly property int shown: Math.max(1, Config.bar.workspaces.shown)
    readonly property bool showNumbers: Config.bar.workspaces.displayType === BarWorkspaceDisplay.Text

    readonly property var wsIds: {
        if (Config.bar.workspaces.showUnoccupied) {
            const offset = Math.floor((activeWsId - 1) / shown) * shown;
            return Array.from({
                length: shown
            }, (_, i) => offset + i + 1);
        }

        const allMonitors = !Config.bar.workspaces.perMonitor;
        const ignoredTags = GlobalConfig.bar.workspaces.ignoredTags;
        const workspaces = Hypr.workspaces.values.filter(w => w.id > 0 && (allMonitors || w.monitor === root.monitor) && (w.id === activeWsId || w.toplevels.values.some(t => !Hypr.isToplevelIgnored(t, ignoredTags))));
        const currentIdx = workspaces.findIndex(w => w.id === activeWsId);
        if (currentIdx < 0)
            return [];

        const end = Math.max(Math.min(shown, workspaces.length), Math.min(currentIdx + 1, workspaces.length));
        const start = Math.max(0, end - shown);
        return workspaces.slice(start, end).map(w => w.id);
    }

    implicitWidth: row.implicitWidth + Tokens.padding.medium * 2
    implicitHeight: Tokens.sizes.bar.innerWidth

    color: Colours.tPalette.m3surfaceContainer
    radius: Tokens.rounding.full
    visible: !fullscreen

    RowLayout {
        id: row

        anchors.centerIn: parent
        spacing: Tokens.spacing.small

        Repeater {
            model: ScriptModel {
                values: root.wsIds
            }

            Item {
                id: cell

                required property int modelData

                readonly property bool focused: modelData === root.activeWsId
                readonly property bool occupied: Hypr.toplevelsForWs(modelData, GlobalConfig.bar.workspaces.ignoredTags).length > 0
                readonly property real dot: 10

                Layout.alignment: Qt.AlignVCenter
                implicitWidth: root.showNumbers ? 24 : focused ? dot * 2.6 : dot
                implicitHeight: root.showNumbers ? 24 : dot

                StyledRect {
                    anchors.fill: parent
                    radius: Tokens.rounding.full
                    color: cell.focused ? Colours.palette.m3primary : root.showNumbers ? "transparent" : cell.occupied ? Colours.palette.m3onSurface : Colours.layer(Colours.palette.m3outlineVariant, 2)
                }

                StyledText {
                    visible: root.showNumbers
                    anchors.centerIn: parent
                    text: cell.modelData
                    color: cell.focused ? Colours.palette.m3onPrimary : cell.occupied ? Colours.palette.m3onSurface : Colours.palette.m3outline
                    font: Tokens.font.label.medium
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -Tokens.spacing.extraSmall
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (Hypr.activeWsId !== cell.modelData)
                            Hypr.focusWorkspace(cell.modelData);
                    }
                }

                Behavior on implicitWidth {
                    Anim {}
                }
            }
        }
    }
}
