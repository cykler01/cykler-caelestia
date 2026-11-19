pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import "../../../utils/toggleRows.js" as ToggleRows

// A drawing of the utilities panel (the control centre) that is edited by hand: drag a card up or down to move it,
// drag a quick toggle to another place in its grid, and drag the right edge of a toggle to make it wider. Cards and
// toggles that are hidden wait underneath, and a press brings them back.
//
// The cards are stand-ins, not the real ones (those talk to the recorder, KDE Connect and so on), but they take their
// sizes, colours and the toggle grid from the same places, and the grid is laid out by the same utils/toggleRows.js as
// the real card. The order, sizes and spans are written to the config when a drag lets go, not on every step of it.
Item {
    id: root

    // id -> display name
    required property var cardNames
    required property var toggleNames

    readonly property var toggleIcons: ({
            wifi: "wifi",
            bluetooth: "bluetooth",
            mic: "mic",
            timer: "timer",
            settings: "settings",
            gameMode: "gamepad",
            wallpaperPlaying: "smart_display",
            dnd: "notifications_off",
            vpn: "vpn_key"
        })
    readonly property var cardIcons: ({
            keepAwake: "coffee",
            recorder: "screen_record",
            phoneShare: "smartphone",
            quickToggles: "toggle_on",
            appVolumes: "tune"
        })
    // Toggles drawn as switched on, so the drawing shows both looks
    readonly property var drawnOn: ["wifi", "bluetooth"]
    // The sizes each card offers, in the order its size button steps through them
    readonly property var cardSizes: ({
            keepAwake: ["normal", "compact"],
            recorder: ["normal", "compact"],
            appVolumes: ["normal", "compact", "vertical"]
        })

    readonly property int columns: Math.max(1, Config.utilities.cards.toggleColumns)
    readonly property real framePad: Tokens.padding.large
    readonly property real innerPad: Tokens.padding.large
    readonly property real cardGap: Tokens.spacing.medium
    readonly property real rowGap: Tokens.spacing.small
    readonly property real rowHeight: 48
    readonly property real headerHeight: 24
    readonly property real panelWidth: Math.min(Tokens.sizes.utilities.width, width)
    readonly property real innerWidth: panelWidth - framePad * 2 - innerPad * 2

    // What the config says, flattened; the working copies below follow it except while something is being dragged
    readonly property var cardsCfg: Config.utilities.cards.order.values.map(c => ({
                id: c.id,
                size: c.size,
                enabled: Config.utilities.cards[c.id] ?? false
            }))
    readonly property var togglesCfg: Config.utilities.quickToggles.values.map(t => ({
                id: t.id,
                enabled: t.enabled,
                span: t.span
            }))

    property var cardWork: []
    property var toggleWork: []
    property bool busy
    property string draggingCard
    property string draggingToggle
    property string resizingToggle
    property string selectedToggle

    // Where everything goes, worked out in one go from the working copies: cards by id, toggles by id (inside the
    // toggles card), and how tall the whole panel comes to
    readonly property var layoutInfo: {
        const rows = ToggleRows.pack(toggleWork.filter(t => t.enabled), columns);
        const togglesHeight = innerPad * 2 + headerHeight + (rows.length > 0 ? rowGap + rows.length * rowHeight + (rows.length - 1) * rowGap : 0);

        const cards = {};
        let y = framePad;
        let shown = 0;
        for (const c of cardWork) {
            if (!c.enabled)
                continue;

            const h = cardHeight(c, togglesHeight);
            cards[c.id] = {
                y,
                h
            };
            y += h + cardGap;
            shown++;
        }

        const toggles = {};
        rows.forEach((row, r) => {
            const total = row.reduce((sum, t) => sum + ToggleRows.spanOf(t, columns), 0);
            const avail = innerWidth - (row.length - 1) * rowGap;
            let x = innerPad;
            for (const t of row) {
                const w = avail * ToggleRows.spanOf(t, columns) / total;
                toggles[t.id] = {
                    x,
                    y: innerPad + headerHeight + rowGap + r * (rowHeight + rowGap),
                    w
                };
                x += w + rowGap;
            }
        });

        return {
            cards,
            toggles,
            columnWidth: (innerWidth - (columns - 1) * rowGap) / columns,
            total: shown > 0 ? y - cardGap + framePad : framePad * 2 + 48
        };
    }

    readonly property var hiddenItems: [...cardWork.filter(c => !c.enabled).map(c => ({
                    kind: "card",
                    id: c.id
                })), ...toggleWork.filter(t => !t.enabled && root.toggleNames[t.id] !== undefined).map(t => ({
                    kind: "toggle",
                    id: t.id
                }))]

    function cardHeight(card: var, togglesHeight: real): real {
        const compact = card.size === "compact";
        switch (card.id) {
        case "keepAwake":
            return compact ? 56 : 68;
        case "recorder":
            return compact ? 68 : 152;
        case "quickToggles":
            return togglesHeight;
        case "appVolumes":
            if (card.size === "vertical")
                return root.innerPad * 2 + root.headerHeight + root.rowGap * 2 + 120;
            return compact ? root.innerPad * 2 + root.rowHeight : root.innerPad * 2 + root.headerHeight + root.rowGap * 2 + root.rowHeight * 2;
        }
        return 68;
    }

    function syncAll(): void {
        cardWork = cardsCfg;
        toggleWork = togglesCfg;
    }

    // Puts the entries of a config list in the order `ids` gives
    function applyOrder(list: var, ids: var): void {
        for (let i = 0; i < ids.length; i++) {
            for (let j = i; j < list.count; j++) {
                if (list.at(j).id === ids[i]) {
                    if (j !== i)
                        list.move(j, i);
                    break;
                }
            }
        }
    }

    function entryIndex(list: var, id: string): int {
        for (let i = 0; i < list.count; i++) {
            if (list.at(i).id === id)
                return i;
        }
        return -1;
    }

    function setCardOn(id: string, on: bool): void {
        GlobalConfig.utilities.cards[id] = on;
    }

    function setCardSize(id: string, size: string): void {
        const i = entryIndex(GlobalConfig.utilities.cards.order, id);
        if (i >= 0)
            GlobalConfig.utilities.cards.order.at(i).size = size;
    }

    function sizeLabel(size: string): string {
        switch (size) {
        case "compact":
            return Tr.trCtx("Compact", "card size");
        case "vertical":
            return Tr.trCtx("Vertical", "card size");
        }
        return Tr.trCtx("Normal", "card size");
    }

    // Steps a card through the sizes it offers, so the preview button reaches every one of them
    function cycleCardSize(id: string): void {
        const sizes = root.cardSizes[id] ?? ["normal", "compact"];
        const current = root.cardWork.find(c => c.id === id)?.size ?? "normal";
        root.setCardSize(id, sizes[(sizes.indexOf(current) + 1) % sizes.length]);
    }

    function setToggleOn(id: string, on: bool): void {
        const i = entryIndex(GlobalConfig.utilities.quickToggles, id);
        if (i >= 0)
            GlobalConfig.utilities.quickToggles.at(i).enabled = on;
        if (!on && selectedToggle === id)
            selectedToggle = "";
    }

    // A card has been carried over the others: where would it go if it were let go here
    function moveCard(id: string, centerY: real): void {
        const dragged = cardWork.find(c => c.id === id);
        if (!dragged)
            return;

        const others = cardWork.filter(c => c.enabled && c.id !== id);
        let y = framePad;
        let index = 0;
        for (const c of others) {
            const h = layoutInfo.cards[c.id]?.h ?? 0;
            if (y + h / 2 < centerY)
                index++;
            y += h + cardGap;
        }

        const order = others.slice();
        order.splice(index, 0, dragged);

        // Hidden cards keep their places in the list; the shown ones are dealt back into the rest in the new order
        let k = 0;
        const next = cardWork.map(c => c.enabled ? order[k++] : c);
        if (next.some((c, i) => c.id !== cardWork[i].id))
            cardWork = next;
    }

    function moveToggle(id: string, x: real, y: real): void {
        const enabled = toggleWork.filter(t => t.enabled);
        const hit = enabled.find(t => {
            const r = layoutInfo.toggles[t.id];
            return t.id !== id && r && x >= r.x && x <= r.x + r.w && y >= r.y && y <= r.y + rowHeight;
        });
        if (!hit)
            return;

        const dragged = enabled.find(t => t.id === id);
        const order = enabled.filter(t => t.id !== id);
        order.splice(enabled.indexOf(hit), 0, dragged);

        let k = 0;
        toggleWork = toggleWork.map(t => t.enabled ? order[k++] : t);
    }

    // The right edge of a toggle has been dragged to `rightX`: how many columns is that
    function resizeToggle(id: string, rightX: real): void {
        const rect = layoutInfo.toggles[id];
        if (!rect)
            return;

        const step = layoutInfo.columnWidth + rowGap;
        const span = Math.max(1, Math.min(columns, Math.round((rightX - rect.x + rowGap) / step)));
        if (toggleWork.find(t => t.id === id)?.span !== span)
            toggleWork = toggleWork.map(t => t.id === id ? Object.assign({}, t, {
                span
            }) : t);
    }

    function commitCards(): void {
        applyOrder(GlobalConfig.utilities.cards.order, cardWork.map(c => c.id));
    }

    function commitToggles(): void {
        const list = GlobalConfig.utilities.quickToggles;
        applyOrder(list, toggleWork.map(t => t.id));
        for (const t of toggleWork) {
            const i = entryIndex(list, t.id);
            if (i >= 0 && list.at(i).span !== t.span)
                list.at(i).span = t.span;
        }
    }

    // Lets go of whatever was being dragged: writes the result to the config, then follows the config again
    function finishDrag(): void {
        commitCards();
        commitToggles();
        draggingCard = "";
        draggingToggle = "";
        resizingToggle = "";
        busy = false;
        syncAll();
    }

    onCardsCfgChanged: {
        if (!busy)
            cardWork = cardsCfg;
    }
    onTogglesCfgChanged: {
        if (!busy)
            toggleWork = togglesCfg;
    }
    Component.onCompleted: syncAll()

    implicitHeight: hint.implicitHeight + Tokens.spacing.medium + frame.height + (tray.visible ? Tokens.spacing.medium + tray.implicitHeight : 0)

    StyledText {
        id: hint

        anchors.left: parent.left
        anchors.right: parent.right
        text: Tr.tr("Drag a card to move it. Drag a toggle to move it, or its right edge to make it wider. Hover a card to hide it or change its size.")
        color: Colours.palette.m3outline
        font: Tokens.font.label.small
        wrapMode: Text.WordWrap
    }

    StyledRect {
        id: frame

        anchors.top: hint.bottom
        anchors.topMargin: Tokens.spacing.medium
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.panelWidth
        height: root.layoutInfo.total

        radius: Tokens.rounding.extraLarge
        color: Colours.tPalette.m3surface

        Behavior on height {
            Anim {}
        }

        // Pressing the backdrop lets go of the selected toggle
        MouseArea {
            anchors.fill: parent
            onPressed: root.selectedToggle = ""
        }

        StyledText {
            anchors.centerIn: parent
            visible: Object.keys(root.layoutInfo.cards).length === 0
            text: Tr.tr("Every card is hidden")
            color: Colours.palette.m3outline
        }

        Repeater {
            model: ScriptModel {
                values: root.cardWork.filter(c => c.enabled)
                objectProp: "id"
            }

            CardView {}
        }
    }

    // What is hidden. A press puts it back
    Flow {
        id: tray

        anchors.top: frame.bottom
        anchors.topMargin: Tokens.spacing.medium
        anchors.left: parent.left
        anchors.right: parent.right
        visible: root.hiddenItems.length > 0
        spacing: Tokens.spacing.small

        StyledText {
            height: 32
            text: Tr.tr("Hidden")
            color: Colours.palette.m3outline
            font: Tokens.font.label.medium
            verticalAlignment: Text.AlignVCenter
        }

        Repeater {
            model: root.hiddenItems

            StyledRect {
                id: chip

                required property var modelData

                implicitWidth: chipRow.implicitWidth + Tokens.padding.large * 2
                implicitHeight: 32
                radius: Tokens.rounding.full
                color: Colours.tPalette.m3surfaceContainer

                Row {
                    id: chipRow

                    anchors.centerIn: parent
                    spacing: Tokens.spacing.small

                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: chip.modelData.kind === "card" ? root.cardIcons[chip.modelData.id] ?? "widgets" : root.toggleIcons[chip.modelData.id] ?? "toggle_on"
                        color: Colours.palette.m3onSurfaceVariant
                        fontStyle: Tokens.font.icon.small
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: (chip.modelData.kind === "card" ? root.cardNames[chip.modelData.id] : root.toggleNames[chip.modelData.id]) ?? chip.modelData.id
                        font: Tokens.font.label.medium
                    }

                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "add"
                        color: Colours.palette.m3primary
                        fontStyle: Tokens.font.icon.small
                    }
                }

                StateLayer {
                    onClicked: {
                        if (chip.modelData.kind === "card")
                            root.setCardOn(chip.modelData.id, true);
                        else
                            root.setToggleOn(chip.modelData.id, true);
                    }
                }
            }
        }
    }

    // One card of the drawing
    component CardView: StyledRect {
        id: card

        required property var modelData

        readonly property string cid: modelData.id
        readonly property var info: root.layoutInfo.cards[cid] ?? ({
                y: 0,
                h: 0
            })
        readonly property var work: root.cardWork.find(c => c.id === cid) ?? modelData
        readonly property bool compact: work.size === "compact"
        readonly property bool dragging: root.draggingCard === cid
        property real dragY

        x: root.framePad
        y: dragging ? dragY : info.y
        z: dragging ? 10 : 0
        width: frame.width - root.framePad * 2
        height: info.h
        scale: dragging ? 1.02 : 1
        radius: Tokens.rounding.large
        color: Colours.tPalette.m3surfaceContainer
        clip: true

        Behavior on y {
            enabled: !card.dragging

            Anim {}
        }

        Behavior on height {
            Anim {}
        }

        Behavior on scale {
            Anim {}
        }

        Loader {
            anchors.fill: parent
            sourceComponent: {
                switch (card.cid) {
                case "keepAwake":
                    return keepAwakeDrawing;
                case "recorder":
                    return recorderDrawing;
                case "phoneShare":
                    return phoneDrawing;
                case "quickToggles":
                    return togglesDrawing;
                case "appVolumes":
                    return appVolumesDrawing;
                }
                return null;
            }
        }

        // Where a press starts moving the card: all of it, except the toggles card, which only gives its title
        // because its toggles are dragged on their own
        MouseArea {
            id: cardMouse

            property point press

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: card.cid === "quickToggles" ? root.innerPad + root.headerHeight : parent.height
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

            onPressed: e => {
                root.selectedToggle = "";
                press = Qt.point(e.x, e.y);
            }
            onPositionChanged: e => {
                if (!pressed)
                    return;

                if (!card.dragging) {
                    if (Math.abs(e.y - press.y) < 6)
                        return;

                    card.dragY = card.info.y;
                    root.busy = true;
                    root.draggingCard = card.cid;
                }

                const p = mapToItem(frame, e.x, e.y);
                card.dragY = Math.max(0, Math.min(frame.height - card.height, p.y - press.y));
                root.moveCard(card.cid, card.dragY + card.height / 2);
            }
            onReleased: {
                if (card.dragging)
                    root.finishDrag();
            }
        }

        // Hide and resize, shown while the pointer is over the card
        HoverHandler {
            id: hover
        }

        Row {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: Tokens.padding.small
            spacing: Tokens.spacing.small
            opacity: hover.hovered && !card.dragging ? 1 : 0
            visible: opacity > 0

            Behavior on opacity {
                Anim {
                    type: Anim.StandardSmall
                }
            }

            StyledRect {
                visible: root.cardSizes[card.cid] !== undefined
                implicitWidth: sizeLabel.implicitWidth + Tokens.padding.large * 2
                implicitHeight: 28
                radius: Tokens.rounding.full
                color: Colours.palette.m3secondaryContainer

                StyledText {
                    id: sizeLabel

                    anchors.centerIn: parent
                    text: root.sizeLabel(card.work.size)
                    color: Colours.palette.m3onSecondaryContainer
                    font: Tokens.font.label.medium
                }

                StateLayer {
                    onClicked: root.cycleCardSize(card.cid)
                }
            }

            StyledRect {
                implicitWidth: 28
                implicitHeight: 28
                radius: Tokens.rounding.full
                color: Colours.palette.m3secondaryContainer

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "visibility_off"
                    color: Colours.palette.m3onSecondaryContainer
                    fontStyle: Tokens.font.icon.small
                }

                StateLayer {
                    onClicked: root.setCardOn(card.cid, false)
                }
            }
        }

        Component {
            id: keepAwakeDrawing

            Item {
                StyledRect {
                    id: icon

                    x: root.innerPad
                    anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: 40
                    implicitHeight: 40
                    radius: Tokens.rounding.full
                    color: Colours.palette.m3secondaryContainer

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: "coffee"
                        color: Colours.palette.m3onSecondaryContainer
                        fontStyle: Tokens.font.icon.large
                    }
                }

                Column {
                    anchors.left: icon.right
                    anchors.leftMargin: Tokens.spacing.medium
                    anchors.right: pill.left
                    anchors.rightMargin: Tokens.spacing.medium
                    anchors.verticalCenter: parent.verticalCenter

                    StyledText {
                        width: parent.width
                        text: root.cardNames.keepAwake
                        font: Tokens.font.body.medium
                        elide: Text.ElideRight
                    }

                    StyledText {
                        width: parent.width
                        visible: !card.compact
                        text: Tr.trCtx("Normal power management", "idle inhibitor")
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.body.small
                        elide: Text.ElideRight
                    }
                }

                StyledRect {
                    id: pill

                    anchors.right: parent.right
                    anchors.rightMargin: root.innerPad
                    anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: modes.implicitWidth + 6
                    implicitHeight: 34
                    radius: Tokens.rounding.full
                    color: Colours.tPalette.m3surfaceContainerHighest

                    Row {
                        id: modes

                        anchors.centerIn: parent

                        Repeater {
                            model: ["close", "coffee", "lock_clock"]

                            StyledRect {
                                required property string modelData
                                required property int index

                                implicitWidth: 34
                                implicitHeight: 28
                                radius: Tokens.rounding.full
                                color: index === 0 ? Colours.palette.m3primary : "transparent"

                                MaterialIcon {
                                    anchors.centerIn: parent
                                    text: parent.modelData
                                    color: parent.index === 0 ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                                    fontStyle: Tokens.font.icon.medium
                                }
                            }
                        }
                    }
                }
            }
        }

        Component {
            id: recorderDrawing

            Item {
                StyledRect {
                    id: icon

                    x: root.innerPad
                    y: 14
                    implicitWidth: 40
                    implicitHeight: 40
                    radius: Tokens.rounding.full
                    color: Colours.palette.m3secondaryContainer

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: "screen_record"
                        color: Colours.palette.m3onSecondaryContainer
                        fontStyle: Tokens.font.icon.large
                    }
                }

                Column {
                    anchors.left: icon.right
                    anchors.leftMargin: Tokens.spacing.medium
                    anchors.verticalCenter: icon.verticalCenter

                    StyledText {
                        text: root.cardNames.recorder
                        font: Tokens.font.body.medium
                    }

                    StyledText {
                        text: Tr.trCtx("Ready", "recorder state")
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.body.small
                    }
                }

                StyledRect {
                    anchors.right: parent.right
                    anchors.rightMargin: root.innerPad
                    anchors.verticalCenter: icon.verticalCenter
                    implicitWidth: 96
                    implicitHeight: 34
                    radius: Tokens.rounding.full
                    color: Colours.palette.m3secondaryContainer

                    StyledText {
                        anchors.centerIn: parent
                        text: Tr.trCtx("Region", "recording mode")
                        color: Colours.palette.m3onSecondaryContainer
                        font: Tokens.font.label.medium
                    }
                }

                // The list of recordings, which the compact size leaves out
                Column {
                    visible: !card.compact
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: icon.bottom
                    anchors.margins: root.innerPad
                    anchors.topMargin: Tokens.spacing.medium
                    spacing: Tokens.spacing.small

                    Repeater {
                        model: 2

                        StyledRect {
                            required property int index

                            width: parent.width
                            implicitHeight: 28
                            radius: Tokens.rounding.small
                            color: Colours.tPalette.m3surfaceContainerHigh

                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                x: Tokens.padding.medium
                                text: "recording_" + (index + 1) + ".mp4"
                                color: Colours.palette.m3onSurfaceVariant
                                font: Tokens.font.label.small
                            }
                        }
                    }
                }
            }
        }

        Component {
            id: phoneDrawing

            Item {
                StyledRect {
                    id: icon

                    x: root.innerPad
                    anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: 40
                    implicitHeight: 40
                    radius: Tokens.rounding.full
                    color: Colours.palette.m3secondaryContainer

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: "smartphone"
                        color: Colours.palette.m3onSecondaryContainer
                        fontStyle: Tokens.font.icon.large
                    }
                }

                Column {
                    anchors.left: icon.right
                    anchors.leftMargin: Tokens.spacing.medium
                    anchors.verticalCenter: parent.verticalCenter

                    StyledText {
                        text: root.cardNames.phoneShare
                        font: Tokens.font.body.medium
                    }

                    StyledText {
                        text: Tr.tr("Send files to your phone")
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.body.small
                    }
                }
            }
        }

        Component {
            id: appVolumesDrawing

            Item {
                StyledText {
                    x: root.innerPad
                    y: root.innerPad
                    height: root.headerHeight
                    verticalAlignment: Text.AlignVCenter
                    text: root.cardNames.appVolumes
                    font: Tokens.font.body.medium
                }

                MaterialIcon {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: root.innerPad
                    visible: card.compact
                    text: "unfold_more"
                    color: Colours.palette.m3onSurfaceVariant
                    fontStyle: Tokens.font.icon.medium
                }

                Row {
                    visible: card.work.size === "vertical"
                    x: root.innerPad
                    y: root.innerPad + root.headerHeight + root.rowGap
                    width: parent.width - root.innerPad * 2
                    height: 120
                    spacing: root.rowGap

                    Repeater {
                        model: 4

                        Item {
                            required property int index

                            width: (parent.width - parent.spacing * 3) / 4
                            height: parent.height

                            StyledRect {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                anchors.topMargin: 8
                                anchors.bottomMargin: 8
                                width: 4
                                radius: Tokens.rounding.full
                                color: Colours.palette.m3surfaceContainerHighest

                                StyledRect {
                                    anchors.bottom: parent.bottom
                                    width: parent.width
                                    height: parent.height * [0.35, 0.7, 0.5, 0.85][index]
                                    radius: parent.radius
                                    color: Colours.palette.m3primary
                                }
                            }
                        }
                    }
                }

                Column {
                    visible: !card.compact && card.work.size !== "vertical"
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: root.innerPad
                    anchors.topMargin: root.innerPad + root.headerHeight + root.rowGap
                    spacing: root.rowGap

                    Repeater {
                        model: 2

                        Column {
                            required property int index

                            width: parent.width
                            spacing: Tokens.spacing.small

                            StyledRect {
                                width: parent.width * 0.4
                                implicitHeight: 10
                                radius: Tokens.rounding.full
                                color: Colours.palette.m3surfaceContainerHighest
                            }

                            StyledRect {
                                width: parent.width
                                implicitHeight: 4
                                radius: Tokens.rounding.full
                                color: Colours.palette.m3surfaceContainerHighest

                                StyledRect {
                                    width: parent.width * (index === 0 ? 0.55 : 0.8)
                                    implicitHeight: parent.implicitHeight
                                    radius: parent.radius
                                    color: Colours.palette.m3primary
                                }
                            }
                        }
                    }
                }
            }
        }

        Component {
            id: togglesDrawing

            Item {
                StyledText {
                    x: root.innerPad
                    y: root.innerPad
                    height: root.headerHeight
                    verticalAlignment: Text.AlignVCenter
                    text: root.cardNames.quickToggles
                    font: Tokens.font.body.medium
                }

                Repeater {
                    model: ScriptModel {
                        values: root.toggleWork.filter(t => t.enabled)
                        objectProp: "id"
                    }

                    ToggleView {}
                }
            }
        }
    }

    // One quick toggle of the drawing
    component ToggleView: StyledRect {
        id: view

        required property var modelData

        readonly property string tid: modelData.id
        readonly property var rect: root.layoutInfo.toggles[tid] ?? ({
                x: 0,
                y: 0,
                w: 0
            })
        readonly property var work: root.toggleWork.find(t => t.id === tid) ?? modelData
        readonly property bool dragging: root.draggingToggle === tid
        readonly property bool selected: root.selectedToggle === tid
        readonly property bool on: root.drawnOn.includes(tid)
        property real dragX
        property real dragY

        x: dragging ? dragX : rect.x
        y: dragging ? dragY : rect.y
        z: dragging ? 10 : selected ? 1 : 0
        width: rect.w
        height: root.rowHeight
        radius: Tokens.rounding.full
        color: on ? Colours.palette.m3secondaryContainer : Colours.layer(Colours.palette.m3surfaceContainerHighest, 2)
        scale: dragging ? 1.05 : 1

        Behavior on x {
            enabled: !view.dragging

            Anim {}
        }

        Behavior on y {
            enabled: !view.dragging

            Anim {}
        }

        Behavior on width {
            enabled: root.resizingToggle !== view.tid

            Anim {}
        }

        Behavior on scale {
            Anim {}
        }

        Row {
            anchors.centerIn: parent
            spacing: Tokens.spacing.small

            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                text: root.toggleIcons[view.tid] ?? "toggle_on"
                color: view.on ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                fontStyle: Tokens.font.icon.medium
            }

            // The name, once the toggle is wide enough to have room for it
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                visible: view.width > 120
                text: root.toggleNames[view.tid] ?? view.tid
                color: view.on ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.medium
            }
        }

        MouseArea {
            property point press

            anchors.fill: parent
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

            onPressed: e => {
                root.selectedToggle = view.tid;
                press = Qt.point(e.x, e.y);
            }
            onPositionChanged: e => {
                if (!pressed)
                    return;

                if (!view.dragging) {
                    if (Math.abs(e.x - press.x) + Math.abs(e.y - press.y) < 6)
                        return;

                    view.dragX = view.rect.x;
                    view.dragY = view.rect.y;
                    root.busy = true;
                    root.draggingToggle = view.tid;
                }

                const p = mapToItem(view.parent, e.x, e.y);
                view.dragX = p.x - press.x;
                view.dragY = p.y - press.y;
                root.moveToggle(view.tid, p.x, p.y);
            }
            onReleased: {
                if (view.dragging)
                    root.finishDrag();
            }
        }

        // The ring round the one that is picked up
        Rectangle {
            anchors.fill: parent
            visible: view.selected
            radius: view.radius
            color: "transparent"
            border.width: 2
            border.color: Colours.palette.m3primary
        }

        // Drag this to change how many columns the toggle takes
        StyledRect {
            id: handle

            anchors.right: parent.right
            anchors.rightMargin: 3
            anchors.verticalCenter: parent.verticalCenter
            visible: view.selected && !view.dragging
            implicitWidth: 8
            implicitHeight: parent.height - 16
            radius: Tokens.rounding.full
            color: Colours.palette.m3primary

            MouseArea {
                anchors.fill: parent
                anchors.margins: -8
                cursorShape: Qt.SizeHorCursor

                onPressed: {
                    root.busy = true;
                    root.resizingToggle = view.tid;
                }
                onPositionChanged: e => {
                    if (!pressed)
                        return;

                    root.resizeToggle(view.tid, mapToItem(view.parent, e.x, e.y).x);
                }
                onReleased: root.finishDrag()
            }
        }

        // The badge on the picked-up toggle: its width in columns, and a way to hide it
        StyledRect {
            anchors.horizontalCenter: parent.left
            anchors.verticalCenter: parent.top
            visible: view.selected && !view.dragging
            implicitWidth: 22
            implicitHeight: 22
            radius: Tokens.rounding.full
            color: Colours.palette.m3errorContainer

            MaterialIcon {
                anchors.centerIn: parent
                text: "close"
                color: Colours.palette.m3onErrorContainer
                fontStyle: Tokens.font.icon.small
            }

            StateLayer {
                onClicked: root.setToggleOn(view.tid, false)
            }
        }

        StyledRect {
            anchors.horizontalCenter: parent.right
            anchors.verticalCenter: parent.top
            visible: view.selected
            implicitWidth: spanText.implicitWidth + Tokens.padding.medium * 2
            implicitHeight: 22
            radius: Tokens.rounding.full
            color: Colours.palette.m3primary

            StyledText {
                id: spanText

                anchors.centerIn: parent
                text: "×" + ToggleRows.spanOf(view.work, root.columns)
                color: Colours.palette.m3onPrimary
                font: Tokens.font.label.small
            }
        }
    }
}
