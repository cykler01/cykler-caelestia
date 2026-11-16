pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

// Settings for the progress card's milestones. Kept separate from the stocks page so each feed can
// grow without turning either into a mixed list of unrelated controls.
PageBase {
    id: root

    readonly property var widgetsConfig: GlobalConfig.background.desktopWidgets

    // 0 day, 1 week, 2 daily, 3 weekly, 4 date, 5 yearly, 6 interval, matching Milestones.modes
    property int milestoneMode: 4
    property string milestoneLabel: ""
    property string milestoneStart: ""
    property string milestoneEnd: ""
    property string milestoneError: ""

    readonly property bool dayMode: root.milestoneMode === 0
    readonly property bool weekMode: root.milestoneMode === 1
    readonly property bool dailyMode: root.milestoneMode === 2
    readonly property bool weeklyMode: root.milestoneMode === 3
    readonly property bool dateMode: root.milestoneMode === 4
    readonly property bool yearlyMode: root.milestoneMode === 5
    readonly property bool intervalMode: root.milestoneMode === 6

    readonly property list<MenuItem> milestoneModes: [
        MenuItem {
            text: Tr.tr("End of day")
        },
        MenuItem {
            text: Tr.tr("End of week")
        },
        MenuItem {
            text: Tr.tr("Daily time")
        },
        MenuItem {
            text: Tr.tr("Weekly time")
        },
        MenuItem {
            text: Tr.tr("Specific date")
        },
        MenuItem {
            text: Tr.tr("Yearly date")
        },
        MenuItem {
            text: Tr.tr("Custom interval")
        }
    ]

    function addMilestone(): void {
        root.milestoneError = "";
        const mode = Milestones.modes[root.milestoneMode] ?? "date";

        if (root.widgetsConfig.progressEntries.values.length >= Milestones.maxItems) {
            root.milestoneError = Tr.tr("You can show up to %1 milestones").arg(Milestones.maxItems);
            return;
        }

        if (mode === "day") {
            if (root.milestoneStart.trim() !== "" && !Milestones.validClock(root.milestoneStart)) {
                root.milestoneError = Tr.tr("Use HH:mm");
                return;
            }
            if (root.milestoneEnd.trim() !== "" && !Milestones.validClock(root.milestoneEnd)) {
                root.milestoneError = Tr.tr("Use HH:mm");
                return;
            }
        } else if (mode === "week") {
            if (root.milestoneStart.trim() !== "" && !Milestones.validWeekly(root.milestoneStart)) {
                root.milestoneError = Tr.tr("Use a weekday such as Mon, optionally with HH:mm");
                return;
            }
            if (root.milestoneEnd.trim() !== "" && !Milestones.validWeekly(root.milestoneEnd)) {
                root.milestoneError = Tr.tr("Use a weekday such as Mon, optionally with HH:mm");
                return;
            }
        } else if (mode === "daily") {
            if (root.milestoneEnd.trim() === "") {
                root.milestoneError = Tr.tr("Give the daily time");
                return;
            }
            if (!Milestones.validDaily(root.milestoneEnd)) {
                root.milestoneError = Tr.tr("Use HH:mm");
                return;
            }
            if (root.milestoneStart.trim() !== "" && !Milestones.validDaily(root.milestoneStart)) {
                root.milestoneError = Tr.tr("Use HH:mm");
                return;
            }
        } else if (mode === "weekly") {
            if (root.milestoneEnd.trim() === "") {
                root.milestoneError = Tr.tr("Give the weekday");
                return;
            }
            if (!Milestones.validWeekly(root.milestoneEnd)) {
                root.milestoneError = Tr.tr("Use a weekday such as Fri, optionally with HH:mm");
                return;
            }
            if (root.milestoneStart.trim() !== "" && !Milestones.validWeekly(root.milestoneStart)) {
                root.milestoneError = Tr.tr("Use a weekday such as Fri, optionally with HH:mm");
                return;
            }
        } else if (mode === "date") {
            if (root.milestoneEnd.trim() === "") {
                root.milestoneError = Tr.tr("Give this milestone a date");
                return;
            }
            if (!Milestones.validDate(root.milestoneEnd, true)) {
                root.milestoneError = Tr.tr("Use YYYY-MM-DD or YYYY-MM-DD HH:mm");
                return;
            }
            if (root.milestoneStart.trim() !== "" && (!Milestones.validDate(root.milestoneStart, false) || Milestones.parseTime(root.milestoneStart, false) >= Milestones.parseTime(root.milestoneEnd, true))) {
                root.milestoneError = Tr.tr("The end must be after the start");
                return;
            }
        } else if (mode === "yearly") {
            if (root.milestoneEnd.trim() === "") {
                root.milestoneError = Tr.tr("Give this milestone a date");
                return;
            }
            if (!Milestones.validAnnual(root.milestoneEnd)) {
                root.milestoneError = Tr.tr("Use MM-DD or MM-DD HH:mm");
                return;
            }
        } else if (mode === "interval") {
            if (root.milestoneStart.trim() === "" || root.milestoneEnd.trim() === "") {
                root.milestoneError = Tr.tr("Give the interval a start and an end");
                return;
            }
            if (!Milestones.validDate(root.milestoneStart, false) || !Milestones.validDate(root.milestoneEnd, true) || Milestones.parseTime(root.milestoneStart, false) >= Milestones.parseTime(root.milestoneEnd, true)) {
                root.milestoneError = Tr.tr("Use a valid range; the end must be after the start");
                return;
            }
        }

        GlobalConfig.background.desktopWidgets.progressEntries.insert({
            label: root.milestoneLabel.trim(),
            mode: mode,
            // The yearly date has no start of its own; everything else keeps whatever was typed
            start: mode === "yearly" ? "" : root.milestoneStart.trim(),
            end: root.milestoneEnd.trim(),
            enabled: true
        });

        root.milestoneLabel = "";
        root.milestoneStart = "";
        root.milestoneEnd = "";
    }

    title: Tr.tr("Progress")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: Tr.tr("Milestones")
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.largeIncreased
            Layout.rightMargin: Tokens.padding.largeIncreased
            Layout.bottomMargin: Tokens.spacing.small
            wrapMode: Text.Wrap
            text: Tr.tr("The progress widget shows end of day and end of week automatically. Add a specific date, a yearly date, a daily or weekly time, or an interval below; each card can show up to %1. Give a repeating milestone a start and an end to mark the hours it counts - the rest of the cycle shows as completed until it begins again.").arg(Milestones.maxItems)
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
        }

        ListEditor {
            function labelFor(item: var): string {
                return Milestones.describe(item);
            }

            function toggledFor(item: var): bool {
                return item.enabled;
            }

            z: 1
            first: true
            visible: root.widgetsConfig.progressEntries.values.length > 0
            values: root.widgetsConfig.progressEntries.values
            onItemMoved: (from, to) => GlobalConfig.background.desktopWidgets.progressEntries.move(from, to)
            onItemRemoved: index => GlobalConfig.background.desktopWidgets.progressEntries.remove(index)
            onItemToggled: (index, checked) => GlobalConfig.background.desktopWidgets.progressEntries.at(index).enabled = checked
        }

        TextFieldRow {
            first: root.widgetsConfig.progressEntries.values.length === 0
            label: Tr.tr("Milestone name")
            subtext: Tr.tr("Optional; the type is used when this is empty")
            placeholderText: Tr.tr("Christmas")
            value: root.milestoneLabel
            maximumLength: 40
            onValueEdited: value => {
                root.milestoneLabel = value;
                root.milestoneError = "";
            }
        }

        SelectRow {
            label: Tr.tr("Milestone type")
            subtext: Tr.tr("What the progress bar counts towards")
            menuItems: root.milestoneModes
            active: root.milestoneModes[root.milestoneMode]
            onSelected: item => {
                root.milestoneMode = root.milestoneModes.indexOf(item);
                root.milestoneError = "";
            }
        }

        TextFieldRow {
            visible: !root.yearlyMode
            label: root.dateMode ? Tr.tr("Starts (optional)") : root.dayMode || root.dailyMode ? Tr.tr("Starts at") : Tr.tr("Starts")
            subtext: root.dayMode || root.dailyMode ? Tr.tr("HH:mm; when the day begins") : root.weekMode || root.weeklyMode ? Tr.tr("Mon-Sun, optionally with HH:mm") : root.dateMode ? Tr.tr("Defaults to 1 January of the target year") : Tr.tr("YYYY-MM-DD or YYYY-MM-DD HH:mm")
            placeholderText: root.dayMode || root.dailyMode ? Tr.tr("07:00") : root.weekMode || root.weeklyMode ? Tr.tr("Mon 09:00") : Tr.tr("2026-01-01")
            value: root.milestoneStart
            maximumLength: 32
            onValueEdited: value => {
                root.milestoneStart = value;
                root.milestoneError = "";
            }
        }

        TextFieldRow {
            label: root.dayMode || root.dailyMode ? Tr.tr("Ends at") : root.weeklyMode ? Tr.tr("Day and time") : root.weekMode ? Tr.tr("Ends") : root.dateMode || root.yearlyMode ? Tr.tr("Date") : Tr.tr("Ends")
            subtext: root.dayMode ? Tr.tr("HH:mm; when the day is over") : root.dailyMode ? Tr.tr("HH:mm; repeats every day") : root.weeklyMode ? Tr.tr("Mon-Sun, optionally with HH:mm; repeats every week") : root.weekMode ? Tr.tr("Mon-Sun, optionally with HH:mm; defaults to the end of Sunday") : root.yearlyMode ? Tr.tr("MM-DD or MM-DD HH:mm; repeats every year") : Tr.tr("YYYY-MM-DD or YYYY-MM-DD HH:mm")
            placeholderText: root.dayMode ? Tr.tr("18:00") : root.dailyMode ? Tr.tr("23:00") : root.weekMode || root.weeklyMode ? Tr.tr("Fri 17:00") : root.yearlyMode ? Tr.tr("12-25") : Tr.tr("2026-12-25")
            value: root.milestoneEnd
            maximumLength: 32
            onValueEdited: value => {
                root.milestoneEnd = value;
                root.milestoneError = "";
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.largeIncreased
            Layout.rightMargin: Tokens.padding.largeIncreased
            Layout.bottomMargin: Tokens.spacing.small
            visible: root.milestoneError !== ""
            wrapMode: Text.Wrap
            text: root.milestoneError
            color: Colours.palette.m3error
            font: Tokens.font.label.small
        }

        NavRow {
            last: true
            icon: "add"
            text: Tr.tr("Add milestone")
            subtext: Tr.tr("Adds it to every progress card")
            onClicked: root.addMilestone()
        }
    }
}
