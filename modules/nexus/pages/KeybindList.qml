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

// NOTE(fork): every keybind as a list of rows, with the custom binds and the touchpad
// gestures under them. This is the List half of the Keybinds page; KeyboardView is the other,
// which draws the same binds on a keyboard.
ColumnLayout {
    id: root

    // A custom bind being added, not saved until it has both a combo and a command
    property bool addingCustom
    property string pendingCombo
    property string pendingCommand

    // A custom gesture being added, not saved until it has a command
    property bool addingGesture
    property int pendingGestureFingers: 3
    property string pendingGestureDirection: "up"
    property string pendingGestureCommand

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

    function commitCustom(): void {
        if (root.pendingCombo === "" || root.pendingCommand.trim() === "")
            return;

        Keybinds.addCustomBind(root.pendingCombo, root.pendingCommand.trim());
        root.addingCustom = false;
        root.pendingCombo = "";
        root.pendingCommand = "";
    }

    function commitGesture(): void {
        if (root.pendingGestureCommand.trim() === "")
            return;

        Keybinds.addCustomGesture(root.pendingGestureFingers, root.pendingGestureDirection, root.pendingGestureCommand.trim());
        root.addingGesture = false;
        root.pendingGestureFingers = 3;
        root.pendingGestureDirection = "up";
        root.pendingGestureCommand = "";
    }

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
        Layout.bottomMargin: Tokens.spacing.small
        visible: search.text === ""
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

    ColumnLayout {
        id: customGroup

        Layout.fillWidth: true
        visible: search.text === ""
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: root.groups.length === 0
            text: Tr.tr("Custom")
        }

        Repeater {
            model: ScriptModel {
                values: Keybinds.customBinds
            }

            CustomKeybindRow {
                // index is filled in directly since this already declares its own
                // "required property int index"
                required property var modelData

                combo: modelData.combo
                command: modelData.command
            }
        }

        ConnectedRect {
            Layout.fillWidth: true
            last: true
            implicitHeight: addRow.implicitHeight + Tokens.padding.medium * 2

            ColumnLayout {
                id: addRow

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: Tokens.padding.largeIncreased
                spacing: Tokens.spacing.small

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.medium
                    visible: root.addingCustom

                    ComboEditor {
                        Layout.fillWidth: true
                        combo: root.pendingCombo
                        startCapturing: root.pendingCombo === ""
                        removable: true
                        onChanged: c => root.pendingCombo = c
                        onRemoved: {
                            root.addingCustom = false;
                            root.pendingCombo = "";
                            root.pendingCommand = "";
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.medium
                    visible: root.addingCustom

                    StyledTextField {
                        Layout.fillWidth: true
                        text: root.pendingCommand
                        placeholderText: Tr.tr("Command to run")
                        onTextEdited: root.pendingCommand = text
                        Keys.onReturnPressed: root.commitCustom()
                    }

                    IconButton {
                        type: IconButton.Filled
                        isRound: true
                        icon: "check"
                        disabled: root.pendingCombo === "" || root.pendingCommand.trim() === ""
                        font: Tokens.font.icon.medium
                        onClicked: root.commitCustom()
                    }
                }

                TextButton {
                    visible: !root.addingCustom
                    type: TextButton.Text
                    isRound: true
                    text: Tr.tr("Add keybind")
                    onClicked: root.addingCustom = true
                }
            }
        }
    }

    ColumnLayout {
        id: gestureGroup

        Layout.fillWidth: true
        Layout.topMargin: Tokens.spacing.largeIncreased
        visible: search.text === ""
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: Tr.tr("Gestures")
        }

        StyledText {
            Layout.fillWidth: true
            Layout.bottomMargin: Tokens.spacing.small
            text: Tr.tr("Touchpad swipes. Changes are saved to your hypr-vars.lua and Hyprland is reloaded.")
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
            wrapMode: Text.WordWrap
        }

        StepperRow {
            first: true
            label: Tr.tr("Switch workspace")
            subtext: Tr.tr("Horizontal swipe")
            value: Keybinds.gestureFingerCount("workspaceSwipeFingers")
            from: 2
            to: 5
            onMoved: v => Keybinds.setGestureFingerCount("workspaceSwipeFingers", v)
        }

        StepperRow {
            label: Tr.tr("Special workspace")
            subtext: Tr.tr("Swipe up or down")
            value: Keybinds.gestureFingerCount("gestureFingers")
            from: 2
            to: 5
            onMoved: v => Keybinds.setGestureFingerCount("gestureFingers", v)
        }

        StepperRow {
            last: true
            label: Tr.tr("Close overview, or sleep")
            subtext: Tr.tr("Swipe down")
            value: Keybinds.gestureFingerCount("gestureFingersMore")
            from: 2
            to: 5
            onMoved: v => Keybinds.setGestureFingerCount("gestureFingersMore", v)
        }
    }

    ColumnLayout {
        id: customGestureGroup

        Layout.fillWidth: true
        visible: search.text === ""
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            text: Tr.tr("Custom gestures")
        }

        Repeater {
            model: ScriptModel {
                values: Keybinds.customGestures
            }

            CustomGestureRow {
                // index is filled in directly since this already declares its own
                // "required property int index"
                required property var modelData

                fingers: modelData.fingers
                direction: modelData.direction
                command: modelData.command
            }
        }

        ConnectedRect {
            Layout.fillWidth: true
            last: true
            implicitHeight: addGestureRow.implicitHeight + Tokens.padding.medium * 2

            ColumnLayout {
                id: addGestureRow

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: Tokens.padding.largeIncreased
                spacing: Tokens.spacing.small

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.medium
                    visible: root.addingGesture

                    StyledSpinBox {
                        fieldWidth: 32
                        from: 2
                        to: 5
                        value: root.pendingGestureFingers
                        onValueModified: root.pendingGestureFingers = value
                    }

                    GestureDirectionPicker {
                        direction: root.pendingGestureDirection
                        onSelected: d => root.pendingGestureDirection = d
                    }

                    Item {
                        Layout.fillWidth: true
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.medium
                    visible: root.addingGesture

                    StyledTextField {
                        Layout.fillWidth: true
                        text: root.pendingGestureCommand
                        placeholderText: Tr.tr("Command to run")
                        onTextEdited: root.pendingGestureCommand = text
                        Keys.onReturnPressed: root.commitGesture()
                    }

                    IconButton {
                        type: IconButton.Filled
                        isRound: true
                        icon: "check"
                        disabled: root.pendingGestureCommand.trim() === ""
                        font: Tokens.font.icon.medium
                        onClicked: root.commitGesture()
                    }
                }

                TextButton {
                    visible: !root.addingGesture
                    type: TextButton.Text
                    isRound: true
                    text: Tr.tr("Add gesture")
                    onClicked: root.addingGesture = true
                }
            }
        }
    }
}
