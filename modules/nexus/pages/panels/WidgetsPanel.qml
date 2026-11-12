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
    }
}
