pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.filedialog
import qs.services
import qs.modules.dashboard as Dashboard

// A live, interactive miniature of the dashboard's home page - the real cards (weather, clock,
// profile, calendar, resources, media) rendered with Dash.qml, the exact same component the
// dashboard itself uses, scaled down to fit the settings page. Not a mock-up of what the page
// might look like: this *is* the page, so it updates live as cards are moved and removed.
//
// Grab any card and drag it into whichever row or column it should be in, or along a row to
// reorder it; a caret shows where it will land, and an empty place shows an outline to drop
// onto. The button on each card takes it off the page. Dash.qml and DashZone.qml draw those
// handles themselves whenever `editing` is set, which is why nothing here has to mirror the
// page's layout - it only has to say what a drag means.
//
// Based on the lock screen's own LockScreenPreview.qml, which does the read-only half of this.
Item {
    id: root

    // The live Config.dashboard.widgets list node itself (not a snapshot) - mutated directly,
    // the same way a ToggleRow writes straight to GlobalConfig
    required property var list
    // id -> display name / material icon, for the chip that follows the cursor while dragging
    required property var names
    required property var icons
    // The screen whose dashboard state the preview's cards read (the calendar's month, mostly)
    property var nState: null

    readonly property real framePadding: Tokens.padding.large

    // The cards read the real dashboard's per-screen state (the calendar's month, mostly), so
    // the preview shows the month that is actually open. Nothing renders until there is one -
    // the cards assume a screen, and a null one leaves the calendar reading a date off nothing
    readonly property var previewState: {
        const screen = root.nState?.screen;
        return (screen ? ShellState.forScreen(screen) : null) ?? ShellState.forActive();
    }

    readonly property Item dash: dashLoader.item as Item

    // How far the real page has to shrink to fit the settings page's column
    readonly property real factor: Math.min(1, (root.width - root.framePadding * 2) / Math.max(1, root.dash?.implicitWidth ?? 1))

    // The card being dragged and where it would land: both read straight back out by the zones,
    // which draw the caret and dim the card themselves
    property string draggingId
    property string dropZone
    property int dropIndex: -1
    property point ghostPos

    function realIndexOf(id: string): int {
        return root.list.values.findIndex(e => e.id === id);
    }

    function entriesFor(zone: string): var {
        return root.list.values.filter(e => e.enabled && e.zone === zone);
    }

    // Which place a drag at `pt` (this item's coordinates) is over, and how far along it. Falls
    // back to the nearest place, so a drag that strays into a gap still means something
    function targetAt(pt: point): var {
        let nearest = null;
        let nearestDist = Infinity;

        for (const zone of root.dash?.zones ?? []) {
            if (!zone.visible)
                continue;

            const local = zone.mapFromItem(root, pt.x, pt.y);
            const inside = local.x >= 0 && local.x <= zone.width && local.y >= 0 && local.y <= zone.height;
            const dx = Math.max(0, -local.x, local.x - zone.width);
            const dy = Math.max(0, -local.y, local.y - zone.height);
            const dist = inside ? -1 : Math.sqrt(dx * dx + dy * dy);

            if (dist < nearestDist) {
                nearestDist = dist;
                nearest = {
                    zone: zone.zoneId,
                    index: zone.insertIndexAt(local)
                };
            }
            if (inside)
                break;
        }
        return nearest;
    }

    function beginDrag(id: string, item: Item, x: real, y: real): void {
        root.draggingId = id;
        root.moveDrag(item, x, y);
    }

    function moveDrag(item: Item, x: real, y: real): void {
        if (!root.draggingId)
            return;

        const pt = root.mapFromItem(item, x, y);
        root.ghostPos = pt;

        const target = root.targetAt(pt);
        root.dropZone = target ? target.zone : "";
        root.dropIndex = target ? target.index : -1;
    }

    function endDrag(): void {
        const id = root.draggingId;
        const zone = root.dropZone;
        const index = root.dropIndex;
        root.cancelDrag();

        if (id && zone && index >= 0)
            root.commitDrop(id, zone, index);
    }

    function cancelDrag(): void {
        root.draggingId = "";
        root.dropZone = "";
        root.dropIndex = -1;
    }

    function removeCard(id: string): void {
        const index = root.realIndexOf(id);
        if (index >= 0)
            root.list.remove(index);
    }

    // Moves `id` into `zone` at `index`, counted among the cards already there. The config is
    // one flat list covering all four places, so an index within a place has to be turned back
    // into an index in that
    function commitDrop(id: string, zone: string, index: int): void {
        const from = root.realIndexOf(id);
        if (from < 0)
            return;

        const entry = root.list.at(from);
        const sameZone = entry.zone === zone;
        // In its own place the card is still counted by the caret it is being dragged past, so
        // dropping after itself has to lose that one place
        const current = sameZone ? root.entriesFor(zone).findIndex(e => e.id === id) : -1;

        if (!sameZone)
            entry.zone = zone;

        const others = root.entriesFor(zone).filter(e => e.id !== id);
        let idx = sameZone && index > current ? index - 1 : index;
        idx = Math.max(0, Math.min(idx, others.length));

        let to = from;
        if (others.length > 0) {
            if (idx >= others.length) {
                const last = root.realIndexOf(others[others.length - 1].id);
                to = from < last ? last : last + 1;
            } else {
                const before = root.realIndexOf(others[idx].id);
                to = from < before ? before - 1 : before;
            }
        }

        if (to !== from)
            root.list.move(from, to);
    }

    implicitHeight: (root.dash?.implicitHeight ?? 0) * root.factor + root.framePadding * 2

    StyledRect {
        anchors.fill: parent

        radius: Tokens.rounding.extraLarge
        color: Colours.palette.m3shadow
        border.width: 1
        border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.4)
        clip: true

        Loader {
            id: dashLoader

            x: root.framePadding
            y: root.framePadding
            width: dashLoader.implicitWidth
            height: dashLoader.implicitHeight
            scale: root.factor
            transformOrigin: Item.TopLeft

            active: !!root.previewState
            sourceComponent: dashComp
        }
    }

    Component {
        id: dashComp

        Dashboard.Dash {
            editing: true
            editController: root
            editScale: root.factor
            screenState: root.previewState
            facePicker: picker
        }
    }

    // The real page's profile card opens this when its picture is clicked. Nothing in the
    // preview is clickable - every card is covered by its own grab handle - but Dash needs one
    FileDialog {
        id: picker

        title: Tr.tr("Select a profile picture")
    }

    // Follows the cursor while dragging, at full size rather than the preview's scale, so it
    // is always clear what is being moved
    StyledRect {
        id: ghost

        readonly property real margin: Tokens.padding.small

        visible: !!root.draggingId
        x: root.ghostPos.x - ghost.width / 2
        y: root.ghostPos.y - ghost.height / 2
        z: 100

        implicitWidth: ghostRow.implicitWidth + ghost.margin * 3
        implicitHeight: ghostRow.implicitHeight + ghost.margin * 2
        radius: Tokens.rounding.full
        color: Colours.palette.m3primaryContainer

        Row {
            id: ghostRow

            anchors.centerIn: parent
            spacing: Tokens.spacing.small

            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                text: root.icons[root.draggingId] ?? "widgets"
                color: Colours.palette.m3onPrimaryContainer
                fontStyle: Tokens.font.icon.small
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: root.names[root.draggingId] ?? root.draggingId
                color: Colours.palette.m3onPrimaryContainer
                font: Tokens.font.label.large
            }
        }
    }
}
