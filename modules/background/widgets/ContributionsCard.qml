pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
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
    readonly property bool userValid: WidgetData.validGithubUser(gh.user)

    readonly property bool monthView: gh.variant.startsWith("month")
    readonly property bool lineView: gh.variant.endsWith("line")
    // The stats variants show the stars and followers under the calendar, on top of the days themselves
    readonly property bool stats: gh.variant.endsWith("-stats")

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

    title: Tr.tr("GitHub")
    icon: gh.monthView ? "calendar_view_month" : "calendar_view_week"

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

    // The card's last line: the commit total (or the day under the pointer), and in the stats variants the
    // profile counts on the same line in front of it rather than on a row of their own, which leaves that
    // line of height to the calendar
    RowLayout {
        Layout.fillWidth: true
        visible: gh.days.length > 0
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
            WidgetData.requestGithub(gh.user, true);
            if (gh.stats)
                WidgetData.requestGithubStats(gh.user, true);
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
