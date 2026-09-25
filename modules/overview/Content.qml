pragma ComponentBehavior: Bound

import "geometry.js" as Geometry
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.utils

Item {
    id: root

    required property ShellScreen screen
    required property ScreenState screenState
    required property real reveal
    // 0 with the grid off the bottom of the screen, 1 once it has been pulled up into place
    required property real lift

    readonly property bool blurred: !!Hypr.options["decoration:blur:enabled"]
    readonly property var monitor: Hypr.monitorFor(screen)
    readonly property int activeWsId: monitor?.activeWorkspace?.id ?? 1

    // Ten tiles to a page, in a 2x5 grid
    readonly property int columns: 5
    readonly property int rows: 2
    readonly property int perPage: columns * rows

    // Workspaces that have a window on them, on any monitor
    readonly property var occupiedIds: {
        const ids = new Set();
        for (const t of Hypr.toplevels.values) {
            const id = t.workspace?.id ?? -1;
            if (id > 0 && !Hypr.isToplevelIgnored(t, GlobalConfig.bar.workspaces.ignoredTags))
                ids.add(id);
        }
        return [...ids].sort((a, b) => a - b);
    }

    // Every workspace the overview can show, in order, split into pages of ten. By default
    // that is every workspace in groups of ten (matching the keybinds), out to the last group
    // that has a window or is focused plus one empty group so a fresh one can be reached.
    // With "only in use" it is just the workspaces with windows, the focused one and the
    // first free number, so none of the empty ones in between.
    readonly property var workspaceIds: {
        const per = root.perPage;
        if (GlobalConfig.overview.onlyInUse) {
            const ids = new Set(root.occupiedIds);
            if (root.activeWsId > 0)
                ids.add(root.activeWsId);
            let free = 1;
            while (ids.has(free))
                free++;
            ids.add(free);
            return [...ids].sort((a, b) => a - b);
        }

        const highest = Math.max(1, root.activeWsId, ...root.occupiedIds);
        const groups = Math.floor((highest - 1) / per) + 2;
        return Array.from({
            length: groups * per
        }, (_, i) => i + 1);
    }
    readonly property int pageCount: Math.max(1, Math.ceil(root.workspaceIds.length / root.perPage))
    property int page: 0
    // 1 / -1 as a new page slides in from the right / left, easing to 0 once it has arrived
    property real slide
    property int shownPage: 0
    // The workspace the keyboard has picked; the mouse moves it too
    property int selectedId: 1
    readonly property var pageIds: root.workspaceIds.slice(root.page * root.perPage, (root.page + 1) * root.perPage)

    // Tiles take the shape of this screen's usable area, so windows fill them instead of
    // being stretched into a shape the monitor doesn't have
    readonly property var usable: Geometry.usableRect(root.monitor?.lastIpcObject)
    readonly property real aspect: root.usable ? Math.max(1.3, Math.min(2.4, root.usable.width / root.usable.height)) : 16 / 9

    // Dragging a window between tiles. A press on a window is noted in `pending`; the drag
    // itself is tracked here rather than on the window, because turning the page (dragging out
    // to the side) destroys the tiles of the page it started on.
    property var pending: null
    property var dragClient: null
    // The workspace being dragged when it is a whole one, or -1
    property int dragWs: -1
    readonly property bool dragging: root.dragClient !== null || root.dragWs > 0
    // What the pointer carries is a workspace number instead of an app icon
    property bool ghostIsWorkspace
    property string ghostLabel
    // What the pointer carries: the app's icon, kept after the drop so it can shrink away
    property string ghostIcon
    property string ghostClass
    readonly property real ghostSize: 64
    property point dragPoint
    // The workspace a dropped window would land on, or -1
    property int dropWsId: -1
    // The window under the pointer in the workspace it came from: dropping there trades places
    property var swapClient: null
    // Which side of the panel the pointer is out past while dragging, so the page can be turned
    readonly property int dragEdge: !root.dragging || root.pageCount < 2 ? 0 : root.dragPoint.x < panel.x ? -1 : root.dragPoint.x > panel.x + panel.width ? 1 : 0

    readonly property int gap: Tokens.spacing.large
    // The grid only ever takes a fraction of the screen, so the tiles stay a modest
    // size and there is plenty of room left around them
    readonly property real gridMaxWidth: root.width * 0.8
    readonly property real gridMaxHeight: root.height * 0.7
    // Each tile is as large as the grid allows. The window is unmapped between openings,
    // so guard the size against a zero width.
    readonly property real cardWidth: Math.max(1, Math.floor(Math.min((root.gridMaxWidth - root.gap * (root.columns - 1)) / root.columns, ((root.gridMaxHeight - root.gap * (root.rows - 1)) / root.rows) * root.aspect)))
    readonly property real cardHeight: Math.round(root.cardWidth / root.aspect)
    readonly property real gridWidth: root.cardWidth * root.columns + root.gap * (root.columns - 1)
    readonly property real gridHeight: root.cardHeight * root.rows + root.gap * (root.rows - 1)

    function close(): void {
        root.screenState.overview = false;
    }

    // Selects the workspace at this position in the whole list (clamped to it) and turns to its page
    function select(index: int): void {
        const ids = root.workspaceIds;
        if (ids.length === 0)
            return;

        const i = Math.max(0, Math.min(ids.length - 1, index));
        root.selectedId = ids[i];
        root.page = Math.floor(i / root.perPage);
    }

    function selectedIndex(): int {
        return Math.max(0, root.workspaceIds.indexOf(root.selectedId));
    }

    // Moving off the edge of a page carries on into the next or previous one
    function moveSelection(dx: int, dy: int): void {
        root.select(root.selectedIndex() + dx + dy * root.columns);
    }

    // Changes page, keeping the same position on it where there is one
    function setPage(target: int): void {
        const page = Math.max(0, Math.min(root.pageCount - 1, target));
        root.select(page * root.perPage + root.selectedIndex() % root.perPage);
    }

    function resetSelection(): void {
        root.select(Math.max(0, root.workspaceIds.indexOf(root.activeWsId)));
    }

    function jumpTo(id: int): void {
        Hypr.focusWorkspace(id);
        root.close();
    }

    function beginDrag(sceneX: real, sceneY: real): void {
        const p = root.pending;
        if (!p)
            return;

        // Only if this press really was on that window, not a stale note from an earlier one
        const press = dragger.centroid.pressPosition;
        if (Math.abs(press.x - p.pressX) > 2 || Math.abs(press.y - p.pressY) > 2)
            return;

        root.ghostIsWorkspace = p.kind === "workspace";
        root.ghostLabel = p.label ?? "";
        root.ghostIcon = p.icon ?? "";
        root.ghostClass = p.windowClass ?? "";
        if (root.ghostIsWorkspace)
            root.dragWs = p.wsId;
        else
            root.dragClient = p.client;
        root.updateDrag(sceneX, sceneY);
    }

    function updateDrag(sceneX: real, sceneY: real): void {
        if (!root.dragging)
            return;

        root.dragPoint = root.mapFromItem(null, sceneX, sceneY);

        let target = -1;
        let swap = null;
        for (let i = 0; i < tiles.count; ++i) {
            const tile = tiles.itemAt(i);
            if (tile && tile.contains(tile.mapFromItem(root, root.dragPoint.x, root.dragPoint.y))) {
                target = tile.wsId;
                // Over another window of its own workspace, a drop rearranges rather than moves
                if (!root.ghostIsWorkspace && target === root.pending?.wsId) {
                    const under = tile.windowAt(root, root.dragPoint.x, root.dragPoint.y);
                    if (under && under !== root.dragClient)
                        swap = under;
                }
                break;
            }
        }
        root.dropWsId = target;
        root.swapClient = swap;
    }

    // Hyprland says nothing when a layout changes under a swap, so the previews are asked to
    // catch up once the windows have settled
    function refreshSoon(): void {
        Hyprland.refreshToplevels();
        Hyprland.refreshWorkspaces();
        refreshTimer.restart();
    }

    // Trades the whole contents of two workspaces
    function swapWorkspaces(a: int, b: int): void {
        for (const t of Hypr.toplevels.values) {
            const id = t.workspace?.id ?? -1;
            if (id === a)
                Hypr.moveWindowToWorkspace(t.address, b);
            else if (id === b)
                Hypr.moveWindowToWorkspace(t.address, a);
        }
    }

    // Letting go over a different workspace sends the window there, over another window of its
    // own trades their places, a whole workspace over another trades their contents, and
    // anywhere else nothing happens
    function endDrag(): void {
        const p = root.pending;
        if (root.dragging && p) {
            if (root.ghostIsWorkspace) {
                if (root.dropWsId > 0 && root.dropWsId !== root.dragWs) {
                    root.swapWorkspaces(root.dragWs, root.dropWsId);
                    root.refreshSoon();
                }
            } else if (root.swapClient !== null) {
                Hypr.swapWindows(root.dragClient.address, root.swapClient.address);
                root.refreshSoon();
            } else if (root.dropWsId > 0 && root.dropWsId !== p.wsId) {
                Hypr.moveWindowToWorkspace(root.dragClient.address, root.dropWsId);
                root.refreshSoon();
            }
        }

        root.dragClient = null;
        root.dragWs = -1;
        root.dropWsId = -1;
        root.swapClient = null;
        root.pending = null;
    }

    // While it is up the previews are kept current, since a layout change (a swap, a resize
    // from elsewhere) sends no event of its own
    Timer {
        interval: 500
        repeat: true
        running: root.screenState.overview
        onTriggered: Hyprland.refreshToplevels()
    }

    Timer {
        id: refreshTimer

        interval: 350
        onTriggered: {
            Hyprland.refreshToplevels();
            Hyprland.refreshWorkspaces();
        }
    }

    focus: true

    Component.onCompleted: root.resetSelection()

    // The list changes as windows come and go; keep the selection on its workspace, or fall
    // back to the focused one if that workspace is no longer listed
    onWorkspaceIdsChanged: {
        const i = root.workspaceIds.indexOf(root.selectedId);
        if (i >= 0)
            root.select(i);
        else
            root.resetSelection();
    }

    // The tiles swap at once, so the new page slides in over the old one's place. Only while
    // the overview is up: it snaps to the focused workspace's page as it opens.
    onPageChanged: {
        if (root.screenState.overview && root.reveal > 0.5 && root.page !== root.shownPage) {
            root.slide = root.page > root.shownPage ? 1 : -1;
            slideAnim.restart();
        }
        root.shownPage = root.page;
    }

    Anim {
        id: slideAnim

        target: root
        property: "slide"
        to: 0
        type: Anim.DefaultSpatial
    }

    onRevealChanged: {
        if (root.reveal > 0)
            root.forceActiveFocus();
    }

    Connections {
        function onOverviewChanged(): void {
            root.dragClient = null;
            root.dragWs = -1;
            root.dropWsId = -1;
            root.swapClient = null;
            root.pending = null;
            if (root.screenState.overview) {
                root.resetSelection();
                root.forceActiveFocus();
            }
        }

        function onOverviewPageRequested(delta: int): void {
            root.setPage(root.page + delta);
        }

        target: root.screenState
    }

    Keys.onEscapePressed: root.close()
    Keys.onPressed: event => {
        event.accepted = true;

        switch (event.key) {
        case Qt.Key_Left:
            root.moveSelection(-1, 0);
            return;
        case Qt.Key_Right:
            root.moveSelection(1, 0);
            return;
        case Qt.Key_Up:
            root.moveSelection(0, -1);
            return;
        case Qt.Key_Down:
            root.moveSelection(0, 1);
            return;
        case Qt.Key_Home:
            root.select(root.page * root.perPage);
            return;
        case Qt.Key_End:
            root.select((root.page + 1) * root.perPage - 1);
            return;
        case Qt.Key_PageUp:
            root.setPage(root.page - 1);
            return;
        case Qt.Key_PageDown:
            root.setPage(root.page + 1);
            return;
        case Qt.Key_Return:
        case Qt.Key_Enter:
        case Qt.Key_Space:
            root.jumpTo(root.selectedId);
            return;
        }

        // 1-9 jump to that tile on this page, 0 is the tenth
        let position = -1;
        if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9)
            position = event.key - Qt.Key_0;
        else if (event.key === Qt.Key_0)
            position = 10;

        const id = position > 0 ? root.pageIds[position - 1] : undefined;
        if (id !== undefined)
            root.jumpTo(id);
        else
            event.accepted = false;
    }

    DragHandler {
        id: dragger

        target: null
        onActiveChanged: {
            if (active)
                root.beginDrag(centroid.scenePosition.x, centroid.scenePosition.y);
            else
                root.endDrag();
        }
        onCentroidChanged: root.updateDrag(centroid.scenePosition.x, centroid.scenePosition.y)
    }

    // One page per notch of the wheel, from anywhere over the overview; a touchpad sends many
    // small events for one swipe, so they are added up and paused between pages
    WheelHandler {
        property real travelled

        onWheel: event => {
            if (wheelPause.running)
                return;

            travelled += (event.angleDelta.y || event.angleDelta.x) || (event.pixelDelta.y || event.pixelDelta.x);
            if (Math.abs(travelled) >= 120) {
                root.setPage(root.page + (travelled < 0 ? 1 : -1));
                travelled = 0;
                wheelPause.restart();
            }
        }
    }

    Timer {
        id: wheelPause

        interval: 250
    }

    // Holding a dragged window out past the side of the panel turns the page
    Timer {
        interval: 700
        repeat: true
        running: root.dragEdge !== 0
        onTriggered: root.setPage(root.page + root.dragEdge)
    }

    StyledRect {
        anchors.fill: parent
        // A light tint when the compositor blurs what is behind it (see Overview.qml), and a
        // darker one where blur is switched off (battery saving, game mode) so it still stands out
        color: Qt.alpha(Colours.palette.m3scrim, root.blurred ? 0.18 : 0.55)
        opacity: root.reveal

        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }
    }

    // Everything but the scrim is pulled up from below the screen edge as it opens
    Item {
        id: stage

        width: parent.width
        height: parent.height
        y: (1 - root.lift) * root.height * 0.6
        opacity: root.reveal

        StyledRect {
            id: panel

            anchors.centerIn: parent
            implicitWidth: root.gridWidth + Tokens.padding.extraLarge * 2
            implicitHeight: content.implicitHeight + Tokens.padding.extraLarge * 2
            radius: Tokens.rounding.extraLarge
            color: Colours.tPalette.m3surfaceContainerLow
            border.width: 1
            border.color: Colours.tPalette.m3outlineVariant

            // Keeps clicks that land between the tiles from closing the overview
            MouseArea {
                anchors.fill: parent
            }

            Column {
                id: content

                anchors.centerIn: parent
                spacing: Tokens.spacing.large

                // Fixed to the size of a full page, so the panel doesn't change size on a short last page
                Item {
                    width: root.gridWidth
                    height: root.gridHeight
                    opacity: 1 - Math.abs(root.slide) * 0.8
                    transform: Translate {
                        x: root.slide * root.gridWidth * 0.12
                    }

                    Grid {
                        // Centred, so a short page (only in use, or the last one) isn't pushed into a corner
                        anchors.centerIn: parent
                        columns: root.columns
                        rowSpacing: root.gap
                        columnSpacing: root.gap

                        Repeater {
                            id: tiles

                            model: ScriptModel {
                                values: root.pageIds
                            }

                            WorkspaceCard {
                                id: tile

                                required property int modelData
                                required property int index

                                wsId: modelData
                                active: root.activeWsId === modelData
                                selected: root.selectedId === modelData
                                dropTarget: root.dragging && root.dropWsId === modelData && root.swapClient === null && root.pending?.wsId !== modelData
                                draggedClient: root.dragClient
                                lifted: root.dragWs === modelData
                                swapClient: root.swapClient
                                order: index
                                cardWidth: root.cardWidth
                                cardHeight: root.cardHeight
                                screenState: root.screenState
                                onPointerMoved: root.selectedId = modelData
                                onWindowGrabbed: (card, gx, gy) => {
                                    const at = card.mapToItem(root, gx, gy);
                                    root.pending = {
                                        kind: "window",
                                        client: card.client,
                                        wsId: modelData,
                                        icon: card.appIcon,
                                        windowClass: card.ipc?.class ?? "",
                                        pressX: at.x,
                                        pressY: at.y
                                    };
                                }
                                onTileGrabbed: (gx, gy) => {
                                    // Only a workspace with something on it is worth carrying
                                    if (!tile.occupied)
                                        return;
                                    const at = tile.mapToItem(root, gx, gy);
                                    root.pending = {
                                        kind: "workspace",
                                        wsId: modelData,
                                        label: tile.wsLabel,
                                        pressX: at.x,
                                        pressY: at.y
                                    };
                                }
                            }
                        }
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Tokens.spacing.small
                    visible: root.pageCount > 1

                    Repeater {
                        model: root.pageCount

                        StyledRect {
                            id: dot

                            required property int index
                            readonly property bool current: index === root.page

                            implicitWidth: dot.current ? Tokens.padding.large : Tokens.padding.small
                            implicitHeight: Tokens.padding.small
                            radius: Tokens.rounding.full
                            color: dot.current ? Colours.palette.m3primary : Colours.palette.m3outlineVariant

                            Behavior on implicitWidth {
                                Anim {
                                    type: Anim.FastSpatial
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -Tokens.padding.extraSmall
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.setPage(dot.index)
                            }
                        }
                    }
                }
            }
        }

        Repeater {
            model: root.pageCount > 1 ? [-1, 1] : []

            StyledRect {
                id: arrow

                required property int modelData
                readonly property bool available: root.page + modelData >= 0 && root.page + modelData < root.pageCount

                anchors.verticalCenter: panel.verticalCenter
                x: modelData < 0 ? panel.x - width - Tokens.padding.large : panel.x + panel.width + Tokens.padding.large
                implicitWidth: Tokens.padding.extraLarge * 3
                implicitHeight: implicitWidth
                radius: Tokens.rounding.full
                color: root.dragEdge === modelData ? Colours.palette.m3primary : Colours.tPalette.m3surfaceContainerLow
                border.width: 1
                border.color: Colours.tPalette.m3outlineVariant
                opacity: available ? 1 : 0.3

                MaterialIcon {
                    anchors.centerIn: parent
                    text: arrow.modelData < 0 ? "chevron_left" : "chevron_right"
                    color: root.dragEdge === arrow.modelData ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                    fontStyle: Tokens.font.icon.large
                }

                StateLayer {
                    disabled: !arrow.available
                    radius: arrow.radius
                    onClicked: root.setPage(root.page + arrow.modelData)
                }
            }
        }

        // On a pill so it stays readable over a bright, blurred backdrop
        StyledRect {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: panel.bottom
            anchors.topMargin: Tokens.padding.large
            implicitWidth: hint.implicitWidth + Tokens.padding.large * 2
            implicitHeight: hint.implicitHeight + Tokens.padding.small * 2
            radius: Tokens.rounding.full
            color: Colours.tPalette.m3surfaceContainerLow

            StyledText {
                id: hint

                anchors.centerIn: parent
                text: root.pageCount > 1 ? Tr.tr("Arrows to move · Enter to open · Drag a window, or a workspace by its number, to move or swap it · Page Up/Down for more · Esc to close") : Tr.tr("Arrows to move · Enter to open · Drag a window to move or swap it · Esc to close")
                color: Colours.palette.m3onSurfaceVariant
            }
        }
    }

    // The app being dragged, as its icon in a disc under the pointer. It pops in as the drag
    // starts and shrinks away when it ends.
    StyledRect {
        id: ghost

        readonly property bool shown: root.dragging

        x: root.dragPoint.x - width / 2
        y: root.dragPoint.y - height / 2
        width: root.ghostSize
        height: root.ghostSize
        radius: Tokens.rounding.full
        color: Colours.palette.m3secondaryContainer
        border.width: 2
        border.color: root.dropWsId > 0 || root.swapClient !== null ? Colours.palette.m3primary : Colours.palette.m3outline
        visible: opacity > 0
        opacity: ghost.shown ? 0.95 : 0
        scale: ghost.shown ? (root.dropWsId > 0 || root.swapClient !== null ? 1.1 : 1) : 0.5

        Behavior on opacity {
            Anim {
                type: Anim.FastEffects
            }
        }

        Behavior on scale {
            Anim {
                type: Anim.FastSpatial
            }
        }

        StyledText {
            anchors.centerIn: parent
            visible: root.ghostIsWorkspace
            text: root.ghostLabel
            color: Colours.palette.m3onSecondaryContainer
            font: Tokens.font.title.large
        }

        IconImage {
            anchors.centerIn: parent
            visible: !root.ghostIsWorkspace && root.ghostIcon !== ""
            asynchronous: true
            implicitSize: root.ghostSize * 0.65
            source: root.ghostIcon
        }

        MaterialIcon {
            anchors.centerIn: parent
            visible: !root.ghostIsWorkspace && root.ghostIcon === ""
            text: Icons.getAppCategoryIcon(root.ghostClass, "window")
            color: Colours.palette.m3onSecondaryContainer
            fontStyle: Tokens.font.icon.size(root.ghostSize * 0.5).build()
        }
    }
}
