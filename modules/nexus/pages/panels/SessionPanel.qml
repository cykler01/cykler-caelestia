pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.modules.nexus.common

// What the session menu (the panel that slides in with the session keybind) offers. The animation in
// the middle of it isn't an action, so it stays put and is set under Shell assets instead.
PageBase {
    id: root

    readonly property var builtinEntries: ({
            logout: Tr.tr("Log out"),
            shutdown: Tr.tr("Shut down"),
            sleep: Tr.tr("Sleep"),
            reboot: Tr.tr("Reboot")
        })

    title: Tr.tr("Session menu")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: Tr.tr("Actions")
        }

        StyledText {
            Layout.fillWidth: true
            Layout.bottomMargin: Tokens.spacing.small
            text: Tr.tr("What the menu offers, top to bottom, and in what order. Switch one off to keep it from showing.")
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
            values: Config.session.entries.values
            onItemMoved: (from, to) => GlobalConfig.session.entries.move(from, to)
            onItemRemoved: index => GlobalConfig.session.entries.remove(index)
            onItemToggled: (index, checked) => GlobalConfig.session.entries.at(index).enabled = checked
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

                GlobalConfig.session.entries.insert({
                    id: selectedItem,
                    enabled: true
                });
            }
        }

        SectionHeader {
            text: Tr.tr("Behaviour")
        }

        ToggleRow {
            first: true
            text: Tr.tr("Vim keybinds")
            subtext: Tr.tr("Move between the actions with Ctrl+J/K or Ctrl+N/P")
            checked: Config.session.vimKeybinds
            onToggled: GlobalConfig.session.vimKeybinds = checked
        }

        ToggleRow {
            last: true
            text: Tr.tr("Enabled")
            subtext: Tr.tr("Show the session menu at all")
            checked: Config.session.enabled
            onToggled: GlobalConfig.session.enabled = checked
        }
    }
}
