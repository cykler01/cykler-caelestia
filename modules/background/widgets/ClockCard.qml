pragma ComponentBehavior: Bound

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
import qs.modules.background
import qs.modules.dashboard.media
import qs.modules.launcher.services

// --- Clock: digital, time only, an analogue face, stacked or oversized figures, a scalloped face,
// or the time in a few other cities ---
WidgetCard {
    id: clock

    // Its own tick, rather than Time.date: the face has a second hand
    property date now: new Date()

    readonly property string style: clock.variant === "" ? "digital" : clock.variant

    // The newer styles follow the shell's 12/24-hour setting. Hours are always two figures, as the
    // bar's clock has them, so the big layouts don't shift sideways at ten o'clock
    readonly property bool twelveHour: Units.twelveHourClock
    readonly property string hourText: Qt.formatTime(clock.now, clock.twelveHour ? "hh AP" : "HH").split(" ")[0]
    readonly property string minuteText: Qt.formatTime(clock.now, "mm")
    readonly property string amPm: clock.twelveHour ? Qt.formatTime(clock.now, "AP") : ""

    // The cities the world clock shows: what they are called and their zone. A plain JS Date can't be
    // asked for another zone's time here (there's no Intl), so each zone's offset is read off `date`
    // below and the time worked out from that
    readonly property var cities: [
        {
            name: Tr.tr("London"),
            zone: "Europe/London"
        },
        {
            name: Tr.tr("New York"),
            zone: "America/New_York"
        },
        {
            name: Tr.tr("Tokyo"),
            zone: "Asia/Tokyo"
        }
    ]
    // Minutes east of UTC for each city above, in the same order; empty until `date` has answered
    property var zoneOffsets: []

    // A city's wall-clock time now, as a Date whose local fields read as that city's
    function cityTime(index: int): date {
        const offset = clock.zoneOffsets[index];
        if (offset === undefined)
            return clock.now;
        const utc = clock.now.getTime() + clock.now.getTimezoneOffset() * 60000;
        return new Date(utc + offset * 60000);
    }

    // "+8 h", "-5 h 30 min" or "±0 h", against the clock here
    function offsetText(index: int): string {
        const offset = clock.zoneOffsets[index];
        if (offset === undefined)
            return "";
        const diff = offset + clock.now.getTimezoneOffset();
        if (diff === 0)
            return "\u00b10 h";
        const h = Math.trunc(Math.abs(diff) / 60);
        const m = Math.abs(diff) % 60;
        const sign = diff > 0 ? "+" : "\u2212";
        if (m === 0)
            return Tr.tr("%1%2 h").arg(sign).arg(h);
        return Tr.tr("%1%2 h %3 min").arg(sign).arg(h).arg(m);
    }

    // Whether the city is a day ahead of here (1), behind (-1), or on the same day (0)
    function dayShift(index: int): int {
        const there = clock.cityTime(index);
        const here = new Date(clock.now.getFullYear(), clock.now.getMonth(), clock.now.getDate());
        const thereDay = new Date(there.getFullYear(), there.getMonth(), there.getDate());
        return Math.sign(Math.round((thereDay - here) / 86400000));
    }

    title: clock.style === "analogue" ? Tr.tr("Clock") : ""
    icon: ""

    Timer {
        interval: 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: clock.now = new Date()
    }

    StyledText {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: clock.style === "minimal"
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: Qt.formatTime(clock.now, "HH:mm")
        color: Colours.palette.m3onSurface
        font: Tokens.font.title.large
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: clock.style === "digital"
        spacing: Tokens.spacing.extraSmall

        StyledText {
            Layout.fillWidth: true
            Layout.fillHeight: true
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
            text: Qt.formatTime(clock.now, "HH:mm")
            color: Colours.palette.m3onSurface
            font: Tokens.font.title.large
        }

        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: Qt.formatDate(clock.now, "dddd d MMMM")
            color: Colours.palette.m3outline
            font: Tokens.font.label.medium
        }
    }

    Canvas {
        id: face

        function hand(ctx, cx, cy, angle: real, length: real, width: real, colour: color): void {
            ctx.strokeStyle = colour;
            ctx.lineWidth = width;
            ctx.lineCap = "round";
            ctx.beginPath();
            ctx.moveTo(cx - Math.sin(angle) * length * 0.12, cy + Math.cos(angle) * length * 0.12);
            ctx.lineTo(cx + Math.sin(angle) * length, cy - Math.cos(angle) * length);
            ctx.stroke();
        }

        Layout.alignment: Qt.AlignHCenter
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: 120
        Layout.preferredHeight: 120
        visible: clock.style === "analogue"

        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);

            const cx = width / 2;
            const cy = height / 2;
            const r = Math.min(cx, cy) - 2;
            if (r <= 0)
                return;

            ctx.strokeStyle = Qt.alpha(Colours.palette.m3outlineVariant, 0.6);
            ctx.lineWidth = 1;
            ctx.beginPath();
            ctx.arc(cx, cy, r, 0, Math.PI * 2);
            ctx.stroke();

            // Twelve ticks, the quarters longer, so the face reads as a clock at a glance
            ctx.strokeStyle = Colours.palette.m3outline;
            for (let i = 0; i < 12; i++) {
                const a = (i / 12) * Math.PI * 2;
                const inner = r * (i % 3 === 0 ? 0.78 : 0.87);
                ctx.lineWidth = i % 3 === 0 ? 2 : 1;
                ctx.beginPath();
                ctx.moveTo(cx + Math.sin(a) * inner, cy - Math.cos(a) * inner);
                ctx.lineTo(cx + Math.sin(a) * r * 0.94, cy - Math.cos(a) * r * 0.94);
                ctx.stroke();
            }

            const seconds = clock.now.getSeconds();
            const minutes = clock.now.getMinutes() + seconds / 60;
            const hours = (clock.now.getHours() % 12) + minutes / 60;

            face.hand(ctx, cx, cy, (hours / 12) * Math.PI * 2, r * 0.5, 3, Colours.palette.m3onSurface);
            face.hand(ctx, cx, cy, (minutes / 60) * Math.PI * 2, r * 0.72, 2, Colours.palette.m3onSurface);
            face.hand(ctx, cx, cy, (seconds / 60) * Math.PI * 2, r * 0.8, 1, Colours.palette.m3primary);

            ctx.fillStyle = Colours.palette.m3primary;
            ctx.beginPath();
            ctx.arc(cx, cy, 2.5, 0, Math.PI * 2);
            ctx.fill();
        }

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onVisibleChanged: {
            if (visible)
                requestPaint();
        }

        Connections {
            function onNowChanged(): void {
                face.requestPaint();
            }

            target: clock
        }
    }

    // Stacked: the hour on a filled block over the minutes on a quieter one, the date under them
    Loader {
        Layout.fillWidth: true
        Layout.fillHeight: true
        active: clock.style === "stacked"
        visible: active

        sourceComponent: ColumnLayout {
            spacing: Tokens.spacing.small

            FigureBlock {
                text: clock.hourText
                colour: Colours.palette.m3primaryContainer
                onColour: Colours.palette.m3onPrimaryContainer
                weight: Font.Bold
                badge: clock.amPm
            }

            FigureBlock {
                text: clock.minuteText
                colour: Colours.palette.m3secondaryContainer
                onColour: Colours.palette.m3onSecondaryContainer
                weight: Font.Medium
            }

            StyledText {
                Layout.fillWidth: true
                Layout.topMargin: Tokens.spacing.extraSmall
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: Qt.formatDate(clock.now, "ddd d MMM")
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.builders.medium.weight(Font.DemiBold).build()
            }
        }
    }

    // Large: nothing but the figures, as big as the card lets them be - hours heavy, minutes light
    Loader {
        Layout.fillWidth: true
        Layout.fillHeight: true
        active: clock.style === "large"
        visible: active

        sourceComponent: Item {
            StyledText {
                id: bigHour

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: -parent.height * 0.04
                height: parent.height * 0.56
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                // Fitted to its half of the card rather than given a size, so the figures fill
                // whatever footprint the card is given. The two halves overlap a little: a line
                // of text is taller than the figures in it, and without the overlap the gap
                // between the rows would be most of the card
                fontSizeMode: Text.Fit
                minimumPointSize: Tokens.font.label.small.pointSize
                text: clock.hourText
                color: Colours.palette.m3primary
                font: Tokens.font.clock.size(400).weight(Font.Black).letterSpacing(-4).build()
            }

            StyledText {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.bottomMargin: -parent.height * 0.04
                height: bigHour.height
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                fontSizeMode: Text.Fit
                minimumPointSize: Tokens.font.label.small.pointSize
                text: clock.minuteText
                color: Colours.palette.m3onSurface
                font: Tokens.font.clock.size(400).weight(Font.Light).letterSpacing(-4).build()
            }

            // The only chrome: AM/PM tucked into a corner on a 12-hour clock
            StyledText {
                anchors.right: parent.right
                anchors.top: parent.top
                visible: clock.amPm !== ""
                text: clock.amPm
                color: Colours.palette.m3tertiary
                font: Tokens.font.label.builders.medium.weight(Font.Bold).letterSpacing(1).build()
            }
        }
    }

    // World: the time here on a highlighted bar, three other cities in tiles under it
    Loader {
        Layout.fillWidth: true
        Layout.fillHeight: true
        active: clock.style === "world"
        visible: active

        sourceComponent: ColumnLayout {
            spacing: Tokens.spacing.small

            StyledRect {
                Layout.fillWidth: true
                implicitHeight: localRow.implicitHeight + Tokens.padding.small * 2
                radius: Tokens.rounding.full
                color: Colours.palette.m3primaryContainer

                RowLayout {
                    id: localRow

                    anchors.fill: parent
                    anchors.leftMargin: Tokens.padding.medium
                    anchors.rightMargin: Tokens.padding.medium
                    spacing: Tokens.spacing.small

                    MaterialIcon {
                        text: "near_me"
                        fill: 1
                        color: Colours.palette.m3onPrimaryContainer
                        fontStyle: Tokens.font.icon.small
                    }

                    StyledText {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: Weather.city || Tr.tr("Here")
                        color: Colours.palette.m3onPrimaryContainer
                        font: Tokens.font.label.builders.large.weight(Font.DemiBold).build()
                    }

                    StyledText {
                        text: Qt.formatTime(clock.now, clock.twelveHour ? "h:mm AP" : "HH:mm")
                        color: Colours.palette.m3onPrimaryContainer
                        font: Tokens.font.title.builders.medium.weight(Font.DemiBold).build()
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Tokens.spacing.small
                uniformCellSizes: true

                Repeater {
                    model: clock.cities

                    StyledRect {
                        id: city

                        required property var modelData
                        required property int index

                        readonly property date time: clock.cityTime(city.index)
                        // Daylight there, roughly: enough to pick a sun or a moon for the tile
                        readonly property bool day: city.time.getHours() >= 7 && city.time.getHours() < 19

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Tokens.rounding.large
                        color: Colours.palette.m3surfaceContainerHigh

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: Tokens.padding.small
                            spacing: 0

                            StyledText {
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                text: city.modelData.name
                                color: Colours.palette.m3onSurfaceVariant
                                font: Tokens.font.label.builders.medium.weight(Font.DemiBold).build()
                            }

                            Item {
                                Layout.fillHeight: true
                            }

                            RowLayout {
                                spacing: 2

                                StyledText {
                                    text: Qt.formatTime(city.time, clock.twelveHour ? "h:mm" : "HH:mm")
                                    color: Colours.palette.m3onSurface
                                    font: Tokens.font.title.builders.large.weight(Font.DemiBold).build()
                                }

                                // AM/PM, or the day it is there when that isn't today: "+1" the way
                                // timetables mark an arrival the next morning
                                StyledText {
                                    Layout.alignment: Qt.AlignTop
                                    visible: text !== ""
                                    text: clock.dayShift(city.index) !== 0 ? (clock.dayShift(city.index) > 0 ? "+1" : "\u22121") : clock.twelveHour ? Qt.formatTime(city.time, "AP") : ""
                                    color: clock.dayShift(city.index) !== 0 ? Colours.palette.m3tertiary : Colours.palette.m3outline
                                    font: Tokens.font.label.builders.small.weight(Font.Bold).build()
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Tokens.spacing.extraSmall

                                MaterialIcon {
                                    text: city.day ? "light_mode" : "dark_mode"
                                    fill: 1
                                    color: city.day ? Colours.palette.m3tertiary : Colours.palette.m3outline
                                    fontStyle: Tokens.font.icon.builders.small.scale(0.8).build()
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    text: clock.offsetText(city.index)
                                    color: Colours.palette.m3outline
                                    font: Tokens.font.label.small
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Face: a scalloped, cookie-shaped dial with chunky hands, which is what sets it apart from the
    // plain analogue one. The second is a dot running round the rim, left off without animations
    Loader {
        Layout.fillWidth: true
        Layout.fillHeight: true
        active: clock.style === "face"
        visible: active

        sourceComponent: Canvas {
            id: cookie

            readonly property bool seconds: PowerSaving.animations

            function hand(ctx, cx, cy, angle: real, length: real, width: real, colour: color): void {
                ctx.strokeStyle = colour;
                ctx.lineWidth = width;
                ctx.lineCap = "round";
                ctx.beginPath();
                ctx.moveTo(cx, cy);
                ctx.lineTo(cx + Math.sin(angle) * length, cy - Math.cos(angle) * length);
                ctx.stroke();
            }

            onPaint: {
                const ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);

                const cx = width / 2;
                const cy = height / 2;
                const r = Math.min(cx, cy) - 2;
                if (r <= 0)
                    return;

                // Twelve soft lobes, one per hour, so the outline itself does the work of hour marks
                const lobes = 12;
                const depth = 0.06;
                ctx.fillStyle = Colours.palette.m3primaryContainer;
                ctx.beginPath();
                for (let i = 0; i <= 360; i++) {
                    const a = (i / 360) * Math.PI * 2;
                    const rr = r * (1 - depth + depth * Math.cos(a * lobes));
                    const x = cx + Math.sin(a) * rr;
                    const y = cy - Math.cos(a) * rr;
                    if (i === 0)
                        ctx.moveTo(x, y);
                    else
                        ctx.lineTo(x, y);
                }
                ctx.closePath();
                ctx.fill();

                // A dot in each lobe, the quarters bigger
                ctx.fillStyle = Colours.palette.m3onPrimaryContainer;
                for (let i = 0; i < 12; i++) {
                    const a = (i / 12) * Math.PI * 2;
                    const quarter = i % 3 === 0;
                    ctx.globalAlpha = quarter ? 0.9 : 0.4;
                    ctx.beginPath();
                    ctx.arc(cx + Math.sin(a) * r * 0.82, cy - Math.cos(a) * r * 0.82, quarter ? r * 0.045 : r * 0.028, 0, Math.PI * 2);
                    ctx.fill();
                }
                ctx.globalAlpha = 1;

                const secs = clock.now.getSeconds();
                const minutes = clock.now.getMinutes() + (cookie.seconds ? secs / 60 : 0);
                const hours = (clock.now.getHours() % 12) + minutes / 60;

                cookie.hand(ctx, cx, cy, (hours / 12) * Math.PI * 2, r * 0.45, r * 0.11, Colours.palette.m3primary);
                cookie.hand(ctx, cx, cy, (minutes / 60) * Math.PI * 2, r * 0.64, r * 0.06, Colours.palette.m3onPrimaryContainer);

                if (cookie.seconds) {
                    const a = (secs / 60) * Math.PI * 2;
                    ctx.fillStyle = Colours.palette.m3tertiary;
                    ctx.beginPath();
                    ctx.arc(cx + Math.sin(a) * r * 0.7, cy - Math.cos(a) * r * 0.7, r * 0.045, 0, Math.PI * 2);
                    ctx.fill();
                }

                ctx.fillStyle = Colours.palette.m3tertiary;
                ctx.beginPath();
                ctx.arc(cx, cy, r * 0.07, 0, Math.PI * 2);
                ctx.fill();
                ctx.fillStyle = Colours.palette.m3primaryContainer;
                ctx.beginPath();
                ctx.arc(cx, cy, r * 0.03, 0, Math.PI * 2);
                ctx.fill();
            }

            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()

            Connections {
                function onNowChanged(): void {
                    // Without the second dot only the minute moves anything
                    if (cookie.seconds || clock.now.getSeconds() === 0)
                        cookie.requestPaint();
                }

                target: clock
            }

            // A new colour scheme changes the palette in place, so follow one of its colours
            Connections {
                function onM3primaryContainerChanged(): void {
                    cookie.requestPaint();
                }

                target: Colours.palette
            }
        }
    }

    // Each zone's offset from UTC, asked of `date` for the world clock, and again every hour so a
    // change to or from summer time is picked up
    Process {
        id: zones

        running: clock.style === "world"
        command: ["sh", "-c", "for z; do TZ=\":$z\" date +%z; done", "sh", ...clock.cities.map(c => c.zone)]
        stdout: StdioCollector {
            onStreamFinished: {
                clock.zoneOffsets = text.trim().split("\n").map(line => {
                    const m = line.trim().match(/^([+-])(\d\d)(\d\d)$/);
                    if (!m)
                        return undefined;
                    return (m[1] === "-" ? -1 : 1) * (Number(m[2]) * 60 + Number(m[3]));
                });
            }
        }
    }

    Timer {
        interval: 3600000
        repeat: true
        running: clock.style === "world"
        onTriggered: zones.running = true
    }

component FigureBlock: StyledRect {
    id: block

    property string text
    property color colour
    property color onColour
    property int weight
    property string badge

    Layout.fillWidth: true
    Layout.fillHeight: true
    radius: Tokens.rounding.extraLarge
    color: block.colour

    StyledText {
        anchors.fill: parent
        anchors.topMargin: -Tokens.padding.extraSmall
        anchors.bottomMargin: -Tokens.padding.extraSmall
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        fontSizeMode: Text.Fit
        minimumPointSize: Tokens.font.label.small.pointSize
        text: block.text
        color: block.onColour
        font: Tokens.font.clock.size(300).weight(block.weight).build()
    }

    StyledText {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: Tokens.padding.small
        visible: block.badge !== ""
        text: block.badge
        color: block.onColour
        opacity: 0.7
        font: Tokens.font.label.builders.small.weight(Font.Bold).build()
    }
}
}
