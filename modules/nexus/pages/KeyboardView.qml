pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

// NOTE(fork): the Keyboard half of the Keybinds page - the board itself (KeyboardMap), what the
// key under the pointer or the one clicked open does (KeyInspector), and the controls that say
// how much of a keyboard to draw and which modifiers the colours describe.
ColumnLayout {
    id: root

    readonly property var sizes: ["60%", "75%", "100%"]
    property string size: "100%"

    // The modifiers the colours describe, as a bitmask; -1 is every combination
    readonly property var filters: [-1, 0, Keybinds.maskOf(["SUPER"]), Keybinds.maskOf(["CTRL"]), Keybinds.maskOf(["ALT"]), Keybinds.maskOf(["SHIFT"])]
    property int filter: -1

    // Confirming a reset, so one stray click cannot undo every change at once
    property bool confirmingReset

    readonly property string shown: map.selected !== "" ? map.selected : map.hovered
    readonly property string shownLabel: map.layout.find(k => k.key === root.shown)?.label ?? root.shown

    spacing: Tokens.spacing.small

    RowLayout {
        Layout.fillWidth: true
        Layout.bottomMargin: Tokens.spacing.extraSmall
        spacing: Tokens.spacing.medium

        StyledText {
            Layout.fillWidth: true
            text: Tr.tr("Hover a key to see what it does. Click one to change it.")
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
            wrapMode: Text.WordWrap
        }

        SegmentedBar {
            implicitWidth: 180
            segmentHeight: 30
            currentIndex: root.sizes.indexOf(root.size)
            model: root.sizes.map(s => ({
                        text: s
                    }))

            onActivated: index => root.size = root.sizes[index]
        }
    }

    SegmentedBar {
        Layout.fillWidth: true
        segmentHeight: 30
        currentIndex: root.filters.indexOf(root.filter)
        model: [
            {
                text: Tr.tr("Any")
            },
            {
                text: Tr.tr("None")
            },
            {
                text: "Super"
            },
            {
                text: "Ctrl"
            },
            {
                text: "Alt"
            },
            {
                text: "Shift"
            }
        ]

        onActivated: index => root.filter = root.filters[index]
    }

    KeyboardMap {
        id: map

        Layout.fillWidth: true
        Layout.topMargin: Tokens.spacing.medium
        boardSize: root.size
        mask: root.filter
    }

    StyledText {
        Layout.fillWidth: true
        Layout.topMargin: Tokens.spacing.extraSmall
        text: Keybinds.conflictCount > 0 ? `${Tr.tr("Outlined: bound · red: two binds on one shortcut · faint: free")} · ${Tr.tr("keys with a clash: %1").arg(Keybinds.conflictCount)}` : Tr.tr("Outlined: bound · red: two binds on one shortcut · faint: free")
        color: Colours.palette.m3outline
        font: Tokens.font.label.small
        wrapMode: Text.WordWrap
    }

    KeyInspector {
        Layout.fillWidth: true
        Layout.topMargin: Tokens.spacing.small
        visible: root.shown !== ""
        keyName: root.shown
        keyLabel: root.shownLabel
        editable: map.selected !== ""
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: Tokens.spacing.medium
        spacing: Tokens.spacing.medium

        TextButton {
            type: TextButton.Tonal
            isRound: true
            text: Tr.tr("Reload")
            onClicked: Keybinds.reload()
        }

        TextButton {
            type: TextButton.Tonal
            isRound: true
            text: root.confirmingReset ? Tr.tr("Reset every shortcut?") : Tr.tr("Reset all")
            onClicked: {
                if (root.confirmingReset) {
                    Keybinds.resetAll();
                    root.confirmingReset = false;
                } else {
                    root.confirmingReset = true;
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            visible: root.confirmingReset
            text: Tr.tr("Click again to put every keybind back to its default. Custom binds are kept.")
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
            wrapMode: Text.WordWrap
        }
    }
}
