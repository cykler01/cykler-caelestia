pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.modules.background

// --- Contributions: GitHub activity as squares or a line graph over the last week or month, the whole year
// as a calendar, or the streak it adds up to ---
WidgetCard {
    id: gh

    readonly property real gap: 6

    readonly property string user: (GlobalConfig.background.desktopWidgets.githubUser ?? "").trim()
    readonly property bool userValid: WidgetData.validGithubUser(gh.user)

    readonly property bool monthView: gh.variant.startsWith("month")
    readonly property bool lineView: gh.variant.endsWith("line")
    // The stats variants show the stars and followers under the calendar, on top of the days themselves
    readonly property bool stats: gh.variant.endsWith("-stats")
    // The two variants drawn from the whole year rather than the last thirty days
    readonly property bool yearView: gh.variant === "year"
    readonly property bool streakView: gh.variant === "streak"
    readonly property bool longView: gh.yearView || gh.streakView

    // The last 30 days, oldest first, so today is the last square. The week is the tail of it, which is what
    // lets the variant be switched without asking GitHub again. The days are held in services/WidgetData.qml
    // rather than here: the card is unloaded whenever windows hide the desktop, and days kept in the card meant
    // going back to GitHub every time you returned to a bare workspace
    readonly property var days: WidgetData.daysFor(gh.user)
    // Whatever went wrong, shown on the card: a failure should never be a blank space
    readonly property string error: WidgetData.errorFor(gh.user)
    // { stars, followers } once they have been fetched, null until then
    readonly property var profile: WidgetData.statsFor(gh.user)
    // Index of the square being hovered, -1 for none
    property int hovered: -1

    readonly property var shown: gh.monthView ? gh.days : gh.days.slice(-7)

    // What the card says instead of the squares
    readonly property string message: {
        if (gh.user === "")
            return Tr.tr("Set a GitHub name in Settings");
        if (!gh.userValid)
            return Tr.tr("That is not a valid GitHub name");
        if (gh.longView) {
            if (gh.year.length > 0)
                return "";
            return yearData.error !== "" ? yearData.error : Tr.tr("Loading...");
        }
        if (gh.days.length > 0)
            return "";
        return gh.error !== "" ? gh.error : Tr.tr("Loading...");
    }

    // The year, oldest day first and today last
    readonly property var year: gh.longView ? yearData.days : []

    // The year laid out as GitHub draws it: a column per week, the first day of the week at the top, and
    // the current week cut off at today. Null for the days before the year began in the first column
    readonly property var weeks: {
        if (!gh.yearView || gh.year.length === 0)
            return [];

        const first = Qt.locale().firstDayOfWeek % 7;
        const today = new Date();
        today.setHours(0, 0, 0, 0);
        const back = (today.getDay() - first + 7) % 7;
        const start = new Date(today.getFullYear(), today.getMonth(), today.getDate() - back - 52 * 7);
        const byDate = {};
        for (const day of gh.year)
            byDate[day.date] = day;

        const out = [];
        for (let c = 0; c < 53; c++) {
            const column = [];
            for (let r = 0; r < 7; r++) {
                const date = new Date(start.getFullYear(), start.getMonth(), start.getDate() + c * 7 + r);
                if (date > today)
                    break;
                const key = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}-${String(date.getDate()).padStart(2, "0")}`;
                column.push(byDate[key] ?? {
                    date: key,
                    count: 0,
                    level: 0
                });
            }
            out.push(column);
        }
        return out;
    }

    // The day under the pointer on the year calendar, or null
    property var yearHovered: null

    // { current, longest, total } over the fetched year. A day with nothing yet doesn't break the
    // streak until it is over, so the count carries on from yesterday until midnight
    readonly property var streaks: {
        const days = gh.year;
        const out = {
            current: 0,
            longest: 0,
            total: 0
        };
        if (days.length === 0)
            return out;

        let run = 0;
        for (const day of days) {
            run = day.count > 0 ? run + 1 : 0;
            out.longest = Math.max(out.longest, run);
        }

        let i = days.length - 1;
        if (days[i].count === 0)
            i--;
        while (i >= 0 && days[i].count > 0) {
            out.current++;
            i--;
        }

        const thisYear = String(new Date().getFullYear());
        out.total = days.filter(d => d.date.startsWith(thisYear)).reduce((sum, d) => sum + d.count, 0);
        return out;
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

    // A count as it is usually written: 1234 reads as 1.2k, and an em dash until there is one to show
    function compact(count: var): string {
        if (count === undefined || count === null)
            return "—";
        if (count >= 1000000)
            return (count / 1000000).toFixed(1).replace(/\.0$/, "") + "M";
        if (count >= 1000)
            return (count / 1000).toFixed(1).replace(/\.0$/, "") + "k";
        return String(count);
    }

    // The year needs every line of height it can get for its squares, so it draws its own mark in the
    // line under them instead of the card's title
    title: gh.yearView ? "" : Tr.tr("GitHub")
    icon: gh.streakView ? "local_fire_department" : gh.monthView || gh.yearView ? "calendar_view_month" : "calendar_view_week"

    // The cache answers from what it already has, so a card being rebuilt after the desktop was hidden draws
    // its squares on the first frame instead of waiting for curl; only an expired calendar is fetched again,
    // and that lands behind the squares that are already there
    Component.onCompleted: {
        WidgetData.requestGithub(gh.user, false);
        if (gh.stats)
            WidgetData.requestGithubStats(gh.user, false);
    }
    onUserChanged: {
        WidgetData.requestGithub(gh.user, false);
        if (gh.stats)
            WidgetData.requestGithubStats(gh.user, false);
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
        visible: gh.days.length > 0 && !gh.monthView && !gh.lineView && !gh.longView

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

    // The card's last line: the commit total (or the day under the pointer), and in the stats variants the
    // profile counts on the same line in front of it rather than on a row of their own, which leaves that
    // line of height to the calendar
    RowLayout {
        Layout.fillWidth: true
        visible: gh.days.length > 0 && !gh.longView
        spacing: Tokens.spacing.medium

        Stat {
            visible: gh.stats

            icon: "star"
            value: gh.compact(gh.profile?.stars)
        }

        Stat {
            visible: gh.stats

            icon: "group"
            value: gh.compact(gh.profile?.followers)
        }

        StyledText {
            // The total, or the day under the pointer while one is hovered
            readonly property int total: gh.shown.reduce((sum, day) => sum + day.count, 0)

            Layout.fillWidth: true
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
            text: gh.hoveredDay ? gh.hoveredDay.date + " · " + (gh.hoveredDay.count === 1 ? Tr.tr("1 commit") : Tr.tr("%1 commits").arg(gh.hoveredDay.count)) : gh.monthView ? Tr.tr("%1 in 30 days").arg(total) : Tr.tr("%1 this week").arg(total)
            color: gh.hoveredDay ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant
            font: Tokens.font.label.small
        }
    }

    // The day turns over at midnight, so the days are fetched again rather than left showing the month the
    // calendar was first read in
    Timer {
        interval: 1800000
        repeat: true
        running: true
        onTriggered: {
            if (gh.longView)
                yearData.refresh(true);
            WidgetData.requestGithub(gh.user, true);
            if (gh.stats)
                WidgetData.requestGithubStats(gh.user, true);
        }
    }

    ContributionsYear {
        id: yearData

        user: gh.longView ? gh.user : ""
    }

    // Year: every day of the last year as a week-by-day calendar, with the months marked along the top.
    // Squares are sized to whichever of the width or the height runs out first, and the grid is centred in
    // what is left over
    Item {
        id: yearGrid

        readonly property int cols: 53
        readonly property real labelHeight: monthMetrics.height + Tokens.spacing.extraSmall
        readonly property real pitch: Math.max(4, Math.min(width / yearGrid.cols, (height - yearGrid.labelHeight) / 7))
        readonly property real cell: yearGrid.pitch * 0.78
        readonly property real gridLeft: (width - yearGrid.cols * yearGrid.pitch) / 2
        readonly property real gridTop: yearGrid.labelHeight + Math.max(0, (height - yearGrid.labelHeight - 7 * yearGrid.pitch) / 2)

        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 60
        visible: gh.yearView && gh.weeks.length > 0

        FontMetrics {
            id: monthMetrics

            font: Tokens.font.label.small
        }

        // A month's name over the first week that starts in it. One that would run into the next is left
        // out, which is only ever the partial month at the very start of the year
        Repeater {
            model: gh.weeks

            StyledText {
                required property var modelData
                required property int index

                readonly property var first: modelData.length > 0 ? new Date(`${modelData[0].date}T00:00:00`) : null
                readonly property var previous: index > 0 && gh.weeks[index - 1].length > 0 ? new Date(`${gh.weeks[index - 1][0].date}T00:00:00`) : null

                x: yearGrid.gridLeft + index * yearGrid.pitch
                y: Math.max(0, yearGrid.gridTop - yearGrid.labelHeight)
                visible: first !== null && (previous === null ? first.getDate() <= 7 : first.getMonth() !== previous.getMonth()) && index < yearGrid.cols - 2
                text: first ? Qt.locale().monthName(first.getMonth(), Locale.ShortFormat) : ""
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.small
            }
        }

        Repeater {
            model: gh.weeks

            Repeater {
                id: week

                required property var modelData
                required property int index

                model: week.modelData

                StyledRect {
                    required property var modelData
                    required property int index

                    readonly property bool today: week.index === gh.weeks.length - 1 && index === week.modelData.length - 1

                    x: yearGrid.gridLeft + week.index * yearGrid.pitch
                    y: yearGrid.gridTop + index * yearGrid.pitch
                    width: yearGrid.cell
                    height: yearGrid.cell
                    radius: Math.min(Tokens.rounding.small, yearGrid.cell / 3)
                    color: gh.levelColour(modelData.level)
                    border.width: today || gh.yearHovered === modelData ? 1 : 0
                    border.color: Colours.palette.m3primary
                }
            }
        }

        // One handler over the whole calendar rather than one per square, of which there are some 370
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton

            onPositionChanged: mouse => {
                const col = Math.floor((mouse.x - yearGrid.gridLeft) / yearGrid.pitch);
                const row = Math.floor((mouse.y - yearGrid.gridTop) / yearGrid.pitch);
                const column = col >= 0 && col < gh.weeks.length ? gh.weeks[col] : null;
                gh.yearHovered = column && row >= 0 && row < column.length ? column[row] : null;
            }
            onExited: gh.yearHovered = null
        }
    }

    // Under the year: the scale from none to most on the left, and the year's total, or the day being
    // pointed at, on the right
    RowLayout {
        Layout.fillWidth: true
        visible: gh.yearView && gh.weeks.length > 0
        spacing: Tokens.spacing.small

        MaterialIcon {
            text: "calendar_view_month"
            color: Colours.palette.m3primary
            fontStyle: Tokens.font.icon.small
        }

        StyledText {
            Layout.rightMargin: Tokens.spacing.medium
            text: gh.user
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.label.builders.small.weight(Font.DemiBold).build()
        }

        StyledText {
            text: Tr.tr("Less")
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
        }

        Repeater {
            model: 5

            StyledRect {
                required property int index

                implicitWidth: yearGrid.cell
                implicitHeight: yearGrid.cell
                radius: Math.min(Tokens.rounding.small, yearGrid.cell / 3)
                color: gh.levelColour(index)
            }
        }

        StyledText {
            text: Tr.tr("More")
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
        }

        StyledText {
            readonly property int total: gh.year.reduce((sum, day) => sum + day.count, 0)

            Layout.fillWidth: true
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
            text: gh.yearHovered ? Qt.formatDate(new Date(`${gh.yearHovered.date}T00:00:00`), "ddd d MMM yyyy") + " · " + (gh.yearHovered.count === 1 ? Tr.tr("1 contribution") : Tr.tr("%1 contributions").arg(gh.yearHovered.count)) : Tr.tr("%1 in the past year").arg(total.toLocaleString(Qt.locale(), "f", 0))
            color: gh.yearHovered ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant
            font: Tokens.font.label.small
        }
    }

    // Streak: how many days running there has been something, big, with the record and the year's total
    // beside it and the last week under those to show where the run stands
    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: gh.streakView && gh.year.length > 0
        spacing: Tokens.spacing.small

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Tokens.spacing.medium

            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: 0

                RowLayout {
                    spacing: Tokens.spacing.extraSmall

                    StyledText {
                        text: gh.streaks.current.toLocaleString(Qt.locale(), "f", 0)
                        color: gh.streaks.current > 0 ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.headline.builders.medium.weight(Font.Bold).build()
                    }

                    // Lit while the run is alive, an outline once it has gone out
                    MaterialIcon {
                        Layout.alignment: Qt.AlignVCenter
                        text: "local_fire_department"
                        fill: gh.streaks.current > 0 ? 1 : 0
                        color: gh.streaks.current > 0 ? Colours.palette.m3tertiary : Colours.palette.m3outline
                        fontStyle: Tokens.font.icon.large
                    }
                }

                StyledText {
                    Layout.topMargin: -Tokens.spacing.extraSmall
                    text: Tr.tr("day streak")
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.medium
                }
            }

            Item {
                Layout.fillWidth: true
            }

            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: Tokens.spacing.small

                StreakStat {
                    label: Tr.tr("Longest")
                    value: gh.streaks.longest === 1 ? Tr.tr("1 day") : Tr.tr("%1 days").arg(gh.streaks.longest)
                }

                StreakStat {
                    label: Tr.tr("This year")
                    value: gh.streaks.total.toLocaleString(Qt.locale(), "f", 0)
                }

                // The last seven days under the figures, today on the right and outlined
                RowLayout {
                    Layout.fillWidth: true
                    spacing: gh.gap

                    Repeater {
                        model: gh.year.slice(-7)

                        StyledRect {
                            required property var modelData
                            required property int index

                            Layout.fillWidth: true
                            // Held at its height when the card is short, rather than being the first thing squeezed out
                            Layout.minimumHeight: 8
                            Layout.preferredHeight: 8
                            radius: Tokens.rounding.full
                            color: gh.levelColour(modelData.level)
                            border.width: index === 6 ? 1 : 0
                            border.color: Colours.palette.m3primary
                        }
                    }
                }
            }
        }
    }

    component StreakStat: RowLayout {
        id: streakStat

        property string label
        property string value

        Layout.alignment: Qt.AlignRight
        spacing: Tokens.spacing.small

        StyledText {
            Layout.alignment: Qt.AlignBaseline
            text: streakStat.label
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
        }

        StyledText {
            Layout.alignment: Qt.AlignBaseline
            text: streakStat.value
            color: Colours.palette.m3onSurface
            font: Tokens.font.title.small
        }
    }

    // A profile count on the last line. The icon carries the meaning, so the word label is left out: the
    // total on the same line needs the room more, and two words of label pushed the line over the card
    component Stat: RowLayout {
        id: stat

        property string icon
        property string value

        Layout.alignment: Qt.AlignVCenter
        spacing: Tokens.spacing.extraSmall

        MaterialIcon {
            text: stat.icon
            color: Colours.palette.m3primary
            fontStyle: Tokens.font.icon.small
        }

        StyledText {
            text: stat.value
            color: Colours.palette.m3onSurface
            font: Tokens.font.label.medium
        }
    }
}
