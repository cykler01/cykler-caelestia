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

    readonly property bool editMode: (screenState?.widgetEdit ?? false)

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
        return WidgetGrid.place(entries, gridCols, gridRows, widgetConfig.columns, widgetConfig.position, heights);
    }

    // The cards on screen, in entry order. Derived rather than kept in step by hand: adding, removing or turning
    // a widget off is one config write, and this simply reads the result. Every card looks its own cell up in
    // `placements`, so rebuilding the list never hands a card the wrong widget
    readonly property var shownEntries: placements.filter(p => p.enabled).map(p => ({
            widgetId: p.id,
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
    onEditModeChanged: if (editMode) forceActiveFocus()

    focus: editMode

    Keys.onEscapePressed: {
        if (screenState)
            screenState.widgetEdit = false;
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
                roleValue: "battery"
                delegate: BatteryCard {
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
                roleValue: "todo"
                delegate: TodoCard {
                    gridHost: root
                }
            }
        }
    }

    // The grid the cards snap to, under everything, only while the layout is being rearranged
    Canvas {
        anchors.fill: parent
        z: -1
        visible: root.editMode

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

    // A clear handle over each card, since the cards themselves are for reading rather than grabbing
    Repeater {
        model: root.editMode ? root.placements : []

        Item {
            required property var modelData

            visible: modelData.enabled
            z: 3
            x: modelData.col * WidgetGrid.unit
            y: modelData.row * WidgetGrid.unit
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
        }
    }

    // Leaves the mode; the layout is already saved on each drop
    StyledRect {
        z: 5
        visible: root.editMode
        anchors.horizontalCenter: parent.horizontalCenter
        // Under the notch rather than under the middle of the screen, since those are not the same place
        anchors.horizontalCenterOffset: root.notchOffset
        anchors.top: parent.top
        anchors.topMargin: WidgetGrid.margin * WidgetGrid.unit
        implicitWidth: doneRow.implicitWidth + Tokens.padding.large * 2
        implicitHeight: doneRow.implicitHeight + Tokens.padding.small * 2
        radius: Tokens.rounding.full
        color: Colours.palette.m3primary

        RowLayout {
            id: doneRow

            anchors.centerIn: parent
            spacing: Tokens.spacing.small

            MaterialIcon {
                text: "check"
                color: Colours.palette.m3onPrimary
                fontStyle: Tokens.font.icon.small
            }

            StyledText {
                text: Tr.tr("Done")
                color: Colours.palette.m3onPrimary
                font: Tokens.font.label.medium
            }
        }

        StateLayer {
            radius: parent.radius
            color: Colours.palette.m3onPrimary
            onClicked: root.screenState.widgetEdit = false
        }
    }
}
