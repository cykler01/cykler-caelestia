pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services

// Where you are in the day: what you are in now and for how long, or what is next, over a timeline
// of today's events with the time so far filled in. Every kind of event is on it - the routine in
// grey, special ones blue, birthdays and holidays green (services/CalendarEvents.qml) - since
// the routine is exactly what the shape of a day is made of.
//
// Shared by the day progress widgets on the desktop, the dashboard and the lock screen. It sizes
// itself to its content; `compact` drops the hour labels and the all-day chips for a slimmer card.
ColumnLayout {
    id: root

    property bool compact: false
    // Clicking an event block opens it in GNOME Calendar. Off on the lock screen
    property bool interactive: true

    readonly property date now: Time.date
    readonly property double nowMs: now.getTime()
    readonly property date midnight: new Date(now.getFullYear(), now.getMonth(), now.getDate())

    readonly property var allDay: CalendarEvents.todayAll.filter(e => e.allDay || CalendarEvents.dayCount(e) > 1 && e.start < root.midnight && e.end.getTime() >= root.midnight.getTime() + 86400000)
    // Today's events with a time to them, by start. todayAll leads with the multi-day ones, the
    // way the lists stack them; `next` and the lanes below need them in the order they happen
    readonly property var timed: CalendarEvents.todayAll.filter(e => !root.allDay.includes(e)).sort((a, b) => a.start - b.start || a.end - b.end)

    // The stretch of the day the timeline covers: eight till eight, pushed out to take in an
    // earlier start or a later finish, whole hours either end
    readonly property double dayStart: {
        let start = new Date(root.midnight).setHours(8);
        for (const e of root.timed)
            start = Math.min(start, Math.max(e.start.getTime(), root.midnight.getTime()));
        const d = new Date(start);
        d.setMinutes(0, 0, 0);
        return d.getTime();
    }
    readonly property double dayEnd: {
        const endOfDay = root.midnight.getTime() + 86400000;
        let end = new Date(root.midnight).setHours(20);
        for (const e of root.timed)
            end = Math.max(end, Math.min(e.end.getTime(), endOfDay));
        const d = new Date(end);
        if (d.getMinutes() > 0 || d.getSeconds() > 0)
            d.setHours(d.getHours() + 1, 0, 0, 0);
        return Math.min(d.getTime(), endOfDay);
    }
    readonly property double span: Math.max(1, dayEnd - dayStart)
    readonly property real progress: Math.max(0, Math.min(1, (nowMs - dayStart) / span))

    // What is on now, the one that matters most if several overlap: special over rare over the
    // routine, then whichever started last
    readonly property var current: {
        const rank = {
            special: 0,
            rare: 1,
            regular: 2
        };
        const on = root.timed.filter(e => e.start.getTime() <= root.nowMs && root.nowMs < e.end.getTime());
        on.sort((a, b) => rank[a.kind] - rank[b.kind] || b.start - a.start);
        return on[0] ?? null;
    }
    readonly property var next: root.timed.find(e => e.start.getTime() > root.nowMs) ?? null
    readonly property int remaining: root.timed.filter(e => e.start.getTime() > root.nowMs).length

    // Events as blocks on the timeline, each in a lane so overlapping ones sit one above the other
    readonly property var blocks: {
        const ends = [];
        const out = [];
        for (const e of root.timed) {
            const s = Math.max(e.start.getTime(), root.dayStart);
            const f = Math.min(e.end.getTime(), root.dayEnd);
            if (f <= s && e.end.getTime() > e.start.getTime())
                continue;
            let lane = ends.findIndex(t => t <= s);
            if (lane < 0) {
                lane = ends.length;
                ends.push(f);
            } else {
                ends[lane] = f;
            }
            out.push({
                event: e,
                from: (s - root.dayStart) / root.span,
                to: (Math.max(f, s) - root.dayStart) / root.span,
                lane: Math.min(lane, 2)
            });
        }
        return out;
    }
    readonly property int lanes: Math.min(3, root.blocks.reduce((n, b) => Math.max(n, b.lane + 1), 1))

    // Hour marks under the track, every one, two or three hours so there are no more than seven
    readonly property var hours: {
        const count = root.span / 3600000;
        const step = count <= 6 ? 1 : count <= 12 ? 2 : 3;
        const out = [];
        for (let t = root.dayStart; t <= root.dayEnd; t += step * 3600000)
            out.push(t);
        return out;
    }

    function endLabel(ev: var): string {
        if (CalendarEvents.sameDay(ev.end, root.now) || ev.end.getTime() === root.midnight.getTime() + 86400000)
            return CalendarEvents.formatTime(ev.end);
        return `${CalendarEvents.dayLabel(ev.end)} ${CalendarEvents.formatTime(ev.end)}`;
    }

    spacing: root.compact ? Tokens.spacing.small : Tokens.spacing.medium

    // Status: what is happening and how long for
    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.medium

        StyledRect {
            implicitWidth: root.compact ? 28 : 36
            implicitHeight: implicitWidth
            radius: Tokens.rounding.full
            color: Qt.alpha(root.current ? CalendarEvents.colourOf(root.current) : Colours.palette.m3primary, 0.2)

            MaterialIcon {
                anchors.centerIn: parent
                text: {
                    if (root.current)
                        return root.current.kind === "regular" ? "schedule" : root.current.kind === "rare" ? "celebration" : "star";
                    if (root.next)
                        return "self_improvement";
                    return root.timed.length > 0 ? "bedtime" : "wb_sunny";
                }
                color: root.current ? CalendarEvents.colourOf(root.current) : Colours.palette.m3primary
                fontStyle: root.compact ? Tokens.font.icon.small : Tokens.font.icon.medium
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                elide: Text.ElideRight
                color: Colours.palette.m3onSurface
                font: root.compact ? Tokens.font.body.builders.medium.weight(Font.DemiBold).build() : Tokens.font.title.builders.medium.weight(Font.DemiBold).build()
                text: {
                    if (root.current)
                        return CalendarEvents.titleOf(root.current);
                    if (root.next)
                        return Tr.tr("Free");
                    if (root.timed.length > 0)
                        return Tr.tr("Done for the day");
                    return Tr.tr("Nothing scheduled");
                }
            }

            StyledText {
                Layout.fillWidth: true
                elide: Text.ElideRight
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.medium
                text: {
                    if (root.current) {
                        const left = CalendarEvents.durationLabel(root.current.end.getTime() - root.nowMs);
                        return Tr.tr("Until %1 · %2 left").arg(root.endLabel(root.current)).arg(left);
                    }
                    if (root.next) {
                        const until = CalendarEvents.durationLabel(root.next.start.getTime() - root.nowMs);
                        return Tr.tr("Next: %1 at %2 · in %3").arg(CalendarEvents.titleOf(root.next)).arg(CalendarEvents.formatTime(root.next.start)).arg(until);
                    }
                    if (root.timed.length > 0)
                        return Tr.trN("%n event today", "%n events today", root.timed.length);
                    return Tr.tr("The whole day is yours");
                }
            }
        }

        // How far through the day, and what is left of it
        ColumnLayout {
            visible: root.timed.length > 0
            spacing: 0

            StyledText {
                Layout.alignment: Qt.AlignRight
                text: `${Math.round(root.progress * 100)}%`
                color: Colours.palette.m3primary
                font: root.compact ? Tokens.font.label.builders.large.weight(Font.Bold).build() : Tokens.font.title.builders.small.weight(Font.Bold).build()
            }

            StyledText {
                Layout.alignment: Qt.AlignRight
                visible: !root.compact
                text: root.remaining > 0 ? Tr.trN("%n to go", "%n to go", root.remaining) : Tr.tr("all done")
                color: Colours.palette.m3outline
                font: Tokens.font.label.small
            }
        }
    }

    // All-day things today - a birthday, a deadline - as chips over the timeline
    Flow {
        Layout.fillWidth: true
        visible: !root.compact && root.allDay.length > 0
        spacing: Tokens.spacing.small

        Repeater {
            model: root.allDay.slice(0, 4)

            StyledRect {
                id: chip

                required property var modelData

                implicitWidth: Math.min(chipRow.implicitWidth + Tokens.padding.medium * 2, root.width)
                implicitHeight: chipRow.implicitHeight + Tokens.padding.extraSmall * 2
                radius: Tokens.rounding.full
                color: Qt.alpha(CalendarEvents.colourOf(chip.modelData), 0.18)

                RowLayout {
                    id: chipRow

                    anchors.fill: parent
                    anchors.leftMargin: Tokens.padding.medium
                    anchors.rightMargin: Tokens.padding.medium
                    spacing: Tokens.spacing.extraSmall

                    MaterialIcon {
                        text: chip.modelData.kind === "rare" ? "cake" : chip.modelData.kind === "regular" ? "event_repeat" : "star"
                        color: CalendarEvents.colourOf(chip.modelData)
                        fontStyle: Tokens.font.icon.small
                    }

                    StyledText {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        text: CalendarEvents.titleOf(chip.modelData)
                        elide: Text.ElideRight
                        color: Colours.palette.m3onSurface
                        font: Tokens.font.label.medium
                    }
                }

                StateLayer {
                    visible: root.interactive
                    radius: chip.radius
                    onClicked: CalendarEvents.openEvent(chip.modelData)
                }
            }
        }
    }

    // The timeline
    Item {
        id: timeline

        readonly property real trackHeight: root.compact ? 10 : 30
        readonly property real labelHeight: root.compact ? 0 : hourMetrics.height + Tokens.spacing.extraSmall

        Layout.fillWidth: true
        implicitHeight: trackHeight + labelHeight + 4

        TextMetrics {
            id: hourMetrics

            font: Tokens.font.label.small
            text: "00"
        }

        StyledRect {
            id: track

            y: 2
            width: parent.width
            height: timeline.trackHeight
            radius: root.compact ? height / 2 : Tokens.rounding.small
            color: Colours.palette.m3surfaceContainerHighest
            clip: true

            // The part of the day already gone
            StyledRect {
                width: track.width * root.progress
                height: track.height
                color: Qt.alpha(Colours.palette.m3primary, 0.18)
            }

            Repeater {
                model: root.blocks

                StyledRect {
                    id: block

                    required property var modelData

                    readonly property bool isCurrent: block.modelData.event === root.current
                    readonly property real laneHeight: (track.height - (root.lanes - 1)) / root.lanes

                    x: track.width * block.modelData.from
                    y: block.modelData.lane * (block.laneHeight + 1)
                    width: Math.max(3, track.width * (block.modelData.to - block.modelData.from) - 1)
                    height: block.laneHeight
                    radius: root.compact ? 0 : 3
                    color: CalendarEvents.colourOf(block.modelData.event)
                    opacity: CalendarEvents.isOver(block.modelData.event) ? 0.45 : 1
                    border.width: block.isCurrent && !root.compact ? 2 : 0
                    border.color: Colours.palette.m3onSurface

                    StyledText {
                        anchors.fill: parent
                        anchors.leftMargin: 4
                        anchors.rightMargin: 2
                        visible: !root.compact && block.width > 40 && root.lanes === 1
                        verticalAlignment: Text.AlignVCenter
                        text: CalendarEvents.titleOf(block.modelData.event)
                        elide: Text.ElideRight
                        color: Colours.on(block.color)
                        font: Tokens.font.label.small
                    }

                    StateLayer {
                        visible: root.interactive && !root.compact
                        radius: block.radius
                        onClicked: CalendarEvents.openEvent(block.modelData.event)
                    }
                }
            }
        }

        // Now, a line across the track with a dot on top
        Item {
            visible: root.nowMs >= root.dayStart && root.nowMs <= root.dayEnd
            x: track.width * root.progress - width / 2
            width: 8
            height: timeline.trackHeight + 4

            StyledRect {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 2
                height: parent.height
                radius: 1
                color: Colours.palette.m3primary
            }

            StyledRect {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: !root.compact
                width: 8
                height: 8
                radius: 4
                color: Colours.palette.m3primary
            }
        }

        Repeater {
            model: root.compact ? [] : root.hours

            StyledText {
                required property var modelData
                required property int index

                readonly property real at: track.width * (modelData - root.dayStart) / root.span

                x: Math.max(0, Math.min(track.width - width, at - width / 2))
                y: track.y + track.height + Tokens.spacing.extraSmall
                text: Qt.formatTime(new Date(modelData), Units.twelveHourClock ? "h AP" : "H")
                color: Colours.palette.m3outline
                font: Tokens.font.label.small
            }
        }
    }
}
