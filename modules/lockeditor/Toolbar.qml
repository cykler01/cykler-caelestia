pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services

// The editor's bar along the top: starting over from a preset and adding elements, undo and redo,
// mirroring, snapping, which side of a curtain to look at, and leaving with or without saving
StyledRect {
    id: root

    required property var editor

    implicitWidth: row.implicitWidth + Tokens.padding.small * 2
    implicitHeight: row.implicitHeight + Tokens.padding.small * 2
    radius: Tokens.rounding.full
    color: Colours.palette.m3surfaceContainer

    layer.enabled: true
    layer.effect: MultiEffect {
        shadowEnabled: true
        blurMax: 16
        shadowColor: Qt.alpha(Colours.palette.m3shadow, 0.6)
    }

    RowLayout {
        id: row

        anchors.centerIn: parent
        spacing: Tokens.spacing.small

        EditorButton {
            icon: "dashboard_customize"
            text: Tr.tr("Presets")
            onActivated: root.editor.sheet = "presets"
        }

        EditorButton {
            icon: "add"
            text: Tr.tr("Add element")
            onActivated: root.editor.sheet = "add"
        }

        Separator {}

        EditorButton {
            icon: "undo"
            tone: "plain"
            disabled: root.editor.undoStack.length === 0
            onActivated: root.editor.undo()
        }

        EditorButton {
            icon: "redo"
            tone: "plain"
            disabled: root.editor.redoStack.length === 0
            onActivated: root.editor.redo()
        }

        EditorButton {
            icon: "flip"
            text: Tr.tr("Mirror")
            tone: "plain"
            onActivated: root.editor.mirror()
        }

        EditorButton {
            icon: "grid_4x4"
            text: Tr.tr("Snap")
            tone: "plain"
            checked: root.editor.snap
            onActivated: root.editor.snap = !root.editor.snap
        }

        EditorButton {
            icon: "view_sidebar"
            text: Tr.tr("Panel")
            tone: "plain"
            checked: root.editor.inspectorShown
            onActivated: root.editor.inspectorShown = !root.editor.inspectorShown
        }

        // Only once something is set to show on one side of the curtain only
        Separator {
            visible: root.editor.hasCurtain
        }

        Repeater {
            model: root.editor.hasCurtain ? [
                {
                    phase: "",
                    text: Tr.tr("Both")
                },
                {
                    phase: "rest",
                    text: Tr.tr("Before typing")
                },
                {
                    phase: "active",
                    text: Tr.tr("Signing in")
                }
            ] : []

            EditorButton {
                required property var modelData

                text: modelData.text
                tone: "plain"
                checked: root.editor.phase === modelData.phase
                onActivated: root.editor.phase = modelData.phase
            }
        }

        Separator {}

        EditorButton {
            icon: "close"
            text: Tr.tr("Cancel")
            tone: "plain"
            onActivated: root.editor.requestClose()
        }

        EditorButton {
            icon: "check"
            text: root.editor.canSave ? Tr.tr("Save") : Tr.tr("Can't save")
            tone: "primary"
            disabled: !root.editor.canSave
            onActivated: root.editor.save()
        }
    }

    component Separator: Rectangle {
        Layout.fillHeight: true
        Layout.topMargin: Tokens.padding.small
        Layout.bottomMargin: Tokens.padding.small
        implicitWidth: 1
        color: Qt.alpha(Colours.palette.m3onSurface, 0.2)
    }
}
