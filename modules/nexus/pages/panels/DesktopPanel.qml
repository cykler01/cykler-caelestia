pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    readonly property var iconsConfig: Config.background.desktopIcons
    readonly property var widgetsConfig: Config.background.desktopWidgets

    readonly property list<MenuItem> positionItems: [
        MenuItem {
            readonly property string value: "top-left"

            text: Tr.trCtx("Top left", "desktop item position")
            icon: "north_west"
        },
        MenuItem {
            readonly property string value: "top-right"

            text: Tr.trCtx("Top right", "desktop item position")
            icon: "north_east"
        },
        MenuItem {
            readonly property string value: "bottom-left"

            text: Tr.trCtx("Bottom left", "desktop item position")
            icon: "south_west"
        },
        MenuItem {
            readonly property string value: "bottom-right"

            text: Tr.trCtx("Bottom right", "desktop item position")
            icon: "south_east"
        }
    ]

    readonly property var widgetNames: ({
            calendar: Tr.tr("Calendar"),
            weather: Tr.tr("Weather"),
            pomodoro: Tr.tr("Focus timer"),
            resources: Tr.tr("System resources"),
            media: Tr.tr("Now playing"),
            battery: Tr.tr("Battery")
        })

    function positionItem(value: string): MenuItem {
        return positionItems.find(i => i.value === value) ?? positionItems[0];
    }

    function moveApp(from: int, to: int): void {
        const apps = [...iconsConfig.apps];
        if (to < 0 || to >= apps.length)
            return;
        apps.splice(to, 0, apps.splice(from, 1)[0]);
        GlobalConfig.background.desktopIcons.apps = apps;
    }

    function removeApp(index: int): void {
        const apps = [...iconsConfig.apps];
        apps.splice(index, 1);
        GlobalConfig.background.desktopIcons.apps = apps;
    }

    function appFor(id: string): var {
        return DesktopEntries.byId(id) ?? DesktopEntries.heuristicLookup(id);
    }

    title: Tr.tr("Desktop")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // ---------- App shortcuts ----------
        SectionHeader {
            first: true
            text: Tr.tr("App shortcuts")
        }

        ToggleRow {
            first: true
            text: Tr.trCtx("Enabled", "toggle label")
            subtext: Tr.tr("Show application shortcuts on the desktop")
            checked: root.iconsConfig.enabled
            onToggled: GlobalConfig.background.desktopIcons.enabled = checked
        }

        ToggleRow {
            text: Tr.tr("Hide when windows are open")
            subtext: Tr.tr("Fade out while the workspace has windows on it")
            checked: root.iconsConfig.hideWithWindows
            onToggled: GlobalConfig.background.desktopIcons.hideWithWindows = checked
        }

        ToggleRow {
            text: Tr.tr("Show labels")
            subtext: Tr.tr("Show app names under the icons")
            checked: root.iconsConfig.showLabels
            onToggled: GlobalConfig.background.desktopIcons.showLabels = checked
        }

        StepperRow {
            label: Tr.tr("Icon size")
            // TRANSLATORS: px is the pixel unit, leave it untranslated
            subtext: Tr.tr("Size of the app icons (px)")
            value: root.iconsConfig.iconSize
            from: 24
            to: 128
            stepSize: 4
            onMoved: v => GlobalConfig.background.desktopIcons.iconSize = Math.round(v)
        }

        SelectRow {
            last: true
            label: Tr.tr("Position")
            menuItems: root.positionItems
            active: root.positionItem(root.iconsConfig.position)
            onSelected: item => GlobalConfig.background.desktopIcons.position = item.value
        }

        // ---------- Shortcut apps ----------
        SectionHeader {
            text: Tr.tr("Applications")
        }

        Repeater {
            id: appList

            model: root.iconsConfig.apps

            ConnectedRect {
                id: appRow

                required property string modelData
                required property int index
                readonly property var entry: root.appFor(modelData)

                Layout.fillWidth: true
                first: index === 0
                last: false
                implicitHeight: rowLayout.implicitHeight + rowLayout.anchors.margins * 2

                RowLayout {
                    id: rowLayout

                    anchors.fill: parent
                    anchors.margins: Tokens.padding.medium
                    anchors.leftMargin: Tokens.padding.largeIncreased
                    anchors.rightMargin: Tokens.padding.medium
                    spacing: Tokens.spacing.medium

                    IconImage {
                        asynchronous: true
                        implicitSize: Math.round(Tokens.font.icon.large.pointSize * 1.8)
                        source: Quickshell.iconPath(appRow.entry?.icon ?? "", "image-missing")
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: appRow.entry?.name ?? appRow.modelData
                        font: Tokens.font.body.small
                        elide: Text.ElideRight
                    }

                    IconButton {
                        icon: "keyboard_arrow_up"
                        type: IconButton.Text
                        disabled: appRow.index === 0
                        onClicked: root.moveApp(appRow.index, appRow.index - 1)
                    }

                    IconButton {
                        icon: "keyboard_arrow_down"
                        type: IconButton.Text
                        disabled: appRow.index === appList.count - 1
                        onClicked: root.moveApp(appRow.index, appRow.index + 1)
                    }

                    IconButton {
                        icon: "delete"
                        type: IconButton.Text
                        onClicked: root.removeApp(appRow.index)
                    }
                }
            }
        }

        DialogSelectButton {
            rootParent: root.flickable
            icon: "add"
            label: Tr.tr("Add application")
            header: Tr.tr("Add an application to the desktop")
            acceptLabel: Tr.trCtx("Add", "button")

            model: [...DesktopEntries.applications.values].sort((a, b) => a.name.localeCompare(b.name)).map(a => ({
                        id: a.id,
                        label: a.name
                    }))

            onAccepted: {
                if (!selectedItem)
                    return;
                const apps = [...root.iconsConfig.apps];
                if (!apps.includes(selectedItem)) {
                    apps.push(selectedItem);
                    GlobalConfig.background.desktopIcons.apps = apps;
                }
            }
        }

        // ---------- Widgets ----------
        SectionHeader {
            text: Tr.tr("Widgets")
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
            subtext: Tr.tr("Fade out while the workspace has windows on it")
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
            label: Tr.tr("Card opacity")
            subtext: Tr.tr("How opaque the card backgrounds are (%)")
            value: Math.round(root.widgetsConfig.opacity * 100)
            from: 10
            to: 100
            stepSize: 5
            onMoved: v => GlobalConfig.background.desktopWidgets.opacity = Math.round(v) / 100
        }

        SelectRow {
            last: true
            label: Tr.tr("Position")
            menuItems: root.positionItems
            active: root.positionItem(root.widgetsConfig.position)
            onSelected: item => GlobalConfig.background.desktopWidgets.position = item.value
        }

        SectionHeader {
            text: Tr.tr("Widget grid")
        }

        StepperRow {
            first: true
            last: true
            label: Tr.tr("Columns")
            subtext: Tr.tr("How many columns the widgets are arranged in; rows stretch to an even height")
            value: root.widgetsConfig.columns
            from: 1
            to: 4
            stepSize: 1
            onMoved: v => GlobalConfig.background.desktopWidgets.columns = Math.round(v)
        }

        SectionHeader {
            text: Tr.tr("Widget order (drag to reorder)")
        }

        ListEditor {
            function labelFor(item: var): string {
                return root.widgetNames[item.id] ?? item.id;
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

        DialogSelectButton {
            rootParent: root.flickable
            icon: "add"
            label: Tr.tr("Add widget")
            header: Tr.tr("Add a widget")
            acceptLabel: Tr.trCtx("Add", "button")

            // Only widgets that aren't in the list already
            model: Object.keys(root.widgetNames).filter(id => !root.widgetsConfig.entries.values.some(e => e.id === id)).map(id => ({
                        id: id,
                        label: root.widgetNames[id]
                    }))

            onAccepted: {
                if (!selectedItem)
                    return;
                GlobalConfig.background.desktopWidgets.entries.insert({
                    id: selectedItem,
                    enabled: true
                });
            }
        }
    }
}
