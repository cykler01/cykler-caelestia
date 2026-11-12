pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.components.filedialog
import qs.services
import qs.utils
import qs.modules.nexus.common

// The desktop's widget cards: which ones show, their look, and the settings the individual cards read
PageBase {
    id: root

    readonly property var widgetsConfig: GlobalConfig.background.desktopWidgets

    // 0 day, 1 week, 2 date, 3 interval, matching Milestones.modes
    property int milestoneMode: 2
    property string milestoneLabel: ""
    property string milestoneStart: ""
    property string milestoneEnd: ""
    property string milestoneError: ""

    readonly property list<MenuItem> milestoneModes: [
        MenuItem {
            text: Tr.tr("End of day")
        },
        MenuItem {
            text: Tr.tr("End of week")
        },
        MenuItem {
            text: Tr.tr("Specific date")
        },
        MenuItem {
            text: Tr.tr("Custom interval")
        }
    ]

    function addMilestone(): void {
        root.milestoneError = "";
        const mode = ["day", "week", "date", "interval"][root.milestoneMode] ?? "date";

        if (root.widgetsConfig.progressEntries.values.length >= Milestones.maxItems) {
            root.milestoneError = Tr.tr("You can show up to %1 milestones").arg(Milestones.maxItems);
            return;
        }

        if (mode === "date") {
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
            start: mode === "day" || mode === "week" ? "" : root.milestoneStart.trim(),
            end: mode === "day" || mode === "week" ? "" : root.milestoneEnd.trim(),
            enabled: true
        });

        root.milestoneLabel = "";
        root.milestoneStart = "";
        root.milestoneEnd = "";
    }

    title: Tr.tr("Widgets")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: Tr.tr("Cards")
        }

        ToggleRow {
            first: true
            text: Tr.trCtx("Enabled", "toggle label")
            subtext: Tr.tr("Show widget cards on the desktop")
            checked: root.widgetsConfig.enabled
            onToggled: GlobalConfig.background.desktopWidgets.enabled = checked
        }

        ToggleRow {
            text: Tr.tr("Hide when windows are open")
            subtext: Tr.tr("Fade the widget cards out while the workspace has windows on it")
            checked: root.widgetsConfig.hideWithWindows
            onToggled: GlobalConfig.background.desktopWidgets.hideWithWindows = checked
        }

        ToggleRow {
            text: Tr.tr("Blur background")
            subtext: Tr.tr("Blur the wallpaper behind each card")
            checked: root.widgetsConfig.blur
            onToggled: GlobalConfig.background.desktopWidgets.blur = checked
        }

        StepperRow {
            last: true
            label: Tr.tr("Card opacity")
            subtext: Tr.tr("How opaque the card backgrounds are (%)")
            value: Math.round(root.widgetsConfig.opacity * 100)
            from: 10
            to: 100
            stepSize: 5
            onMoved: v => GlobalConfig.background.desktopWidgets.opacity = Math.round(v) / 100
        }

        SectionHeader {
            text: Tr.tr("Widget list")
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.largeIncreased
            Layout.rightMargin: Tokens.padding.largeIncreased
            Layout.bottomMargin: Tokens.spacing.small
            visible: root.widgetsConfig.entries.values.length === 0
            wrapMode: Text.Wrap
            text: Tr.tr("Nothing on the desktop yet. Add a widget below to show one.")
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
        }

        ListEditor {
            function labelFor(item: var): string {
                const name = WidgetCatalog.nameFor(item.id);
                const type = WidgetCatalog.typeNameFor(item.id, item.type);
                return type === "" ? name : `${name} · ${type}`;
            }

            function toggledFor(item: var): bool {
                return item.enabled;
            }

            z: 1
            first: true
            values: root.widgetsConfig.entries.values
            onItemMoved: (from, to) => GlobalConfig.background.desktopWidgets.entries.move(from, to)
            onItemRemoved: index => GlobalConfig.background.desktopWidgets.entries.remove(index)
            onItemToggled: (index, checked) => GlobalConfig.background.desktopWidgets.entries.at(index).enabled = checked
        }

        NavRow {
            first: root.widgetsConfig.entries.values.length === 0
            last: true
            icon: "add"
            text: Tr.tr("Add widget")
            subtext: Tr.tr("Pick a widget, then its style")
            onClicked: root.nState.openSubPage(19)
        }

        SectionHeader {
            text: Tr.tr("Widget settings")
        }

        ConnectedRect {
            first: true
            last: false
            // Without this the row keeps its (zero) implicit width inside the page's ColumnLayout
            Layout.fillWidth: true
            implicitHeight: folderRow.implicitHeight + Tokens.padding.medium * 2

            RowLayout {
                id: folderRow

                anchors.fill: parent
                anchors.margins: Tokens.padding.medium
                anchors.leftMargin: Tokens.padding.largeIncreased
                anchors.rightMargin: Tokens.padding.medium
                spacing: Tokens.spacing.medium

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    StyledText {
                        Layout.fillWidth: true
                        text: Tr.tr("Folder")
                        font: Tokens.font.body.small
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: Paths.shortenHome(root.widgetsConfig.photoDir)
                        color: Colours.palette.m3outline
                        font: Tokens.font.label.small
                        elide: Text.ElideMiddle
                    }
                }

                IconButton {
                    icon: "folder_open"
                    type: IconButton.Text
                    onClicked: folderDialog.open()
                }
            }

            FileDialog {
                id: folderDialog

                title: Tr.tr("Select a folder")
                folderMode: true
                onAccepted: path => GlobalConfig.background.desktopWidgets.photoDir = path
            }
        }

        TextFieldRow {
            last: false
            label: Tr.tr("GitHub name")
            subtext: Tr.tr("Shown on the contributions widget")
            value: root.widgetsConfig.githubUser
            onEditingFinished: value => GlobalConfig.background.desktopWidgets.githubUser = value
        }

        TextFieldRow {
            last: true
            label: Tr.tr("Stock symbols")
            subtext: Tr.tr("Yahoo Finance tickers for the stocks widget, separated by commas (up to six)")
            placeholderText: Tr.tr("AAPL, MSFT, NVDA")
            value: Stocks.symbols.join(", ")
            maximumLength: 96
            onEditingFinished: value => GlobalConfig.background.desktopWidgets.stockSymbols = Stocks.normaliseSymbols(value)
        }

        SectionHeader {
            text: Tr.tr("Milestones")
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.largeIncreased
            Layout.rightMargin: Tokens.padding.largeIncreased
            Layout.bottomMargin: Tokens.spacing.small
            wrapMode: Text.Wrap
            text: Tr.tr("The progress widget shows end of day and end of week automatically. Add a specific date or an interval below; each card can show up to %1.").arg(Milestones.maxItems)
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
            visible: root.milestoneMode >= 2
            label: root.milestoneMode === 2 ? Tr.tr("Starts (optional)") : Tr.tr("Starts")
            subtext: root.milestoneMode === 2 ? Tr.tr("Defaults to 1 January of the target year") : Tr.tr("YYYY-MM-DD or YYYY-MM-DD HH:mm")
            placeholderText: Tr.tr("2026-01-01")
            value: root.milestoneStart
            maximumLength: 32
            onValueEdited: value => {
                root.milestoneStart = value;
                root.milestoneError = "";
            }
        }

        TextFieldRow {
            visible: root.milestoneMode >= 2
            label: root.milestoneMode === 2 ? Tr.tr("Date") : Tr.tr("Ends")
            subtext: Tr.tr("YYYY-MM-DD or YYYY-MM-DD HH:mm")
            placeholderText: Tr.tr("2026-12-25")
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
