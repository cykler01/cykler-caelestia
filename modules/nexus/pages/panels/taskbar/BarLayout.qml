pragma ComponentBehavior: Bound

import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.modules.nexus.common

// The bar's own entries (Config.bar.entries), same list-editor pattern BarStatusIcons.qml
// already uses for its own sub-list. A "spacer" pushes whatever comes after it (up to the next
// spacer, or the end) away from whatever comes before it - two of them around one entry, e.g.
// [..., spacer, activeWindow, spacer, ...], centres it, the classic caelestia layout with the
// active window's title in the middle instead of the clock.
PageBase {
    id: root

    readonly property var builtinEntries: ({
            logo: Tr.tr("Logo"),
            workspaces: Tr.tr("Workspaces"),
            activeWindow: Tr.tr("Active window"),
            tray: Tr.tr("Tray"),
            timer: Tr.tr("Timer"),
            clock: Tr.tr("Clock"),
            statusIcons: Tr.tr("Status icons"),
            power: Tr.tr("Power button"),
            spacer: Tr.trCtx("Spacer", "bar layout entry - pushes the next entries away from the previous ones")
        })

    title: Tr.tr("Layout")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: Tr.tr("Entries")
        }

        StyledText {
            Layout.fillWidth: true
            Layout.bottomMargin: Tokens.spacing.small
            text: Tr.tr("What's shown on the bar, left to right, and in what order. A spacer pushes everything after it (up to the next one) away from everything before it - put one on each side of an entry to centre it.")
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
            wrapMode: Text.WordWrap
        }

        ListEditor {
            function labelFor(item: var): string {
                return root.builtinEntries[item.id] ?? item.id;
            }

            function toggledFor(item: var): bool {
                return item.enabled;
            }

            z: 1
            first: true
            values: Config.bar.entries.values
            onItemMoved: (from, to) => GlobalConfig.bar.entries.move(from, to)
            onItemRemoved: index => GlobalConfig.bar.entries.remove(index)
            onItemToggled: (index, checked) => GlobalConfig.bar.entries.at(index).enabled = checked
        }

        DialogSelectButton {
            id: addItemContainer

            rootParent: root.flickable
            icon: "add"
            label: Tr.tr("Add entry")
            header: Tr.tr("Add new entry")
            acceptLabel: Tr.trCtx("Add", "button")

            model: Object.keys(root.builtinEntries).map(k => ({
                        id: k,
                        label: root.builtinEntries[k]
                    }))

            onAccepted: {
                if (!selectedItem)
                    return;

                GlobalConfig.bar.entries.insert({
                    id: selectedItem,
                    enabled: true
                });
            }
        }
    }
}
