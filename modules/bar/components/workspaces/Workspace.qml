pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import M3Shapes
import Caelestia.Components
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.utils

Item {
    id: root

    required property int modelData
    required property int index
    required property int activeWsId
    required property int ws
    required property HyprlandMonitor monitor
    required property ShellScreen screen

    required property int displayType
    required property bool showWindows
    required property var iconRules
    property string activeLabel
    property string occupiedLabel
    property string label

    readonly property list<HyprlandToplevel> toplevels: Hypr.toplevelsForWs(ws, GlobalConfig.bar.workspaces.ignoredTags)
    readonly property bool isOccupied: toplevels.length > 0
    readonly property bool hasWindows: isOccupied && showWindows && Config.bar.workspaces.maxWindowIcons > 0
    // Off by default: the window icons stay decorative unless the actions are turned on
    readonly property bool windowActions: Config.bar.workspaces.windowActions
    // Set while the pointer is over one of this workspace's window icons. The bar's own click area
    // checks it so a press there reaches the icon instead of switching to the workspace
    property bool windowIconHovered
    readonly property bool focused: activeWsId === ws
    readonly property list<int> focusedShapeList: [MaterialShape.Slanted, MaterialShape.Oval, MaterialShape.Pill, MaterialShape.Triangle, MaterialShape.Arrow, MaterialShape.Diamond, MaterialShape.Pentagon, MaterialShape.Gem, MaterialShape.VerySunny, MaterialShape.Sunny, MaterialShape.Cookie4Sided, MaterialShape.Cookie6Sided, MaterialShape.Cookie7Sided, MaterialShape.Cookie9Sided, MaterialShape.Cookie12Sided, MaterialShape.Clover4Leaf, MaterialShape.SoftBurst, MaterialShape.Ghostish]

    property color offMonitorColour: Colours.palette.m3outlineVariant
    readonly property bool onOtherMonitor: {
        if (Config.bar.workspaces.perMonitor)
            return false;
        const mon = Hypr.workspaces.values.find(w => w.id === ws)?.monitor;
        return !!(mon && mon !== monitor);
    }
    readonly property color fgColour: {
        if (onOtherMonitor)
            return offMonitorColour;
        if (focused || isOccupied || Config.bar.workspaces.occupiedBg)
            return Colours.palette.m3onSurface;
        return Colours.layer(Colours.palette.m3outlineVariant, 2);
    }

    function updateShape(): void {
        const shape = indicator.item as MaterialShape;
        if (!shape)
            return;

        if (focused)
            shape.shape = focusedShapeList[Math.floor(Math.random() * focusedShapeList.length)];
        else
            shape.shape = Qt.binding(() => isOccupied ? MaterialShape.Square : MaterialShape.Circle);
    }

    anchors.horizontalCenter: parent?.horizontalCenter
    LazyListView.preferredHeight: LazyListView.removing ? 0 : layout.implicitHeight + (hasWindows ? Tokens.padding.extraSmall : 0)
    LazyListView.visibleHeight: LazyListView.preferredHeight

    opacity: LazyListView.removing || LazyListView.adding ? 0 : 1

    onFocusedChanged: updateShape()
    Component.onCompleted: updateShape()

    Behavior on LazyListView.visibleHeight {
        Anim {}
    }

    Behavior on y {
        enabled: root.LazyListView.ready

        Anim {}
    }

    Behavior on opacity {
        Anim {
            type: Anim.DefaultEffects
        }
    }

    Component {
        id: shapeComponent

        MaterialShape {
            implicitSize: Tokens.sizes.bar.innerWidth - Tokens.padding.small

            color: root.fgColour
            scale: root.focused ? 2 / 3 : root.isOccupied ? 1 / 3 : 1 / 4

            animationEasing: Tokens.anim.expressiveDefaultSpatial
            animationDuration: Tokens.anim.durations.expressiveDefaultSpatial * Tokens.anim.durations.scale

            Behavior on color {
                CAnim {}
            }

            Behavior on scale {
                Anim {}
            }
        }
    }

    Component {
        id: textComponent

        StyledText {
            animate: true
            text: {
                if (root.focused) {
                    const label = root.activeLabel;
                    if (label)
                        return label;
                }

                if (root.focused || root.isOccupied) {
                    const label = root.occupiedLabel;
                    if (label)
                        return label;
                }

                const label = root.label;
                if (label)
                    return label;

                const ws = Hypr.workspaces.values.find(w => w.id === root.ws);
                const wsName = !ws || ws.name == root.ws ? root.ws : Hypr.trimWsName(ws.name)[0];

                const capitalisation = Config.bar.workspaces.capitalisation;
                if (capitalisation === BarWorkspaceCapitalisation.Upper)
                    return String(wsName).toUpperCase();
                else if (capitalisation === BarWorkspaceCapitalisation.Lower)
                    return String(wsName).toLowerCase();
                return wsName;
            }
            color: root.fgColour
            verticalAlignment: Qt.AlignVCenter
            font.family: Tokens.font.workspaces
        }
    }

    Component {
        id: iconComponent

        MaterialIcon {
            fill: 1
            grade: 25
            text: iconCacher.icon
            color: root.fgColour
            verticalAlignment: Qt.AlignVCenter

            WsIconCacher {
                id: iconCacher
            }
        }
    }

    Component {
        id: iconLoaderComponent

        Loader {
            sourceComponent: loaderIconCacher.icon ? iconComponent : textComponent

            WsIconCacher {
                id: loaderIconCacher
            }
        }
    }

    ColumnLayout {
        id: layout

        anchors.fill: parent
        spacing: 0

        Loader {
            id: indicator

            Layout.alignment: Qt.AlignHCenter | Qt.AlignTop
            Layout.preferredHeight: Tokens.sizes.bar.innerWidth - Tokens.padding.small
            sourceComponent: {
                if (root.displayType === BarWorkspaceDisplay.Icons)
                    return iconLoaderComponent;
                if (root.displayType === BarWorkspaceDisplay.Text)
                    return textComponent;
                return shapeComponent;
            }

            onItemChanged: root.updateShape()
        }

        Loader {
            id: windows

            asynchronous: true

            Layout.fillWidth: true
            Layout.topMargin: -Tokens.spacing.extraSmall / 2
            Layout.preferredHeight: root.hasWindows && item ? (item as LazyListView).layoutHeight : 0

            visible: active
            active: root.showWindows && Config.bar.workspaces.maxWindowIcons > 0

            sourceComponent: LazyListView {
                spacing: 0
                implicitHeight: contentHeight
                cullDelegates: false
                removeDuration: Tokens.anim.durations.expressiveDefaultEffects

                model: ScriptModel {
                    values: {
                        const windows = root.toplevels;
                        const maxIcons = root.Config.bar.workspaces.maxWindowIcons;
                        return maxIcons > 0 ? windows.slice(0, maxIcons) : windows;
                    }
                }

                delegate: MaterialIcon {
                    id: win

                    required property var modelData
                    required property int index // Needed, LazyListView will fail to set it if it doesn't exist

                    readonly property bool hovered: iconMouse.containsMouse

                    function focusWindow(): void {
                        const address = String(modelData.address || "").replace(/^0x/, "");
                        if (!address)
                            return;

                        // A minimised window sits on special:minimized, where it can be neither seen
                        // nor focused, so bring it back to the active workspace first
                        if (String(modelData.lastIpcObject.workspace?.name || "") === "special:minimized") {
                            const activeWorkspaceId = Number(Hypr.focusedMonitor?.lastIpcObject.activeWorkspace?.id ?? 0);
                            const workspace = Hypr.workspaces.values.find(w => w.id === activeWorkspaceId && w.id > 0)
                                ?? Hypr.workspaces.values.find(w => w.id > 0 && w.monitor === Hypr.focusedMonitor?.name)
                                ?? Hypr.workspaces.values.find(w => w.id > 0);
                            const target = workspace?.id ?? 1;
                            const window = `address:0x${address}`;
                            Hypr.dispatch(Hypr.usingLua
                                ? `hl.dsp.window.move({workspace=${target},follow=true,window="${window}"})`
                                : `movetoworkspace ${target},${window}`);
                            Qt.callLater(() => Hypr.focusWindow(address));
                        } else {
                            Hypr.focusWindow(address);
                        }
                    }

                    function minimizeWindow(): void {
                        const address = String(modelData.address || "").replace(/^0x/, "");
                        if (!address)
                            return;
                        const target = `address:0x${address}`;
                        Hypr.dispatch(Hypr.usingLua
                            ? `hl.dsp.window.move({workspace="special:minimized",follow=false,window="${target}"})`
                            : `movetoworkspacesilent special:minimized,${target}`);
                    }

                    function closeWindow(): void {
                        const address = String(modelData.address || "").replace(/^0x/, "");
                        if (!address)
                            return;
                        const target = `address:0x${address}`;
                        Hypr.dispatch(Hypr.usingLua
                            ? `hl.dsp.window.close({window="${target}"})`
                            : `closewindow ${target}`);
                    }

                    function showWindowPreview(): void {
                        const components = ShellState.componentsFor(root.screen);
                        const popouts = components?.panels?.popouts;
                        const bar = components?.bar;
                        if (!popouts || !bar)
                            return;

                        const center = mapToItem(bar, width / 2, height / 2);
                        popouts.windowPreviewClient = modelData;
                        popouts.windowPreviewTrigger = win;
                        popouts.currentName = "windowpreview";
                        popouts.currentCenter = bar.vertical ? center.y : center.x;
                        popouts.hasCurrent = true;
                    }

                    function hideWindowPreview(): void {
                        const popouts = ShellState.componentsFor(root.screen)?.panels?.popouts;
                        if (popouts?.currentName === "windowpreview")
                            popouts.hasCurrent = false;
                    }

                    grade: 0
                    horizontalAlignment: Text.AlignHCenter
                    text: Icons.getAppCategoryIcon(modelData.lastIpcObject.class, "terminal")
                    color: win.hovered ? Colours.palette.m3primary : root.onOtherMonitor ? root.offMonitorColour : Colours.palette.m3onSurfaceVariant

                    opacity: LazyListView.adding || LazyListView.removing ? 0 : 1

                    onHoveredChanged: root.windowIconHovered = hovered

                    Behavior on color {
                        CAnim {}
                    }

                    Behavior on opacity {
                        Anim {
                            type: Anim.DefaultEffects
                        }
                    }

                    Behavior on y {
                        Anim {}
                    }

                    MouseArea {
                        id: iconMouse

                        anchors.fill: parent
                        enabled: root.windowActions
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onEntered: win.showWindowPreview()

                        onClicked: event => {
                            if (event.button === Qt.RightButton) {
                                win.hideWindowPreview();
                                contextMenu.expanded = true;
                            } else {
                                win.focusWindow();
                            }
                        }

                        Menu {
                            id: contextMenu

                            attachTo: win
                            compact: true
                            attachSideX: ShellState.componentsFor(root.screen)?.bar?.onRight ? Menu.Left : Menu.Right
                            thisSideX: ShellState.componentsFor(root.screen)?.bar?.onRight ? Menu.Right : Menu.Left
                            attachSideY: Menu.Bottom
                            thisSideY: Menu.Top
                            items: [minimizeItem, closeItem]

                            MenuItem {
                                id: minimizeItem

                                text: Tr.tr("Minimize")
                                icon: "minimize"
                                onClicked: win.minimizeWindow()
                            }

                            MenuItem {
                                id: closeItem

                                text: Tr.tr("Close")
                                icon: "close"
                                onClicked: win.closeWindow()
                            }
                        }

                        // Clicks on the bar land on the menu's own overlay, but the bar only takes input
                        // over itself, so a click anywhere else would otherwise leave the menu open
                        HyprlandFocusGrab {
                            active: contextMenu.expanded
                            windows: [QsWindow.window]
                            onCleared: contextMenu.expanded = false
                        }
                    }
                }
            }
        }
    }

    component WsIconCacher: QtObject {
        id: cacher

        property string name
        readonly property string icon: Icons.matchIconRuleList(Hypr.trimWsName(name), root.iconRules)
        readonly property HyprlandWorkspace wsObj: Hypr.workspaces.values.find(w => w.id === root.ws) ?? null

        readonly property Connections conn: Connections {
            function onNameChanged(): void {
                cacher.updateName();
            }

            target: cacher.wsObj
        }

        function updateName(): void {
            if (wsObj)
                name = wsObj.name;
        }

        onWsObjChanged: updateName()
        Component.onCompleted: updateName()
    }
}
