pragma ComponentBehavior: Bound

import "../../utils/widgetgrid.js" as WidgetGrid
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import Caelestia.Config
import Caelestia.I18n
import Caelestia.Services
import qs.components
import qs.components.controls
import qs.services
import qs.modules.dashboard.media

// Glass widget cards laid out on a snapping grid that covers the desktop. Which cards show and the cell each one
// sits in come from background.desktopWidgets; cards that haven't been placed by hand flow in from a corner.
Item {
    id: root

    required property Item wallpaper

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

    onPlacementsChanged: syncShown()
    Component.onCompleted: syncShown()

    ListModel {
        id: shownModel
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
        }
    }

    // Shared placement of every card on the grid; a card fills its footprint, or grows past it if its content needs to
    component GridCard: DesktopCard {
        // Handed to every delegate by the Repeater/DelegateChooser
        required property string widgetId
        required property int index

        readonly property var slot: root.slotFor(widgetId)

        wallpaper: root.wallpaper
        x: slot.col * WidgetGrid.unit
        y: slot.row * WidgetGrid.unit
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

        visible: source.available
        title: Tr.tr("Now playing")
        icon: "music_note"

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
