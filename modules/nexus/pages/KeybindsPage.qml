pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

// NOTE(fork): change the Hyprland keybinds without editing Lua. See services/Keybinds.qml.
PageBase {
    id: root

    // Sections of the binds that match the search, in file order
    readonly property var groups: {
        const q = search.text.trim().toLowerCase();
        const sections = new Map();
        for (const e of Keybinds.entries) {
            if (q && !`${e.label} ${e.combos.map(c => Keybinds.pretty(c)).join(" ")}`.toLowerCase().includes(q))
                continue;
            if (!sections.has(e.section))
                sections.set(e.section, []);
            sections.get(e.section).push(e);
        }
        return [...sections].map(([name, items]) => ({
                    name: name.charAt(0).toUpperCase() + name.slice(1),
                    items
                }));
    }

    title: Tr.tr("Keybinds")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        StyledTextField {
            id: search

            Layout.fillWidth: true
            Layout.bottomMargin: Tokens.spacing.large
            visible: Keybinds.available
            leadingIcon: "search"
            placeholderText: Tr.tr("Search keybinds")
        }

        StyledText {
            Layout.fillWidth: true
            visible: !Keybinds.available
            text: Tr.tr("No keybinds were found in your Hyprland config (hypr/variables.lua).")
            color: Colours.palette.m3outline
            wrapMode: Text.WordWrap
        }

        StyledText {
            Layout.fillWidth: true
            Layout.bottomMargin: Tokens.spacing.small
            visible: Keybinds.available && search.text === ""
            text: Tr.tr("Click a keybind to change it. Pick its modifiers, then click the key and press the one you want. Changes are saved to your hypr-vars.lua and Hyprland is reloaded.")
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
            wrapMode: Text.WordWrap
        }

        Repeater {
            // Keyed by name, so a row keeps being expanded while its own shortcuts change
            model: ScriptModel {
                values: root.groups
                objectProp: "name"
            }

            ColumnLayout {
                id: group

                required property var modelData
                required property int index

                Layout.fillWidth: true
                spacing: Tokens.spacing.extraSmall / 2

                SectionHeader {
                    first: group.index === 0
                    text: group.modelData.name
                }

                Repeater {
                    model: ScriptModel {
                        values: group.modelData.items
                        objectProp: "id"
                    }

                    KeybindRow {
                        required property var modelData
                        required property int index

                        entry: modelData
                        first: index === 0
                        last: index === group.modelData.items.length - 1
                    }
                }
            }
        }
    }
}
