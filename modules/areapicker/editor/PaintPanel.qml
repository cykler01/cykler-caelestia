pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services

// NOTE(fork): the screenshot editor's paint panel: the drawing tools and what they
// draw with. Everything it shows lives on the editor, which it reads and writes.
StyledRect {
    id: root

    // The ScreenshotEditor window this panel drives.
    required property var editor

    readonly property bool typing: picker.hexFocused

    color: Colours.tPalette.m3surfaceContainer
    radius: Tokens.rounding.large
    implicitWidth: 244

    StyledFlickable {
        anchors.fill: parent
        anchors.margins: Tokens.padding.medium
        contentHeight: column.implicitHeight
        clip: true

        ColumnLayout {
            id: column

            width: parent.width
            spacing: Tokens.spacing.small

            SectionLabel {
                text: Tr.tr("Tools")
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 4
                rowSpacing: Tokens.spacing.small
                columnSpacing: Tokens.spacing.small

                Repeater {
                    model: [
                        {
                            tool: "select",
                            icon: "arrow_selector_tool"
                        },
                        {
                            tool: "brush",
                            icon: "brush"
                        },
                        {
                            tool: "text",
                            icon: "title"
                        },
                        {
                            tool: "rectangle",
                            icon: "rectangle"
                        },
                        {
                            tool: "ellipse",
                            icon: "circle"
                        },
                        {
                            tool: "arrow",
                            icon: "north_east"
                        },
                        {
                            tool: "blur",
                            icon: "blur_on"
                        }
                    ]

                    delegate: IconButton {
                        required property var modelData

                        Layout.fillWidth: true
                        icon: modelData.icon
                        type: IconButton.Tonal
                        isToggle: true
                        optimistic: false
                        checked: root.editor.tool === modelData.tool
                        onClicked: root.editor.setTool(modelData.tool)
                    }
                }
            }

            SectionLabel {
                text: Tr.tr("Colour")
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                Repeater {
                    model: ["red", "green", "blue", "custom"]

                    delegate: Rectangle {
                        id: swatch

                        required property string modelData
                        readonly property bool current: root.editor.colourMode === modelData

                        Layout.fillWidth: true
                        implicitHeight: 32
                        radius: Tokens.rounding.full
                        color: root.editor.swatchColour(modelData)
                        border.width: current ? 3 : 1
                        border.color: current ? Colours.palette.m3onSurface : Colours.palette.m3outlineVariant

                        MaterialIcon {
                            anchors.centerIn: parent
                            visible: swatch.modelData === "custom"
                            text: "palette"
                            color: swatch.color.hsvValue > 0.6 ? "black" : "white"
                            fontStyle: Tokens.font.icon.small
                        }

                        StateLayer {
                            radius: parent.radius
                            onClicked: root.editor.colourMode = swatch.modelData
                        }
                    }
                }
            }

            ColourPicker {
                id: picker

                Layout.fillWidth: true
                visible: root.editor.colourMode === "custom"
                colour: root.editor.customColour
                onPicked: c => root.editor.customColour = c // qmllint disable signal-handler-parameters
            }

            SectionLabel {
                text: Tr.tr("Stroke size")
            }

            Stepper {
                value: root.editor.strokeSize
                onDecrease: root.editor.changeSize(-1, false)
                onIncrease: root.editor.changeSize(1, false)
            }

            SectionLabel {
                text: Tr.tr("Text size")
            }

            Stepper {
                value: root.editor.textSize
                onDecrease: root.editor.changeSize(-1, true)
                onIncrease: root.editor.changeSize(1, true)
            }

            ToggleLine {
                text: Tr.tr("Fill shapes")
                checked: root.editor.fill
                onToggled: root.editor.fill = !root.editor.fill
            }

            ToggleLine {
                text: Tr.tr("Transparent")
                checked: root.editor.transparent
                onToggled: root.editor.transparent = !root.editor.transparent
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small
                opacity: root.editor.transparent ? 1 : 0.5

                StyledSlider {
                    Layout.fillWidth: true
                    enabled: root.editor.transparent
                    from: 0
                    to: 100
                    stepSize: 1
                    value: root.editor.transparency
                    onMoved: root.editor.transparency = value
                }

                StyledText {
                    Layout.minimumWidth: 36
                    horizontalAlignment: Text.AlignRight
                    text: `${Math.round(root.editor.transparency)}%`
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.medium
                }
            }

            IconTextButton {
                Layout.fillWidth: true
                Layout.topMargin: Tokens.spacing.small
                icon: "ink_eraser"
                text: Tr.tr("Clear annotations")
                type: TextButton.Tonal
                disabled: root.editor.paints.length === 0
                onClicked: root.editor.clearPaints()
            }
        }
    }

    component SectionLabel: StyledText {
        Layout.fillWidth: true
        Layout.topMargin: Tokens.spacing.small
        color: Colours.palette.m3onSurfaceVariant
        font: Tokens.font.label.medium
    }

    component Stepper: RowLayout {
        id: stepper

        property real value

        signal decrease
        signal increase

        Layout.fillWidth: true
        spacing: Tokens.spacing.small

        IconButton {
            icon: "remove"
            type: IconButton.Tonal
            onClicked: stepper.decrease()
        }

        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: Math.round(stepper.value)
            font: Tokens.font.title.small
        }

        IconButton {
            icon: "add"
            type: IconButton.Tonal
            onClicked: stepper.increase()
        }
    }

    component ToggleLine: RowLayout {
        id: toggleLine

        property alias text: label.text
        property bool checked

        signal toggled

        Layout.fillWidth: true
        spacing: Tokens.spacing.small

        StyledText {
            id: label

            Layout.fillWidth: true
            font: Tokens.font.body.medium
        }

        StyledSwitch {
            checked: toggleLine.checked
            onClicked: {
                toggleLine.toggled();
                // A click flips the switch itself, which would cut it loose from the
                // editor; keyboard toggles have to keep showing up here too.
                checked = Qt.binding(() => toggleLine.checked);
            }
        }
    }
}
