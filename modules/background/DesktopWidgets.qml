pragma ComponentBehavior: Bound

import "../../utils/widgetgrid.js" as WidgetGrid
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import Caelestia.Config
import Caelestia.I18n
import Caelestia.Models
import Caelestia.Services
import qs.components
import qs.components.controls
import qs.components.effects
import qs.services
import qs.utils
import qs.modules.dashboard.media

// Glass widget cards laid out on a snapping grid that covers the desktop. Which cards show and the cell each one
// sits in come from background.desktopWidgets; cards that haven't been placed by hand flow in from a corner.
Item {
    id: root

    required property Item wallpaper
    // The screen's own state, which carries whether the layout is being rearranged
    property var screenState

    readonly property bool editMode: (screenState?.widgetEdit ?? false)

    // Installed package count for the fetch card; pacman is the only package manager this
    // shell supports, so there is nothing to probe for
    property int packageCount

    // Which card is being dragged in move mode, where the pointer is within it, and where it would land
    property string heldId: ""
    property point pointer
    property point grab
    property int dropCol: -1
    property int dropRow: -1
    property bool dropValid: true

    // Set while a card needs the keyboard, which is only while a note is being typed into. The
    // background surface asks for keyboard focus only for as long as that is so (see
    // modules/background/Background.qml), since there is nothing else out on the desktop to type into
    property bool wantsKeyboard

    readonly property var widgetConfig: Config.background.desktopWidgets
    readonly property int gridCols: Math.floor(width / WidgetGrid.unit)
    readonly property int gridRows: Math.floor(height / WidgetGrid.unit)
    // Every node's enabled/col/row is read here so the layout is worked out again whenever one changes
    readonly property var placements: {
        const entries = widgetConfig.entries.values;
        for (const e of entries)
            void [e.enabled, e.col, e.row, e.right];
        return WidgetGrid.place(entries, gridCols, gridRows, widgetConfig.columns, widgetConfig.position);
    }

    function slotFor(id: string): var {
        return placements.find(p => p.id === id) ?? ({
                col: 0,
                row: 0,
                w: WidgetGrid.cardCells,
                h: 5
            });
    }

    // Brings the list of cards in line with the widgets that are on: a card that is turned off is removed, one that
    // is turned on is added, and the rest are left alone. Every card looks up its own cell in `placements`, so
    // moving one never recreates any. (A list rebuilt from scratch on each change hands cards to the wrong widget
    // when one in the middle disappears.)
    function syncShown(): void {
        const want = placements.filter(p => p.enabled).map(p => p.id);
        for (let i = shownModel.count - 1; i >= 0; i--) {
            if (!want.includes(shownModel.get(i).widgetId))
                shownModel.remove(i);
        }
        want.forEach((id, i) => {
            if (i < shownModel.count && shownModel.get(i).widgetId === id)
                return;
            let from = -1;
            for (let k = i + 1; k < shownModel.count; k++) {
                if (shownModel.get(k).widgetId === id) {
                    from = k;
                    break;
                }
            }
            if (from >= 0)
                shownModel.move(from, i, 1);
            else
                shownModel.insert(i, {
                    widgetId: id
                });
        });
    }

    function placementOf(id: string): var {
        return placements.find(p => p.id === id) ?? null;
    }

    // Where the held card sits relative to the pointer, so it doesn't jump under it
    function beginDrag(id: string, atX: real, atY: real): void {
        const p = placementOf(id);
        if (!p)
            return;

        heldId = id;
        grab = Qt.point(atX - p.col * WidgetGrid.unit, atY - p.row * WidgetGrid.unit);
        pointer = Qt.point(atX, atY);
        updateDrop();
    }

    function updateDrop(): void {
        const p = placementOf(heldId);
        if (!p)
            return;

        dropCol = Math.max(0, Math.min(gridCols - p.w, Math.round((pointer.x - grab.x) / WidgetGrid.unit)));
        dropRow = Math.max(0, Math.min(gridRows - p.h, Math.round((pointer.y - grab.y) / WidgetGrid.unit)));
        dropValid = !WidgetGrid.collides(placements, placements.findIndex(q => q.id === heldId), dropCol, dropRow, p.w, p.h);
    }

    function dragTo(atX: real, atY: real): void {
        if (heldId === "")
            return;

        pointer = Qt.point(atX, atY);
        updateDrop();
    }

    // Drops the card, pinning every other card where it is now so nothing shifts once the layout
    // stops flowing into place
    function endDrag(): void {
        const id = heldId;
        if (id === "")
            return;

        const col = dropCol;
        const row = dropRow;
        const valid = dropValid;
        heldId = "";

        if (!valid)
            return;

        const cells = placements.map(p => ({
                    id: p.id,
                    enabled: p.enabled,
                    w: p.w,
                    col: p.col,
                    row: p.row
                }));
        const moved = cells.find(c => c.id === id);
        if (moved) {
            moved.col = col;
            moved.row = row;
        }

        const entries = widgetConfig.entries;
        cells.forEach((cell, i) => {
            const entry = entries.at(i);
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

    onPlacementsChanged: syncShown()
    Component.onCompleted: syncShown()

    Process {
        running: true
        command: ["sh", "-c", "pacman -Qq 2>/dev/null | wc -l"]

        stdout: StdioCollector {
            onStreamFinished: root.packageCount = parseInt(text()) || 0
        }
    }

    ListModel {
        id: shownModel
    }

    LoggingCategory {
        id: lc

        name: "caelestia.qml.modules.background.desktopwidgets"
        defaultLogLevel: LoggingCategory.Warning
    }

    Repeater {
        model: shownModel

        DelegateChooser {
            role: "widgetId"

            DelegateChoice {
                roleValue: "calendar"
                delegate: CalendarCard {}
            }
            DelegateChoice {
                roleValue: "weather"
                delegate: WeatherCard {}
            }
            DelegateChoice {
                roleValue: "pomodoro"
                delegate: FocusCard {}
            }
            DelegateChoice {
                roleValue: "resources"
                delegate: SystemCard {}
            }
            DelegateChoice {
                roleValue: "media"
                delegate: MediaCard {}
            }
            DelegateChoice {
                roleValue: "battery"
                delegate: BatteryCard {}
            }
            DelegateChoice {
                roleValue: "fetch"
                delegate: FetchCard {}
            }
            DelegateChoice {
                roleValue: "visualiser"
                delegate: VisualiserCard {}
            }
            DelegateChoice {
                roleValue: "sticky"
                delegate: StickyCard {}
            }
            DelegateChoice {
                roleValue: "photo"
                delegate: PhotoCard {}
            }
            DelegateChoice {
                roleValue: "github"
                delegate: ContributionsCard {}
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
        readonly property var held: root.heldId !== "" ? root.placementOf(root.heldId) : null

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
                    root.beginDrag(parent.modelData.id, p.x, p.y);
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

    // Shared placement of every card on the grid; a card fills its footprint, or grows past it if its content needs to
    component GridCard: DesktopCard {
        // Handed to every delegate by the Repeater/DelegateChooser
        required property string widgetId
        required property int index

        readonly property var slot: root.slotFor(widgetId)
        readonly property bool held: root.heldId === widgetId

        wallpaper: root.wallpaper
        z: held ? 4 : 0
        x: held ? root.pointer.x - root.grab.x : slot.col * WidgetGrid.unit
        y: held ? root.pointer.y - root.grab.y : slot.row * WidgetGrid.unit
        width: slot.w * WidgetGrid.unit - WidgetGrid.gap
        height: Math.max(implicitHeight, slot.h * WidgetGrid.unit - WidgetGrid.gap)
    }

    // --- Calendar: month grid ---
    component CalendarCard: GridCard {
        id: cal

        readonly property date now: Time.date
        readonly property var cells: {
            const first = new Date(now.getFullYear(), now.getMonth(), 1);
            const offset = (first.getDay() + 6) % 7; // Monday first
            return Array.from({
                length: 42
            }, (_, i) => {
                const d = new Date(first.getFullYear(), first.getMonth(), 1 - offset + i);
                return {
                    day: d.getDate(),
                    inMonth: d.getMonth() === first.getMonth(),
                    today: d.toDateString() === now.toDateString()
                };
            });
        }

        title: Time.format("MMMM yyyy")
        icon: "calendar_month"

        GridLayout {
            Layout.fillWidth: true
            columns: 7
            rowSpacing: 2
            columnSpacing: 0

            Repeater {
                model: [1, 2, 3, 4, 5, 6, 0]

                StyledText {
                    required property int modelData

                    // Same preferred width as the day cells, so all seven columns come out
                    // equal: a GridLayout sizes each column to its widest cell, which lines the
                    // narrow weekday letters up differently from the two-digit dates
                    Layout.preferredWidth: 1
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: Qt.locale().dayName(modelData, Locale.NarrowFormat)
                    color: Colours.palette.m3primary
                    font: Tokens.font.label.small
                }
            }

            Repeater {
                model: cal.cells

                Item {
                    id: cell

                    required property var modelData

                    Layout.preferredWidth: 1
                    Layout.fillWidth: true
                    implicitHeight: 30

                    StyledRect {
                        anchors.centerIn: parent
                        implicitWidth: 28
                        implicitHeight: 28
                        radius: Tokens.rounding.full
                        color: cell.modelData.today ? Colours.palette.m3primary : "transparent"
                    }

                    StyledText {
                        anchors.centerIn: parent
                        text: cell.modelData.day
                        font: Tokens.font.label.medium
                        color: cell.modelData.today ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                        opacity: cell.modelData.inMonth ? 1 : 0.3
                    }
                }
            }
        }
    }

    // --- Weather ---
    component WeatherCard: GridCard {
        title: Weather.city || Tr.tr("Weather")
        icon: "location_on"
        // The card is created again each time the desktop is uncovered, so only fetch when there is nothing to show
        Component.onCompleted: {
            if (!Weather.cc)
                Weather.reload();
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.medium

            MaterialIcon {
                text: Weather.icon
                color: Colours.palette.m3secondary
                fontStyle: Tokens.font.icon.builders.extraLarge.scale(1.4).build()
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: Weather.temp
                    color: Colours.palette.m3onSurface
                    font: Tokens.font.headline.builders.medium.weight(Font.DemiBold).build()
                }

                StyledText {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: Weather.description
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.medium
                }
            }

            ColumnLayout {
                spacing: Tokens.spacing.extraSmall

                Stat {
                    icon: "humidity_percentage"
                    text: `${Weather.humidity}%`
                }

                Stat {
                    icon: "air"
                    text: `${Math.round(Weather.windSpeed)} km/h`
                }
            }
        }

        StyledRect {
            Layout.fillWidth: true
            implicitHeight: forecastRow.implicitHeight + Tokens.padding.small * 2
            radius: Tokens.rounding.large
            color: Colours.palette.m3surfaceContainerHigh
            opacity: 0.85

            RowLayout {
                id: forecastRow

                anchors.fill: parent
                anchors.margins: Tokens.padding.small
                spacing: 0
                // Equal-width columns however wide each day's text is
                uniformCellSizes: true

                Repeater {
                    model: Weather.forecast.slice(0, 5)

                    ColumnLayout {
                        id: fc

                        required property var modelData
                        required property int index

                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.minimumWidth: 0
                        Layout.maximumWidth: Number.POSITIVE_INFINITY
                        spacing: 2

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: fc.index === 0 ? Tr.tr("Today") : Qt.locale().dayName(new Date(fc.modelData.date).getDay(), Locale.ShortFormat)
                            color: Colours.palette.m3onSurfaceVariant
                            font: Tokens.font.label.small
                        }

                        MaterialIcon {
                            Layout.alignment: Qt.AlignHCenter
                            text: fc.modelData.icon
                            color: Colours.palette.m3secondary
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: Weather.formatTemp(fc.modelData.maxTempC, true)
                            color: Colours.palette.m3onSurface
                            font: Tokens.font.label.small
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: Weather.formatTemp(fc.modelData.minTempC, true)
                            color: Colours.palette.m3outline
                            font: Tokens.font.label.small
                        }
                    }
                }
            }
        }
    }

    // --- Focus timer ---
    component FocusCard: GridCard {
        title: Tr.tr("Focus")
        icon: "timer"

        Pomodoro {
            Layout.fillWidth: true
        }
    }

    // --- System resources ---
    component SystemCard: GridCard {
        id: sys

        title: Tr.tr("System")
        icon: "monitoring"

        ServiceRef {
            service: Cpu
        }

        ServiceRef {
            service: Memory
        }

        ServiceRef {
            service: Storage
        }

        // The rings show a reading taken every few seconds rather than following the live value: a ring that
        // restarts an animation on every tick keeps the whole desktop redrawing, and that was the shell's
        // biggest single power cost while idle.
        property real cpu

        property real memory

        property real disk

        Timer {
            interval: 3000 * PowerSaving.pollSlowdown
            running: true
            repeat: true
            triggeredOnStart: true
            onTriggered: {
                sys.cpu = Cpu.percentage;
                sys.memory = Memory.percentage;
                sys.disk = Storage.percentage;
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.maximumWidth: Number.POSITIVE_INFINITY
            spacing: 0
            // Three equal columns spread across the card, rather than bunched at the left
            uniformCellSizes: true

            Meter {
                label: "CPU"
                icon: "memory"
                value: sys.cpu
                colour: Colours.palette.m3primary
            }

            Meter {
                label: "RAM"
                icon: "memory_alt"
                value: sys.memory
                colour: Colours.palette.m3tertiary
            }

            Meter {
                label: Tr.tr("Disk")
                icon: "hard_disk"
                value: sys.disk
                colour: Colours.palette.m3secondary
            }
        }
    }

    // --- Now playing (only while there is a player, or something remembered from one) ---
    component MediaCard: GridCard {
        id: media

        // Mirrors the notch's own rule: whichever side is actually playing right now wins, and if
        // neither is, whichever paused most recently (Music.lastPlayedAt vs Players.rememberedAt)
        // wins. This is the only widget that used to read Players.active directly, which is why it
        // never showed the in-shell player at all.
        readonly property bool local: Music.playing || (Players.active?.isPlaying !== true && Music.recentlyPlaying && (!Players.recentPlayer || Music.lastPlayedAt >= Players.rememberedAt))
        readonly property MediaSource source: MediaSource {
            local: media.local
            mpris: media.local ? null : Players.recentPlayer
        }

        readonly property bool unknownLength: media.source.length > 2147483647
        readonly property real barValue: media.source.length > 0 && !media.unknownLength ? Math.min(1, Math.max(0, media.source.position / media.source.length)) : 0

        // Minutes:seconds, growing to hours:minutes:seconds for a long track
        function lengthStr(length: real): string {
            if (length < 0)
                return "-1:-1";

            const hours = Math.floor(length / 3600);
            const mins = Math.floor((length % 3600) / 60);
            const secs = Math.floor(length % 60).toString().padStart(2, "0");

            if (hours > 0)
                return `${hours}:${mins.toString().padStart(2, "0")}:${secs}`;
            return `${mins}:${secs}`;
        }

        visible: source.available
        title: Tr.tr("Now playing")
        icon: "music_note"

        Timer {
            running: media.source.isPlaying
            interval: GlobalConfig.dashboard.mediaUpdateInterval
            triggeredOnStart: true
            repeat: true
            onTriggered: media.source.refresh()
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.medium

            ClipRect {
                implicitWidth: 76
                implicitHeight: 76
                radius: Tokens.rounding.large
                color: Colours.palette.m3surfaceContainerHigh

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "album"
                    color: Colours.palette.m3outline
                    fontStyle: Tokens.font.icon.large
                }

                Image {
                    anchors.fill: parent
                    asynchronous: true
                    fillMode: Image.PreserveAspectCrop
                    source: media.source.coverSource
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                StyledText {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: media.source.title || Tr.tr("Unknown title")
                    color: Colours.palette.m3onSurface
                    font: Tokens.font.body.builders.medium.weight(Font.DemiBold).build()
                }

                StyledText {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: media.source.artist || Tr.tr("Unknown artist")
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.medium
                }

                RowLayout {
                    spacing: Tokens.spacing.extraSmall

                    IconButton {
                        icon: "skip_previous"
                        type: IconButton.Text
                        disabled: !media.source.canGoPrevious
                        onClicked: media.source.previous()
                    }

                    IconButton {
                        icon: media.source.isPlaying ? "pause" : "play_arrow"
                        type: IconButton.Filled
                        onClicked: media.source.togglePlaying()
                    }

                    IconButton {
                        icon: "skip_next"
                        type: IconButton.Text
                        disabled: !media.source.canGoNext
                        onClicked: media.source.next()
                    }
                }
            }
        }

        // Playback position: a bar across the card with the elapsed and total time under it
        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.extraSmall
            spacing: Tokens.spacing.extraSmall

            StyledProgressBar {
                Layout.fillWidth: true
                implicitHeight: 4
                value: media.barValue
            }

            RowLayout {
                Layout.fillWidth: true

                StyledText {
                    text: media.lengthStr(media.source.position)
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.small
                }

                Item {
                    Layout.fillWidth: true
                }

                StyledText {
                    text: media.unknownLength ? "--:--" : media.lengthStr(media.source.length)
                    color: Colours.palette.m3outline
                    font: Tokens.font.label.small
                }
            }
        }
    }

    // --- Battery: charge, state, rate and time remaining on a laptop; the GPU's power draw on a desktop ---
    component BatteryCard: GridCard {
        id: bat

        readonly property var dev: UPower.displayDevice
        readonly property bool laptop: dev.isLaptopBattery
        readonly property real pct: dev.percentage
        readonly property bool full: dev.state === UPowerDeviceState.FullyCharged
        readonly property bool charging: dev.state === UPowerDeviceState.Charging || full
        readonly property real rate: Math.abs(dev.changeRate)
        readonly property real seconds: charging ? dev.timeToFull : dev.timeToEmpty
        readonly property bool low: pct < 0.2 && !charging

        function duration(secs: real): string {
            if (secs <= 0)
                return "";
            const h = Math.floor(secs / 3600);
            const m = Math.round((secs % 3600) / 60);
            return h > 0 ? Tr.tr("%1 h %2 min").arg(h).arg(m) : Tr.tr("%1 min").arg(m);
        }

        visible: laptop || Gpu.power > 0
        title: laptop ? Tr.tr("Battery") : Tr.tr("Power draw")
        icon: !laptop ? "bolt" : charging ? "battery_charging_full" : "battery_full"

        ServiceRef {
            service: Gpu
        }

        RowLayout {
            Layout.fillWidth: true
            visible: !bat.laptop
            spacing: Tokens.spacing.medium

            StyledText {
                text: `${Math.round(Gpu.power)} W`
                color: Colours.palette.m3onSurface
                font: Tokens.font.headline.builders.medium.weight(Font.DemiBold).build()
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: Tr.tr("Graphics card")
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.medium
                }

                StyledText {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: Gpu.name
                    color: Colours.palette.m3outline
                    font: Tokens.font.label.small
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: bat.laptop
            spacing: Tokens.spacing.medium

            StyledText {
                text: `${Math.round(bat.pct * 100)}%`
                color: bat.low ? Colours.palette.m3error : Colours.palette.m3onSurface
                font: Tokens.font.headline.builders.medium.weight(Font.DemiBold).build()
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.extraSmall

                StyledText {
                    text: bat.full ? Tr.tr("Fully charged") : bat.charging ? Tr.tr("Charging") : Tr.tr("On battery")
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.medium
                }

                StyledRect {
                    Layout.fillWidth: true
                    implicitHeight: 8
                    radius: Tokens.rounding.full
                    color: Colours.palette.m3surfaceContainerHighest

                    StyledRect {
                        width: parent.width * Math.max(0, Math.min(1, bat.pct))
                        height: parent.height
                        radius: Tokens.rounding.full
                        color: bat.low ? Colours.palette.m3error : bat.charging ? Colours.palette.m3tertiary : Colours.palette.m3primary
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: bat.laptop && ((bat.rate > 0 && !bat.full) || bat.seconds >= 60)
            spacing: Tokens.spacing.small

            MaterialIcon {
                visible: bat.rate > 0 && !bat.full
                text: bat.charging ? "bolt" : "trending_down"
                color: bat.charging ? Colours.palette.m3tertiary : Colours.palette.m3primary
                fontStyle: Tokens.font.icon.small
            }

            StyledText {
                visible: bat.rate > 0 && !bat.full
                text: `${bat.charging ? "+" : "−"}${bat.rate.toFixed(1)} W`
                color: Colours.palette.m3onSurface
                font: Tokens.font.label.medium
            }

            Item {
                Layout.fillWidth: true
            }

            StyledText {
                visible: bat.seconds >= 60 && !bat.full
                text: bat.charging ? Tr.tr("Full in %1").arg(bat.duration(bat.seconds)) : Tr.tr("%1 left").arg(bat.duration(bat.seconds))
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.medium
            }
        }
    }

    // --- Fetch: a neofetch-style summary of the machine, in the same voice as the lock screen's ---
    component FetchCard: GridCard {
        id: fetch

        // Only the lines with something to say; the labels are padded to one width below so the
        // values still line up whatever is missing
        readonly property var rows: {
            const list = [
                {
                    label: Tr.tr("OS"),
                    value: SysInfo.osPrettyName || SysInfo.osName
                },
                {
                    label: Tr.tr("Kernel"),
                    value: SysInfo.kernel
                },
                {
                    label: Tr.tr("Uptime"),
                    value: SysInfo.uptimeShort
                },
                {
                    label: Tr.tr("Packages"),
                    value: root.packageCount > 0 ? Tr.tr("%1 (pacman)").arg(root.packageCount) : ""
                },
                {
                    label: Tr.tr("Shell"),
                    value: SysInfo.shell
                },
                {
                    label: Tr.tr("WM"),
                    value: SysInfo.wm
                },
                {
                    label: Tr.tr("CPU"),
                    value: Cpu.name
                },
                {
                    label: Tr.tr("GPU"),
                    value: Gpu.name
                },
                {
                    label: Tr.tr("Memory"),
                    value: Units.formatKibUsage(Memory.used, Memory.total)
                }
            ];
            return list.filter(r => r.value);
        }
        // Monospace, so padding the labels to the longest of them lines the values up
        readonly property int labelChars: fetch.rows.reduce((n, r) => Math.max(n, r.label.length), 0)

        title: ""
        icon: ""

        ServiceRef {
            service: Cpu
        }

        ServiceRef {
            service: Memory
        }

        ServiceRef {
            service: Gpu
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            // The command whose output the card reads like
            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                StyledText {
                    text: ">"
                    color: Colours.palette.m3primary
                    font: Tokens.font.mono.builders.small.weight(Font.DemiBold).build()
                }

                StyledText {
                    Layout.fillWidth: true
                    text: "caelestiafetch"
                    elide: Text.ElideRight
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.mono.small
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: `${SysInfo.user}@${SysInfo.hostname}`
                elide: Text.ElideRight
                color: Colours.palette.m3primary
                font: Tokens.font.mono.builders.small.weight(Font.DemiBold).build()
            }

            StyledRect {
                Layout.fillWidth: true
                Layout.topMargin: Tokens.spacing.extraSmall
                Layout.bottomMargin: Tokens.spacing.extraSmall
                implicitHeight: 1
                color: Colours.palette.m3outlineVariant
            }

            Repeater {
                model: fetch.rows

                RowLayout {
                    id: infoRow

                    required property var modelData

                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    StyledText {
                        text: infoRow.modelData.label + " ".repeat(fetch.labelChars - infoRow.modelData.label.length)
                        color: Colours.palette.m3primary
                        font: Tokens.font.mono.small
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: infoRow.modelData.value
                        elide: Text.ElideRight
                        color: Colours.palette.m3onSurface
                        font: Tokens.font.mono.small
                    }
                }
            }

            // The terminal palette, as a single strip
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Tokens.spacing.small
                spacing: Tokens.spacing.extraSmall

                Repeater {
                    model: 8

                    StyledRect {
                        required property int index

                        Layout.fillWidth: true
                        Layout.preferredHeight: 6
                        radius: Tokens.rounding.full
                        color: Colours.palette[`term${index}`]
                    }
                }
            }
        }
    }


    // --- Visualiser: the same spectrum the background and the notch draw, on a card ---
    component VisualiserCard: GridCard {
        id: visualiser

        readonly property int barCount: Math.max(1, GlobalConfig.services.visualiserBars)
        // Levels are sampled from cava at the shared decorative rate instead of bound straight to
        // it, so a burst of analyser updates can't rebuild the whole row
        property var levels: []

        title: Tr.tr("Visualiser")
        icon: "graphic_eq"

        // Cava, and the PipeWire capture behind it, only runs while something references it
        ServiceRef {
            service: PowerSaving.pauseVisualisers ? null : Audio.cava
        }

        Timer {
            interval: PowerSaving.frameMs
            repeat: true
            triggeredOnStart: true
            running: visualiser.visible && !PowerSaving.pauseVisualisers

            onTriggered: {
                const values = Audio.cava.values;
                const next = new Array(visualiser.barCount);
                for (let i = 0; i < visualiser.barCount; i++)
                    next[i] = Math.min(1, Math.max(0, values[i] ?? 0));
                visualiser.levels = next;
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 80

            RowLayout {
                anchors.fill: parent
                spacing: Tokens.spacing.extraSmall

                Repeater {
                    model: visualiser.barCount

                    Item {
                        required property int index

                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        // A bar grows up from the bottom of its own slot; the 2px floor keeps the
                        // row visible while the room is quiet instead of collapsing to nothing
                        StyledRect {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: Math.max(2, parent.height * (visualiser.levels[index] ?? 0))
                            radius: Math.min(width / 2, height / 2)
                            color: Colours.palette.m3primary

                            Behavior on height {
                                Anim {
                                    type: Anim.FastSpatial
                                }
                            }
                        }
                    }
                }
            }
        }
    }


    // --- Sticky note: short text written straight into the card ---
    component StickyCard: GridCard {
        id: sticky

        // The note is a plain file, so it outlives the shell reloading
        readonly property string notePath: `${Paths.data}/sticky-note.md`
        // Trimmed, so a note of nothing but blank lines still reads as empty
        readonly property string body: sticky.note.trim()

        property string note

        property bool editing
        property bool hovered

        function startEditing(): void {
            input.text = sticky.note;
            sticky.editing = true;
            input.forceActiveFocus();
        }

        function stopEditing(): void {
            if (!sticky.editing)
                return;

            sticky.editing = false;
            save.stop();
            sticky.note = input.text;
            sticky.write();
        }

        function write(): void {
            store.setText(sticky.note);
        }

        title: Tr.tr("Sticky note")
        icon: "sticky_note_2"
        onHoveredChanged: root.wantsKeyboard = sticky.hovered || sticky.editing
        onEditingChanged: root.wantsKeyboard = sticky.hovered || sticky.editing

        FileView {
            id: store

            printErrors: false
            watchChanges: true
            path: sticky.notePath

            // Text being typed in the card wins over what is on disk, so the file can't pull the
            // caret out from under it
            onLoaded: {
                if (!sticky.editing)
                    sticky.note = text();
            }
            // The signal this FileView emits when the file on disk changes under it
            onFileChanged: {
                if (!sticky.editing)
                    sticky.note = text();
            }
            // No file yet is the normal first run: the first keystroke creates it
            onLoadFailed: sticky.note = ""
        }

        // Saved as typing settles rather than on every keystroke
        Timer {
            id: save

            interval: 400
            onTriggered: sticky.write()
        }

        StyledRect {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 60
            implicitHeight: noteText.implicitHeight + Tokens.padding.medium * 2
            radius: Tokens.rounding.large
            color: Colours.tPalette.m3surfaceContainerHigh
            opacity: 0.85
            clip: true

            StyledText {
                id: noteText

                anchors.fill: parent
                anchors.margins: Tokens.padding.medium
                visible: !sticky.editing
                text: sticky.body !== "" ? sticky.note : Tr.tr("Click to write a note")
                color: sticky.body !== "" ? Colours.palette.m3onSurface : Colours.palette.m3outline
                font: Tokens.font.body.medium
                wrapMode: Text.Wrap
                elide: Text.ElideRight
                // As many whole lines as the card has room for; anything past that is elided
                maximumLineCount: Math.max(1, Math.floor(height / Math.max(1, lineHeight)))
            }

            TextEdit {
                id: input

                anchors.fill: parent
                anchors.margins: Tokens.padding.medium
                visible: sticky.editing
                wrapMode: TextEdit.Wrap
                selectByMouse: true
                persistentSelection: true
                color: Colours.palette.m3onSurface
                selectionColor: Qt.alpha(Colours.palette.m3primary, 0.4)
                selectedTextColor: Colours.palette.m3onSurface
                font: Tokens.font.body.medium
                renderType: Text.NativeRendering

                onTextChanged: {
                    if (sticky.editing)
                        save.restart();
                }

                Keys.onEscapePressed: sticky.stopEditing()

                onActiveFocusChanged: {
                    // Clicking off the note, or the desktop being covered, ends the edit
                    if (!activeFocus && sticky.editing)
                        sticky.stopEditing();
                }
            }

            // Kept off the text editor (disabled while typing) so clicks in there place the caret
            MouseArea {
                anchors.fill: parent
                enabled: !sticky.editing
                cursorShape: Qt.IBeamCursor
                onClicked: sticky.startEditing()
            }

            // Separate from the MouseArea, so hovering stays tracked while editing disables it
            HoverHandler {
                onHoveredChanged: sticky.hovered = hovered
            }
        }
    }

    // --- Photo: a picture from a folder, one at a time ---
    component PhotoCard: GridCard {
        id: photo

        readonly property var files: images.entries
        // The photo showing, by path, so the card can find its place in the folder again after a rescan
        property string current

        readonly property int position: photo.files.findIndex(f => f.path === photo.current)

        function pick(): void {
            if (photo.files.length === 0) {
                photo.current = "";
                return;
            }

            photo.current = photo.files[Math.floor(Math.random() * photo.files.length)].path;
        }

        function step(delta: int): void {
            const n = photo.files.length;
            if (n === 0)
                return;

            // Stepping from a photo that has since left the folder starts again from the top
            const i = photo.position < 0 ? 0 : photo.position;
            photo.current = photo.files[(i + delta + n) % n].path;
        }

        title: Tr.tr("Pictures")
        icon: "photo"

        // A random photo to start with, and another whenever the one showing is no longer there
        Component.onCompleted: photo.pick()
        onFilesChanged: {
            if (photo.position < 0)
                photo.pick();
        }

        FileSystemModel {
            id: images

            path: root.widgetConfig.photoDir
            recursive: true
            watchChanges: true
            filter: FileSystemModel.Images
        }

        // The photo area. The picture is scaled to fit and centred, its own corners rounded, and the
        // space around it left unpainted so the card's plate, tint and wallpaper blur show through
        // exactly as they do beside the header
        Item {
            id: frame

            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 100

            // How much the picture has to shrink to fit the area, so the rounded frame can be cut to
            // the picture rather than to the area
            readonly property real fit: pic.sourceSize.width > 0 && pic.sourceSize.height > 0 ? Math.min(width / pic.sourceSize.width, height / pic.sourceSize.height) : 0

            ClipRect {
                anchors.centerIn: parent
                width: Math.round(pic.sourceSize.width * frame.fit)
                height: Math.round(pic.sourceSize.height * frame.fit)
                radius: Tokens.rounding.large

                Image {
                    id: pic

                    anchors.fill: parent
                    asynchronous: true
                    fillMode: Image.PreserveAspectFit
                    source: photo.current !== "" ? Paths.absolutePath(photo.current) : ""
                }

                // Text buttons carry no plate, so nothing frames the arrows against the picture
                IconButton {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.margins: Tokens.spacing.small
                    visible: photo.files.length > 1
                    icon: "chevron_left"
                    type: IconButton.Text
                    inactiveOnColour: Colours.palette.m3onSurface
                    onClicked: photo.step(-1)
                }

                IconButton {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: Tokens.spacing.small
                    visible: photo.files.length > 1
                    icon: "chevron_right"
                    type: IconButton.Text
                    inactiveOnColour: Colours.palette.m3onSurface
                    onClicked: photo.step(1)
                }
            }

            StyledText {
                anchors.centerIn: parent
                width: parent.width - Tokens.padding.medium * 2
                visible: photo.files.length === 0
                horizontalAlignment: Text.AlignHCenter
                text: Tr.tr("No photos in the folder")
                color: Colours.palette.m3outline
                font: Tokens.font.label.medium
                wrapMode: Text.Wrap
            }
        }
    }

    // --- Contributions: this week's GitHub activity, a square a day ---
    component ContributionsCard: GridCard {
        id: gh

        readonly property real gap: 6

        readonly property string user: (root.widgetConfig.githubUser ?? "").trim()
        // Letters, digits and hyphens only: the name is part of a URL, so nothing else gets through
        readonly property bool userValid: /^[A-Za-z0-9-]+$/.test(gh.user)

        // Sunday through Saturday of the week we are in: [{ date, count, level }]
        property var week: []
        property int total: 0
        // Index of the square being hovered, -1 for none
        property int hovered: -1
        // Whatever went wrong, shown on the card: a failure should never be a blank space
        property string error

        // What the card says instead of the squares
        readonly property string message: {
            if (gh.user === "")
                return Tr.tr("Set a GitHub name in Settings");
            if (!gh.userValid)
                return Tr.tr("That is not a valid GitHub name");
            if (gh.week.length > 0)
                return "";
            return gh.error !== "" ? gh.error : Tr.tr("Loading...");
        }

        // The square under the pointer as a readable day, or null
        readonly property var hoveredDay: {
            const day = gh.hovered >= 0 && gh.hovered < gh.week.length ? gh.week[gh.hovered] : null;
            if (!day)
                return null;

            return {
                date: Qt.formatDate(new Date(`${day.date}T00:00:00`), "d MMM"),
                count: day.count
            };
        }

        function levelColour(level: int): color {
            if (level <= 0)
                return Qt.alpha(Colours.palette.m3outlineVariant, 0.35);

            return Qt.alpha(Colours.palette.m3primary, 0.3 + 0.175 * Math.min(4, level));
        }

        // The seven days up to and including today, oldest first, so today is the rightmost square.
        // Worked out when the data arrives rather than once at build time, so the card doesn't keep
        // showing the week it was created in
        function weekDates(): var {
            const now = new Date();

            return Array.from({
                length: 7
            }, (_, i) => {
                const day = new Date(now.getFullYear(), now.getMonth(), now.getDate() - (6 - i));
                const month = String(day.getMonth() + 1).padStart(2, "0");
                const date = String(day.getDate()).padStart(2, "0");
                return `${day.getFullYear()}-${month}-${date}`;
            });
        }

        // Started by hand rather than with a `running` binding, so a name change re-fetches instead of
        // leaving the previous name's week on the card
        function reload(): void {
            gh.week = [];
            gh.total = 0;
            gh.hovered = -1;
            gh.error = "";

            if (!gh.userValid)
                return;

            fetch.running = false;
            fetch.running = true;
        }

        // The calendar as JSON rather than as GitHub's page: the page's markup moves, this shape does
        // not, and it carries the counts outright
        function parse(json: string): void {
            let data;
            try {
                data = JSON.parse(json);
            } catch (e) {
                gh.error = Tr.tr("Could not read the contributions data");
                console.warn(lc, `Contributions: unreadable response: ${e}`);
                return;
            }

            const list = Array.isArray(data?.contributions) ? data.contributions : [];
            if (list.length === 0) {
                gh.error = Tr.tr("No contributions came back for this name");
                return;
            }

            const byDate = {};
            for (const day of list)
                byDate[day.date] = day;

            gh.week = weekDates().map(date => ({
                date: date,
                count: byDate[date]?.count ?? 0,
                level: byDate[date]?.level ?? 0
            }));
            gh.total = gh.week.reduce((sum, day) => sum + day.count, 0);
            gh.error = "";
        }

        title: Tr.tr("GitHub")
        icon: "calendar_view_week"

        Component.onCompleted: gh.reload()
        onUserChanged: gh.reload()

        Process {
            id: fetch

            running: false
            // A public mirror of the calendar, so there is no token and nothing to set up but the name
            command: ["sh", "-c", `curl -fsSL --max-time 20 "https://github-contributions-api.jogruber.de/v4/${gh.user}?y=last"`]

            // curl's own complaint, so a failed fetch says why on the card instead of going quiet
            stderr: StdioCollector {
                onStreamFinished: {
                    const complaint = text.trim();
                    if (complaint !== "" && gh.week.length === 0)
                        gh.error = complaint;
                }
            }

            stdout: StdioCollector {
                onStreamFinished: gh.parse(text)
            }
        }

        // The week turns over at midnight, so the squares are read again rather than left on the
        // week the card was built in
        Timer {
            interval: 1800000
            repeat: true
            running: true
            onTriggered: gh.reload()
        }

        StyledText {
            Layout.fillWidth: true
            visible: gh.message !== ""
            wrapMode: Text.Wrap
            text: gh.message
            color: gh.error !== "" ? Colours.palette.m3error : Colours.palette.m3outline
            font: Tokens.font.label.medium
        }

        Item {
            // Seven squares share the width, each as tall as it is wide
            readonly property real cell: Math.max(2, (width - 6 * gh.gap) / 7)

            Layout.fillWidth: true
            implicitHeight: cell
            visible: gh.week.length > 0

            Repeater {
                model: gh.week

                StyledRect {
                    required property var modelData
                    required property int index

                    border.width: gh.hovered === index ? 1 : 0
                    border.color: Colours.palette.m3primary

                    x: index * (parent.cell + gh.gap)
                    y: 0
                    width: parent.cell
                    height: parent.cell
                    radius: Math.min(Tokens.rounding.medium, parent.cell / 3)
                    color: gh.levelColour(modelData.level)

                    // Clearing only our own index, so moving between two squares doesn't blank it
                    HoverHandler {
                        onHoveredChanged: {
                            if (hovered)
                                gh.hovered = index;
                            else if (gh.hovered === index)
                                gh.hovered = -1;
                        }
                    }
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            visible: gh.week.length > 0
            horizontalAlignment: Text.AlignRight
            // The week's total, or the day under the pointer while one is hovered
            text: gh.hoveredDay ? gh.hoveredDay.date + " · " + (gh.hoveredDay.count === 1 ? Tr.tr("1 commit") : Tr.tr("%1 commits").arg(gh.hoveredDay.count)) : Tr.tr("%1 this week").arg(gh.total)
            color: gh.hoveredDay ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant
            font: Tokens.font.label.small
        }
    }

    component Stat: RowLayout {
        property string icon
        property string text

        spacing: Tokens.spacing.extraSmall

        MaterialIcon {
            text: parent.icon
            color: Colours.palette.m3outline
            fontStyle: Tokens.font.icon.small
        }

        StyledText {
            text: parent.text
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.label.small
        }
    }

    component Meter: ColumnLayout {
        id: meter

        property string label
        property string icon
        property real value
        property color colour

        Layout.fillWidth: true
        Layout.maximumWidth: Number.POSITIVE_INFINITY
        spacing: Tokens.spacing.extraSmall

        CircularProgress {
            Layout.alignment: Qt.AlignHCenter
            implicitSize: 64
            strokeWidth: 6
            value: meter.value
            fgColour: meter.colour
            bgColour: Colours.palette.m3surfaceContainerHighest

            // Short and without overshoot: it only ever runs once every few seconds
            Behavior on clampedVal {
                Anim {
                    type: Anim.FastEffects
                }
            }

            MaterialIcon {
                anchors.centerIn: parent
                text: meter.icon
                color: meter.colour
                fontStyle: Tokens.font.icon.medium
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: `${meter.label} ${Math.round(meter.value * 100)}%`
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.label.small
        }
    }
}
