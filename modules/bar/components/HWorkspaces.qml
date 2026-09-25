pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Caelestia.Config
import qs.components
import qs.services
import qs.utils

// Horizontal workspace strip used by top/bottom bars. Mirrors the vertical one: an indicator per
// workspace (shape, text or icon), the windows on it, an active pill and optional occupied backgrounds.
StyledRect {
    id: root

    required property ShellScreen screen
    required property bool fullscreen

    readonly property HyprlandMonitor monitor: Hypr.monitorFor(screen)
    readonly property int activeWsId: monitor?.activeWorkspace?.id ?? 1
    readonly property int shown: Math.max(1, Config.bar.workspaces.shown)
    readonly property int displayType: Config.bar.workspaces.displayType
    readonly property bool showWindows: Config.bar.workspaces.showWindows && Config.bar.workspaces.maxWindowIcons > 0

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

    implicitWidth: row.implicitWidth + Tokens.padding.extraSmall * 2
    implicitHeight: Tokens.sizes.bar.innerWidth

    color: Colours.tPalette.m3surfaceContainer
    radius: Tokens.rounding.full
    visible: !fullscreen

    RowLayout {
        id: row

        anchors.centerIn: parent
        spacing: Tokens.spacing.extraSmall

        Repeater {
            model: ScriptModel {
                values: root.wsIds
            }

            Item {
                id: cell

                required property int modelData

                readonly property int ws: modelData
                readonly property list<HyprlandToplevel> toplevels: Hypr.toplevelsForWs(ws, GlobalConfig.bar.workspaces.ignoredTags)
                readonly property bool occupied: toplevels.length > 0
                readonly property bool focused: ws === root.activeWsId
                readonly property bool hasWindows: occupied && root.showWindows
                readonly property bool onOtherMonitor: {
                    if (Config.bar.workspaces.perMonitor)
                        return false;
                    const mon = Hypr.workspaces.values.find(w => w.id === ws)?.monitor;
                    return !!(mon && mon !== root.monitor);
                }
                readonly property bool pilled: focused && Config.bar.workspaces.activeIndicator
                readonly property color fgColour: {
                    if (pilled)
                        return Colours.palette.m3onPrimary;
                    if (onOtherMonitor)
                        return Colours.palette.m3outlineVariant;
                    if (focused || occupied || Config.bar.workspaces.occupiedBg)
                        return Colours.palette.m3onSurface;
                    return Colours.layer(Colours.palette.m3outlineVariant, 2);
                }
                readonly property string wsName: Hypr.workspaces.values.find(w => w.id === ws)?.name ?? String(ws)

                Layout.alignment: Qt.AlignVCenter
                implicitWidth: content.implicitWidth + Tokens.padding.small * 2
                implicitHeight: root.implicitHeight - Tokens.padding.small

                StyledRect {
                    anchors.fill: parent
                    radius: Tokens.rounding.full
                    color: cell.pilled ? Colours.palette.m3primary : Config.bar.workspaces.occupiedBg && cell.occupied ? Colours.layer(Colours.palette.m3surfaceContainerHighest, 2) : "transparent"
                }

                RowLayout {
                    id: content

                    anchors.centerIn: parent
                    spacing: Tokens.spacing.extraSmall

                    Loader {
                        Layout.alignment: Qt.AlignVCenter
                        sourceComponent: {
                            if (root.displayType === BarWorkspaceDisplay.Icons && cell.ruleIcon)
                                return iconIndicator;
                            if (root.displayType === BarWorkspaceDisplay.Shapes)
                                return shapeIndicator;
                            return textIndicator;
                        }
                    }

                    Repeater {
                        model: ScriptModel {
                            values: cell.hasWindows ? cell.toplevels.slice(0, Config.bar.workspaces.maxWindowIcons) : []
                        }

                        MaterialIcon {
                            required property var modelData

                            Layout.alignment: Qt.AlignVCenter
                            grade: 0
                            text: Icons.getAppCategoryIcon(modelData.lastIpcObject.class, "terminal")
                            color: cell.pilled ? Colours.palette.m3onPrimary : cell.onOtherMonitor ? Colours.palette.m3outlineVariant : Colours.palette.m3onSurfaceVariant
                            fontStyle: Tokens.font.icon.small
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (Hypr.activeWsId !== cell.ws)
                            Hypr.focusWorkspace(cell.ws);
                        else if (Config.bar.workspaces.specialWorkspaces)
                            Hypr.toggleSpecial("special");
                    }
                }

                readonly property string ruleIcon: Icons.matchIconRuleList(Hypr.trimWsName(wsName), GlobalConfig.bar.workspaces.workspaceIcons)

                Component {
                    id: shapeIndicator

                    StyledRect {
                        implicitWidth: cell.focused ? 12 : cell.occupied ? 10 : 8
                        implicitHeight: implicitWidth
                        radius: cell.occupied ? Tokens.rounding.extraSmall : Tokens.rounding.full
                        color: cell.fgColour

                        Behavior on implicitWidth {
                            Anim {}
                        }
                    }
                }

                Component {
                    id: textIndicator

                    StyledText {
                        animate: true
                        text: {
                            if (cell.focused && Config.bar.workspaces.activeLabel)
                                return Config.bar.workspaces.activeLabel;
                            if ((cell.focused || cell.occupied) && Config.bar.workspaces.occupiedLabel)
                                return Config.bar.workspaces.occupiedLabel;
                            if (Config.bar.workspaces.label)
                                return Config.bar.workspaces.label;

                            const name = cell.wsName == cell.ws ? cell.ws : Hypr.trimWsName(cell.wsName)[0];
                            const capitalisation = Config.bar.workspaces.capitalisation;
                            if (capitalisation === BarWorkspaceCapitalisation.Upper)
                                return String(name).toUpperCase();
                            if (capitalisation === BarWorkspaceCapitalisation.Lower)
                                return String(name).toLowerCase();
                            return name;
                        }
                        color: cell.fgColour
                        font: Tokens.font.label.medium
                    }
                }

                Component {
                    id: iconIndicator

                    MaterialIcon {
                        fill: 1
                        grade: 25
                        text: cell.ruleIcon
                        color: cell.fgColour
                    }
                }

                Behavior on implicitWidth {
                    Anim {}
                }
            }
        }
    }
}
