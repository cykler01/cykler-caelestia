pragma ComponentBehavior: Bound

import "../../utils/widgetgrid.js" as WidgetGrid
import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.utils
import qs.modules.background.widgets

// Glass widget cards laid out on a snapping grid that covers the desktop. Which cards show and the cell each one
// sits in come from background.desktopWidgets; cards that haven't been placed by hand flow in from a corner.
Item {
    id: root

    required property Item wallpaper
    // The screen's own state, which carries whether the layout is being rearranged
    property var screenState
    // How far the bar band's centre sits from the screen's own, so anything that should line up with the notch
    // (which centres on the band, not the screen) can be shifted by it
    property real notchOffset: 0
    // Whether the desktop is actually uncovered. Holding a card to rearrange is only offered then:
    // with windows over it there is no desktop to press on, and the cards are faded out anyway
    property bool deskClear: true

    readonly property bool editMode: (screenState?.widgetEdit ?? false)
    // The cards take the hold themselves while the layout is settled; once rearranging, the drag
    // handles are over them and holding one means dragging it
    readonly property bool holdToRearrange: !root.editMode && root.deskClear

    // Which card is being dragged in move mode (the entry it shows), where the pointer is within it, and where it
    // would land. Keyed by entry rather than by kind, since the same widget can be on the desktop twice
    property int heldIndex: -1
    property point pointer
    property point grab
    property int dropCol: -1
    property int dropRow: -1
    property bool dropValid: true

    // Set while a card needs the keyboard, which is only while a note is being typed into. The
    // background surface asks for keyboard focus only for as long as that is so (see
    // modules/background/Background.qml), since there is nothing else out on the desktop to type into
    property bool wantsKeyboard
    // The widget picker is open over the desktop, from the button in the rearrange bar
    property bool addingWidget
    // The entry whose style is being changed, from the brush on its card, or -1. The same picker
    // does both jobs: adding one of every style there is, or swapping the style of one already out
    property int stylingIndex: -1

    readonly property var widgetConfig: GlobalConfig.background.desktopWidgets
    readonly property int gridCols: Math.floor(width / WidgetGrid.unit)
    readonly property int gridRows: Math.floor(height / WidgetGrid.unit)
    // Every node's enabled/col/row is read here so the layout is worked out again whenever one changes
    readonly property var placements: {
        const entries = widgetConfig.entries.values;
        for (const e of entries)
            void [e.enabled, e.col, e.row, e.right, e.type];
        // The variant decides how many squares the card takes. The heights go in alongside the entries rather than
        // into copies of them: entries.values hands out the config nodes themselves, and copying those into plain
        // objects loses every property the layout needs
        const heights = entries.map(e => WidgetCatalog.heightFor(e.id, e.type));
        const widths = entries.map(e => WidgetCatalog.widthFor(e.id, e.type));
        return WidgetGrid.place(entries, gridCols, gridRows, widgetConfig.columns, widgetConfig.position, heights, widths);
    }

    // The cards on screen, in entry order. Derived rather than kept in step by hand: adding, removing or turning
    // a widget off is one config write, and this simply reads the result. Every card looks its own cell up in
    // `placements`, so rebuilding the list never hands a card the wrong widget
    readonly property var shownEntries: placements.filter(p => p.enabled).map(p => ({
            // Portfolio is a stocks style, but has its own delegate and config is still keyed by the style
            widgetId: p.id === "stocks" && p.type === "portfolio" ? "portfolio" : p.id,
            entryIndex: p.index
        }))

    function slotFor(index: int): var {
        return placements[index] ?? ({
                col: 0,
                row: 0,
                w: WidgetGrid.cardCells,
                h: 5,
                type: "",
                index: -1
            });
    }

    function placementOf(index: int): var {
        return placements[index] ?? null;
    }

    // Where the held card sits relative to the pointer, so it doesn't jump under it
    function beginDrag(index: int, atX: real, atY: real): void {
        const p = placementOf(index);
        if (!p)
            return;

        heldIndex = index;
        grab = Qt.point(atX - p.col * WidgetGrid.unit, atY - p.row * WidgetGrid.unit);
        pointer = Qt.point(atX, atY);
        updateDrop();
    }

    function updateDrop(): void {
        const p = placementOf(heldIndex);
        if (!p)
            return;

        dropCol = Math.max(0, Math.min(gridCols - p.w, Math.round((pointer.x - grab.x) / WidgetGrid.unit)));
        dropRow = Math.max(0, Math.min(gridRows - p.h, Math.round((pointer.y - grab.y) / WidgetGrid.unit)));
        dropValid = !WidgetGrid.collides(placements, heldIndex, dropCol, dropRow, p.w, p.h);
    }

    function dragTo(atX: real, atY: real): void {
        if (heldIndex < 0)
            return;

        pointer = Qt.point(atX, atY);
        updateDrop();
    }

    // Drops the card, pinning every other card where it is now so nothing shifts once the layout
    // stops flowing into place
    function endDrag(): void {
        const index = heldIndex;
        if (index < 0)
            return;

        const col = dropCol;
        const row = dropRow;
        const valid = dropValid;
        heldIndex = -1;

        if (!valid)
            return;

        const cells = placements.map(p => ({
                    index: p.index,
                    enabled: p.enabled,
                    w: p.w,
                    col: p.col,
                    row: p.row
                }));
        const moved = cells.find(c => c.index === index);
        if (moved) {
            moved.col = col;
            moved.row = row;
        }

        const entries = widgetConfig.entries;
        cells.forEach(cell => {
            const entry = entries.at(cell.index);
            if (!cell.enabled || !entry)
                return;

            const anchor = WidgetGrid.anchor(cell.col, cell.w, gridCols);
            entry.col = anchor.col;
            entry.row = cell.row;
            entry.right = anchor.right;
        });
    }

    // The surface only gets the keyboard while rearranging, so the focus has to be taken then
    onEditModeChanged: {
        if (editMode)
            forceActiveFocus();
        else {
            root.addingWidget = false;
            root.stylingIndex = -1;
        }
    }

    // The picker takes the keyboard for itself while it is up, for its own Escape
    focus: editMode && !root.addingWidget && root.stylingIndex < 0

    Keys.onEscapePressed: {
        if (screenState)
            screenState.widgetEdit = false;
    }

    // How far the rearrange overlays are in. The mode is entered by holding a card, and everything it
    // draws - the grid, the drag handles, the two buttons - used to appear on a single frame, so this is
    // what they are brought in and out with instead. It sits on an item of its own, and is a plain
    // property rather than a readonly one: under Qt 6.12 a Behavior on either the root's own property or
    // on a readonly one segfaults the shell the moment it starts, and both were tried here first
    Item {
        id: reveal

        property real progress: root.editMode ? 1 : 0

        Behavior on progress {
            Anim {
                type: Anim.DefaultEffects
            }
        }
    }

    LoggingCategory {
        id: lc

        name: "caelestia.qml.modules.background.desktopwidgets"
        defaultLogLevel: LoggingCategory.Warning
    }

    Repeater {
        model: root.shownEntries

        DelegateChooser {
            role: "widgetId"

            DelegateChoice {
                roleValue: "calendar"
                delegate: CalendarCard {
                    gridHost: root
                }
            }
            DelegateChoice {
                roleValue: "clock"
                delegate: ClockCard {
                    gridHost: root
                }
            }
            DelegateChoice {
                roleValue: "weather"
                delegate: WeatherCard {
                    gridHost: root
                }
            }
            DelegateChoice {
                roleValue: "pomodoro"
                delegate: FocusCard {
                    gridHost: root
                }
            }
            DelegateChoice {
                roleValue: "resources"
                delegate: SystemCard {
                    gridHost: root
                }
            }
            DelegateChoice {
                roleValue: "network"
                delegate: NetworkCard {
                    gridHost: root
                }
            }
            DelegateChoice {
                roleValue: "media"
                delegate: MediaCard {
                    gridHost: root
                }
            }
            DelegateChoice {
                roleValue: "lyrics"
                delegate: LyricsCard {
                    gridHost: root
                }
            }
            DelegateChoice {
                roleValue: "battery"
                delegate: BatteryCard {
                    gridHost: root
                }
            }
            DelegateChoice {
                roleValue: "bluetooth"
                delegate: BluetoothBatteryCard {
                    gridHost: root
                }
            }
            DelegateChoice {
                roleValue: "fetch"
                delegate: FetchCard {
                    gridHost: root
                }
            }
            DelegateChoice {
                roleValue: "visualiser"
                delegate: VisualiserCard {
                    gridHost: root
                }
            }
            DelegateChoice {
                roleValue: "sticky"
                delegate: StickyCard {
                    gridHost: root
                    onKeyboardWanted: wanted => root.wantsKeyboard = wanted
                }
            }
            DelegateChoice {
                roleValue: "photo"
                delegate: PhotoCard {
                    gridHost: root
                }
            }
            DelegateChoice {
                roleValue: "github"
                delegate: ContributionsCard {
                    gridHost: root
                }
            }
            DelegateChoice {
                roleValue: "stocks"
                delegate: StockCard {
                    gridHost: root
                }
            }
            DelegateChoice {
                roleValue: "portfolio"
                delegate: PortfolioCard {
                    gridHost: root
                }
            }
            DelegateChoice {
                roleValue: "progress"
                delegate: ProgressCard {
                    gridHost: root
                }
            }
            DelegateChoice {
                roleValue: "todo"
                delegate: TodoCard {
                    gridHost: root
                }
            }
            DelegateChoice {
                roleValue: "glance"
                delegate: GlanceCard {
                    gridHost: root
                }
            }
            DelegateChoice {
                roleValue: "search"
                delegate: SearchCard {
                    gridHost: root
                    onKeyboardWanted: wanted => root.wantsKeyboard = wanted
                }
            }
            DelegateChoice {
                roleValue: "sun"
                delegate: SunCard {
                    gridHost: root
                }
            }
            DelegateChoice {
                roleValue: "palette"
                delegate: PaletteCard {
                    gridHost: root
                }
            }
            DelegateChoice {
                roleValue: "shortcuts"
                delegate: ShortcutsCard {
                    gridHost: root
                }
            }
            DelegateChoice {
                roleValue: "toggles"
                delegate: TogglesCard {
                    gridHost: root
                }
            }
            DelegateChoice {
                roleValue: "timer"
                delegate: TimersCard {
                    gridHost: root
                }
            }
            DelegateChoice {
                roleValue: "games"
                delegate: GamesCard {
                    gridHost: root
                }
            }
            DelegateChoice {
                roleValue: "thermal"
                delegate: ThermalCard {
                    gridHost: root
                }
            }
            DelegateChoice {
                roleValue: "phone"
                delegate: PhoneCard {
                    gridHost: root
                }
            }
        }
    }

    // The grid the cards snap to, under everything, only while the layout is being rearranged
    Canvas {
        anchors.fill: parent
        z: -1
        visible: reveal.progress > 0
        opacity: reveal.progress

        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            ctx.strokeStyle = Qt.alpha(Colours.palette.m3outline, 0.3);
            ctx.lineWidth = 1;
            ctx.beginPath();
            for (let x = WidgetGrid.unit; x < width; x += WidgetGrid.unit) {
                ctx.moveTo(x + 0.5, 0);
                ctx.lineTo(x + 0.5, height);
            }
            for (let y = WidgetGrid.unit; y < height; y += WidgetGrid.unit) {
                ctx.moveTo(0, y + 0.5);
                ctx.lineTo(width, y + 0.5);
            }
            ctx.stroke();
        }

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onVisibleChanged: {
            if (visible)
                requestPaint();
        }
    }

    // Where the held card would land: tinted when it fits, red when it would sit on another card
    StyledRect {
        readonly property var held: root.heldIndex >= 0 ? root.placementOf(root.heldIndex) : null

        z: 2
        visible: held !== null
        x: root.dropCol * WidgetGrid.unit + WidgetGrid.gap / 2
        y: root.dropRow * WidgetGrid.unit + WidgetGrid.gap / 2
        width: (held?.w ?? 0) * WidgetGrid.unit - WidgetGrid.gap
        height: (held?.h ?? 0) * WidgetGrid.unit - WidgetGrid.gap
        radius: Tokens.rounding.extraLarge
        color: root.dropValid ? Colours.palette.m3primary : Colours.palette.m3error
        opacity: 0.2
    }

    // A clear handle over each card, since the cards themselves are for reading rather than grabbing.
    // Kept in the tree rather than built when the mode is entered, so the handles can fade in with the
    // grid; while the mode is off they are disabled, and presses fall through to the cards below
    Repeater {
        model: root.placements

        Item {
            id: handle

            required property var modelData

            // NOTE(fork): the handle rides along with the card it belongs to. It used to sit at the
            // cell the layout has on file, so the moment a card was picked up the card went with the
            // pointer and its cross stayed behind on the old cell - a cross for a card that was no
            // longer under it. The card reads the same two numbers for its own position while held
            // (see WidgetCard.qml), so both move as one thing
            readonly property bool held: root.heldIndex === modelData.index

            enabled: root.editMode
            opacity: reveal.progress
            visible: modelData.enabled && reveal.progress > 0
            // Over the card being dragged, which lifts itself above the rest, so the cross stays in
            // sight on the card it belongs to rather than passing under it
            z: handle.held ? 5 : 3
            x: handle.held ? root.pointer.x - root.grab.x : modelData.col * WidgetGrid.unit
            y: handle.held ? root.pointer.y - root.grab.y : modelData.row * WidgetGrid.unit
            width: modelData.w * WidgetGrid.unit - WidgetGrid.gap
            height: modelData.h * WidgetGrid.unit - WidgetGrid.gap

            MouseArea {
                anchors.fill: parent
                preventStealing: true
                cursorShape: Qt.ClosedHandCursor

                onPressed: mouse => {
                    const p = mapToItem(root, mouse.x, mouse.y);
                    root.beginDrag(parent.modelData.index, p.x, p.y);
                }

                onPositionChanged: mouse => {
                    const p = mapToItem(root, mouse.x, mouse.y);
                    root.dragTo(p.x, p.y);
                }

                onReleased: root.endDrag()
                onCanceled: root.endDrag()
            }

            // NOTE(fork): what can be done to a card from the desktop itself, rather than going back
            // through the settings for it: take it off, and change which style of it is showing.
            // Declared after the press that fills the card so these are what the pointer hits, and
            // both write exactly what the settings page writes, so the rest of the layout closes up
            // or re-flows behind them. Inset far enough that the circles sit inside the card's corner
            // curve instead of cutting across it
            Row {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.margins: Tokens.padding.medium
                spacing: Tokens.spacing.extraSmall

                // The one thing here that throws something away, so it wears the error colour
                HandleButton {
                    icon: "close"
                    fill: Colours.palette.m3error
                    onFill: Colours.palette.m3onError
                    onActivated: root.widgetConfig.entries.remove(handle.modelData.index)
                }

                // Only where there is another style to change to
                HandleButton {
                    icon: "style"
                    fill: Colours.palette.m3secondaryContainer
                    onFill: Colours.palette.m3onSecondaryContainer
                    visible: WidgetCatalog.typesFor(handle.modelData.id).length > 1
                    onActivated: root.stylingIndex = handle.modelData.index
                }
            }
        }
    }

    // Adding a widget and arranging them are the same job, so the picker is here rather than only in
    // the settings. Leaving the mode needs no saving: the layout is written on each drop
    RowLayout {
        id: editBar

        // The distance it slides in from, read here rather than inside the Translate below: a
        // transform is not an item, so Tokens has no screen to resolve against in one
        readonly property real dropIn: Tokens.spacing.medium

        z: 5

        // In and out with the grid, and dropping the last few pixels into place, so the mode reads as
        // one thing coming up rather than a jump plus two buttons arriving separately
        opacity: reveal.progress
        visible: reveal.progress > 0
        enabled: root.editMode
        transform: Translate {
            y: -editBar.dropIn * (1 - reveal.progress)
        }
        anchors.horizontalCenter: parent.horizontalCenter
        // Under the notch rather than under the middle of the screen, since those are not the same place
        anchors.horizontalCenterOffset: root.notchOffset
        anchors.top: parent.top
        anchors.topMargin: WidgetGrid.margin * WidgetGrid.unit
        spacing: Tokens.spacing.small

        Pill {
            icon: "add"
            text: Tr.tr("Add widget")
            fill: Colours.palette.m3secondaryContainer
            onFill: Colours.palette.m3onSecondaryContainer
            onActivated: root.addingWidget = true
        }

        Pill {
            icon: "check"
            text: Tr.tr("Done")
            fill: Colours.palette.m3primary
            onFill: Colours.palette.m3onPrimary
            onActivated: root.screenState.widgetEdit = false
        }
    }

    // Only built while it is open: the tiles are live widgets, and an idle picker should not be
    // running a forecast and a CPU reading behind the desktop
    Loader {
        id: picker

        readonly property var styling: root.stylingIndex >= 0 ? root.placementOf(root.stylingIndex) : null

        anchors.fill: parent
        z: 6
        active: root.editMode && (root.addingWidget || root.stylingIndex >= 0)

        sourceComponent: AddWidgetSheet {
            entryIndex: root.stylingIndex
            entryKind: picker.styling?.id ?? ""
            entryType: picker.styling?.type ?? ""
            onClosed: {
                root.addingWidget = false;
                root.stylingIndex = -1;
            }
        }
    }

    // One round button on a card's handle, for the things that can be done to the card itself
    component HandleButton: StyledRect {
        id: button

        required property string icon
        required property color fill
        required property color onFill

        signal activated

        implicitWidth: buttonLabel.implicitHeight + Tokens.padding.extraSmall * 2
        implicitHeight: implicitWidth
        radius: Tokens.rounding.full
        color: button.fill

        MaterialIcon {
            id: buttonLabel

            anchors.centerIn: parent
            text: button.icon
            color: button.onFill
            fontStyle: Tokens.font.icon.small
        }

        StateLayer {
            radius: button.radius
            color: button.onFill
            onClicked: button.activated()
        }
    }

    component Pill: StyledRect {
        id: pill

        required property string icon
        required property string text
        required property color fill
        required property color onFill

        signal activated

        implicitWidth: pillRow.implicitWidth + Tokens.padding.large * 2
        implicitHeight: pillRow.implicitHeight + Tokens.padding.small * 2
        radius: Tokens.rounding.full
        color: pill.fill

        RowLayout {
            id: pillRow

            anchors.centerIn: parent
            spacing: Tokens.spacing.small

            MaterialIcon {
                text: pill.icon
                color: pill.onFill
                fontStyle: Tokens.font.icon.small
            }

            StyledText {
                text: pill.text
                color: pill.onFill
                font: Tokens.font.label.medium
            }
        }

        StateLayer {
            radius: parent.radius
            color: pill.onFill
            onClicked: pill.activated()
        }
    }
}
