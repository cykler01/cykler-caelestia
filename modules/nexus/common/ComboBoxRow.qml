pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

// A free-text row with a dropdown of suggestions: pick one from the menu, or ignore it and type any
// value you like. Selecting a suggestion commits it straight away, the same as finishing an edit (fork feature).
ConnectedRect {
    id: root

    property alias label: label.text
    property string subtext
    property string value
    property alias placeholderText: input.placeholderText
    // Values offered by the dropdown
    property list<string> suggestions: []
    // Icon shown on each suggestion in the dropdown
    property string suggestionIcon
    // Hint shown in the dropdown while there is nothing to offer, e.g. "Loading branches..."
    property string emptyText

    readonly property list<MenuItem> menuItems: suggestions.length > 0 ? suggestions.map(s => itemComp.createObject(root, {
            text: s,
            icon: root.suggestionIcon,
            value: s
        })) : emptyText ? [itemComp.createObject(root, {
            text: root.emptyText,
            icon: "hourglass_empty",
            value: ""
        })] : []

    // Emitted when the dropdown is opened, so the caller can refresh the suggestions first
    signal opened
    signal valueEdited(value: string)
    signal editingFinished(value: string)

    function clear(): void {
        input.clear();
    }

    searchLabel: root.label
    Component.onDestruction: {
        if (value !== input.text)
            editingFinished(input.text);
    }

    Layout.fillWidth: true
    implicitHeight: rowLayout.implicitHeight + Tokens.padding.medium + Math.max(0, Tokens.padding.large - input.verticalPadding) * 2
    clip: false
    z: dropdownMenu.expanded ? 1 : 0

    RowLayout {
        id: rowLayout

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Tokens.padding.largeIncreased
        anchors.rightMargin: Tokens.padding.largeIncreased
        spacing: Tokens.spacing.medium

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                id: label

                Layout.fillWidth: true
                font: Tokens.font.body.small
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                visible: root.subtext
                text: root.subtext
                color: Colours.palette.m3outline
                font: Tokens.font.label.small
                elide: Text.ElideRight
            }
        }

        StyledTextField {
            id: input

            Layout.preferredWidth: Tokens.sizes.nexus.textFieldWidth
            Layout.maximumWidth: root.width / 2
            Layout.alignment: Qt.AlignVCenter
            verticalPadding: Tokens.padding.small

            text: root.value

            onTextEdited: root.valueEdited(text)
            onEditingFinished: root.editingFinished(text)
        }

        IconButton {
            id: dropdownButton

            Layout.alignment: Qt.AlignVCenter
            type: IconButton.Tonal
            icon: dropdownMenu.expanded ? "expand_less" : "expand_more"
            onClicked: dropdownMenu.expanded = !dropdownMenu.expanded

            Menu {
                id: dropdownMenu

                attachTo: dropdownButton
                items: root.menuItems
                active: root.menuItems.find(item => item.value === root.value) ?? null
                onExpandedChanged: {
                    if (expanded)
                        root.opened();
                }
                onItemSelected: item => {
                    // The empty state hint is not a value to pick
                    if (item.value === "")
                        return;
                    input.text = item.value;
                    root.valueEdited(item.value);
                    root.editingFinished(item.value);
                }
            }
        }
    }

    Component {
        id: itemComp

        MenuItem {}
    }
}
