pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.modules.background

// --- Contributions: GitHub activity as squares or a line graph, over the last week or month ---
WidgetCard {
    id: gh

    readonly property real gap: 6

    readonly property string user: (GlobalConfig.background.desktopWidgets.githubUser ?? "").trim()
    // Letters, digits and hyphens only: the name is part of a URL, so nothing else gets through
    readonly property bool userValid: /^[A-Za-z0-9-]+$/.test(gh.user)

    readonly property bool monthView: gh.variant.startsWith("month")
    readonly property bool lineView: gh.variant.endsWith("line")

    // The last 30 days, oldest first, so today is the last square. The week is the tail of it, which is
    // what lets the variant be switched without asking GitHub again
    property var days: []
    property int total: 0
    // Index of the square being hovered, -1 for none
    property int hovered: -1
    // Whatever went wrong, shown on the card: a failure should never be a blank space
    property string error

    readonly property var shown: gh.monthView ? gh.days : gh.days.slice(-7)

    // What the card says instead of the squares
    readonly property string message: {
        if (gh.user === "")
            return Tr.tr("Set a GitHub name in Settings");
        if (!gh.userValid)
            return Tr.tr("That is not a valid GitHub name");
        if (gh.days.length > 0)
            return "";
        return gh.error !== "" ? gh.error : Tr.tr("Loading...");
    }

    // The square under the pointer as a readable day, or null
    readonly property var hoveredDay: {
        const day = gh.hovered >= 0 && gh.hovered < gh.shown.length ? gh.shown[gh.hovered] : null;
        if (!day)
            return null;

        return {
            date: Qt.formatDate(new Date(`${day.date}T00:00:00`), "d MMM"),
            count: day.count
        };
    }

    // The busiest day's count, so the line graph uses the card's height rather than a fixed scale
    readonly property int peak: gh.shown.reduce((n, d) => Math.max(n, d.count), 0)

    function levelColour(level: int): color {
        if (level <= 0)
            return Qt.alpha(Colours.palette.m3outlineVariant, 0.35);

        return Qt.alpha(Colours.palette.m3primary, 0.3 + 0.175 * Math.min(4, level));
    }

    // The days up to and including today, oldest first. Worked out when the data arrives rather than once at
    // build time, so the card doesn't keep showing the month it was created in
    function monthDates(): var {
        const now = new Date();

        return Array.from({
            length: 30
        }, (_, i) => {
            const day = new Date(now.getFullYear(), now.getMonth(), now.getDate() - (29 - i));
            const month = String(day.getMonth() + 1).padStart(2, "0");
            const date = String(day.getDate()).padStart(2, "0");
            return `${day.getFullYear()}-${month}-${date}`;
        });
    }

    // Started by hand rather than with a `running` binding, so a name change re-fetches instead of
    // leaving the previous name's days on the card
    function reload(): void {
        gh.days = [];
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

        gh.days = monthDates().map(date => ({
            date: date,
            count: byDate[date]?.count ?? 0,
            level: byDate[date]?.level ?? 0
        }));
        gh.total = gh.days.slice(-(gh.monthView ? 30 : 7)).reduce((sum, day) => sum + day.count, 0);
        gh.error = "";
    }

    title: Tr.tr("GitHub")
    icon: gh.monthView ? "calendar_view_month" : "calendar_view_week"

    Component.onCompleted: gh.reload()
    onUserChanged: gh.reload()

    LoggingCategory {
        id: lc

        name: "caelestia.qml.modules.background.widgets.contributions"
        defaultLogLevel: LoggingCategory.Warning
    }

    Process {
        id: fetch

        running: false
        // A public mirror of the calendar, so there is no token and nothing to set up but the name
        command: ["sh", "-c", `curl -fsSL --max-time 20 "https://github-contributions-api.jogruber.de/v4/${gh.user}?y=last"`]

        // curl's own complaint, so a failed fetch says why on the card instead of going quiet
        stderr: StdioCollector {
            onStreamFinished: {
                const complaint = text.trim();
                if (complaint !== "" && gh.days.length === 0)
                    gh.error = complaint;
            }
        }

        stdout: StdioCollector {
            onStreamFinished: gh.parse(text)
        }
    }

    // The day turns over at midnight, so the days are read again rather than left on the
    // month the card was built in
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

    // The week: seven squares sharing the width, each as tall as it is wide
    Item {
        readonly property real cell: Math.max(2, (width - 6 * gh.gap) / 7)

        Layout.fillWidth: true
        implicitHeight: cell
        visible: gh.days.length > 0 && !gh.monthView && !gh.lineView

        Repeater {
            model: gh.shown

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

    // The month: thirty squares, ten to a row, so each one stays square rather than becoming a sliver
    GridLayout {
        Layout.fillWidth: true
        visible: gh.days.length > 0 && gh.monthView && !gh.lineView
        columns: 10
        rowSpacing: gh.gap
        columnSpacing: gh.gap

        Repeater {
            model: gh.shown

            StyledRect {
                required property var modelData
                required property int index

                Layout.fillWidth: true
                Layout.preferredHeight: width
                implicitHeight: 10
                border.width: gh.hovered === index ? 1 : 0
                border.color: Colours.palette.m3primary
                radius: Math.min(Tokens.rounding.medium, 4)
                color: gh.levelColour(modelData.level)

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

    // The line graph: the same days, against the busiest one on the card
    Canvas {
        id: ghLine

        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredHeight: 40
        visible: gh.days.length > 0 && gh.lineView

        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            if (gh.shown.length < 2 || gh.peak <= 0)
                return;

            const step = width / (gh.shown.length - 1);
            const top = 2;
            const bottom = height - 12;

            ctx.beginPath();
            ctx.lineWidth = 2;
            ctx.lineJoin = "round";
            ctx.lineCap = "round";
            ctx.strokeStyle = Colours.palette.m3primary;
            gh.shown.forEach((day, i) => {
                const x = i * step;
                const y = bottom - (day.count / gh.peak) * (bottom - top);
                if (i === 0)
                    ctx.moveTo(x, y);
                else
                    ctx.lineTo(x, y);
            });
            ctx.stroke();

            // A dot on today, so the end of the line is obvious
            const last = gh.shown[gh.shown.length - 1];
            ctx.fillStyle = Colours.palette.m3primary;
            ctx.beginPath();
            ctx.arc(width, bottom - (last.count / gh.peak) * (bottom - top), 3, 0, Math.PI * 2);
            ctx.fill();
        }

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onVisibleChanged: {
            if (visible)
                requestPaint();
        }

        Connections {
            function onShownChanged(): void {
                ghLine.requestPaint();
            }
            function onPeakChanged(): void {
                ghLine.requestPaint();
            }

            target: gh
        }
    }

    StyledText {
        // The total, or the day under the pointer while one is hovered
        readonly property int total: gh.shown.reduce((sum, day) => sum + day.count, 0)

        Layout.fillWidth: true
        visible: gh.days.length > 0
        horizontalAlignment: Text.AlignRight
        text: gh.hoveredDay ? gh.hoveredDay.date + " · " + (gh.hoveredDay.count === 1 ? Tr.tr("1 commit") : Tr.tr("%1 commits").arg(gh.hoveredDay.count)) : gh.monthView ? Tr.tr("%1 in 30 days").arg(total) : Tr.tr("%1 this week").arg(total)
        color: gh.hoveredDay ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant
        font: Tokens.font.label.small
    }
}
