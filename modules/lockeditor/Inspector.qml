pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.lock.canvas

// The editor's side panel. With an element selected: where it's pinned, its size, opacity and
// turn, when it shows, and every option its kind has (ElementCatalog). With nothing selected: the
// list of elements, top of the stack first, to pick one that's hard to get at on the canvas, hide
// one without removing it, and the keys the editor answers to
StyledRect {
    id: root

    required property var editor
    required property var canvas

    readonly property int index: editor.selected
    readonly property var element: editor.selectedElement
    readonly property var kind: element ? ElementCatalog.kind(element.id) : null
    readonly property var opts: element ? ElementCatalog.optionsFor(element.id, element.options) : ({})

    radius: Tokens.rounding.extraLarge
    color: Colours.palette.m3surfaceContainer

    layer.enabled: true
    layer.effect: MultiEffect {
        shadowEnabled: true
        blurMax: 16
        shadowColor: Qt.alpha(Colours.palette.m3shadow, 0.6)
    }

    // Swallows presses, so clicking the panel doesn't drop the selection behind it
    MouseArea {
        anchors.fill: parent
    }

    Flickable {
        id: flick

        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: column

            width: flick.width
            spacing: Tokens.spacing.medium

            // Header
            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.medium

                MaterialIcon {
                    text: root.kind?.icon ?? "layers"
                    color: Colours.palette.m3primary
                    fontStyle: Tokens.font.icon.medium
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.kind?.name ?? Tr.tr("Elements")
                    color: Colours.palette.m3onSurface
                    font: Tokens.font.title.large
                    elide: Text.ElideRight
                }

                // Which side of the screen the panel keeps to, for when it's over what's being edited
                IconBtn {
                    icon: root.editor.inspectorOnLeft ? "dock_to_left" : "dock_to_right"
                    onActivated: root.editor.inspectorOnLeft = !root.editor.inspectorOnLeft
                }
            }

            StyledText {
                Layout.fillWidth: true
                visible: !!root.kind
                text: root.kind?.description ?? ""
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.small
                wrapMode: Text.WordWrap
            }

            // ---- With an element selected ----

            Heading {
                visible: !!root.element
                text: Tr.tr("Placement")
            }

            RowLayout {
                Layout.fillWidth: true
                visible: !!root.element
                spacing: Tokens.spacing.large

                // The 3x3 of points the element can be pinned by
                Grid {
                    columns: 3
                    spacing: 4

                    Repeater {
                        model: ["tl", "t", "tr", "l", "c", "r", "bl", "b", "br"]

                        StyledRect {
                            id: point

                            required property string modelData
                            readonly property bool current: (root.element?.anchor ?? "c") === modelData

                            implicitWidth: 22
                            implicitHeight: 22
                            radius: 6
                            color: current ? Colours.palette.m3primary : Colours.tPalette.m3surfaceContainerHighest

                            StateLayer {
                                radius: point.radius
                                onClicked: root.editor.setAnchor(root.index, point.modelData)
                            }
                        }
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Tr.tr("Pinned by this point, so it keeps its place from that side on other screen sizes")
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.medium
                    wrapMode: Text.WordWrap
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: !!root.element
                spacing: Tokens.spacing.small

                EditorButton {
                    Layout.fillWidth: true
                    icon: "align_horizontal_center"
                    text: Tr.tr("Centre across")
                    onActivated: root.editor.centre(root.index, true)
                }

                EditorButton {
                    Layout.fillWidth: true
                    icon: "align_vertical_center"
                    text: Tr.tr("Centre down")
                    onActivated: root.editor.centre(root.index, false)
                }
            }

            Slider {
                visible: !!root.element && !(root.kind?.sized ?? false)
                label: Tr.tr("Size")
                value: root.element?.scale ?? 1
                from: 0.2
                to: 3
                step: 0.05
                display: v => `${Math.round(v * 100)}%`
                onChanged: v => root.editor.update(root.index, {
                        scale: v
                    }, "scale")
            }

            Slider {
                visible: !!root.element && (root.kind?.sized ?? false)
                label: Tr.tr("Width")
                value: root.element?.w ?? 0
                from: 0.001
                to: 1
                step: 0.005
                display: v => `${Math.round(v * 1000) / 10}%`
                onChanged: v => root.editor.update(root.index, {
                        w: v
                    }, "w")
            }

            Slider {
                visible: !!root.element && (root.kind?.sized ?? false)
                label: Tr.tr("Height")
                value: root.element?.h ?? 0
                from: 0.001
                to: 1
                step: 0.005
                display: v => `${Math.round(v * 1000) / 10}%`
                onChanged: v => root.editor.update(root.index, {
                        h: v
                    }, "h")
            }

            Slider {
                visible: !!root.element
                label: Tr.tr("Opacity")
                value: root.element?.opacity ?? 1
                from: 0.05
                to: 1
                step: 0.05
                display: v => `${Math.round(v * 100)}%`
                onChanged: v => root.editor.update(root.index, {
                        opacity: v
                    }, "opacity")
            }

            Choice {
                visible: !!root.element
                label: Tr.tr("Turn")
                value: root.element?.rotation ?? 0
                items: [
                    {
                        value: 0,
                        label: Tr.tr("Upright")
                    },
                    {
                        value: -90,
                        label: Tr.tr("Reads upward")
                    },
                    {
                        value: 90,
                        label: Tr.tr("Reads downward")
                    }
                ]
                onPicked: v => root.editor.update(root.index, {
                        rotation: v
                    })
            }

            Choice {
                visible: !!root.element
                label: Tr.tr("Shows")
                value: root.element?.showOn ?? "always"
                items: [
                    {
                        value: "always",
                        label: Tr.tr("Always")
                    },
                    {
                        value: "rest",
                        label: Tr.tr("Until a key is pressed")
                    },
                    {
                        value: "active",
                        label: Tr.tr("Once signing in")
                    }
                ]
                onPicked: v => root.editor.update(root.index, {
                        showOn: v
                    })
            }

            StyledText {
                Layout.fillWidth: true
                visible: !!root.element && root.element.showOn !== "always" && root.element.showOn !== undefined
                text: Tr.tr("Elements shown until a key is pressed make a curtain: the first key or click swaps them for the ones shown once signing in. Preview either side from the bar at the top.")
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.medium
                wrapMode: Text.WordWrap
            }

            Heading {
                visible: (root.kind?.options ?? []).length > 0
                text: Tr.tr("Options")
            }

            // The kind's own options, each drawn as its type asks
            Repeater {
                model: root.element ? root.kind?.options ?? [] : []

                Loader {
                    id: option

                    required property var modelData

                    Layout.fillWidth: true
                    sourceComponent: ({
                            select: selectOption,
                            toggle: toggleOption,
                            slider: sliderOption,
                            text: textKind
                        })[modelData.type] ?? null

                    Component {
                        id: selectOption

                        Choice {
                            label: option.modelData.label
                            items: option.modelData.items
                            value: root.opts[option.modelData.key]
                            onPicked: v => root.editor.setOption(root.index, option.modelData.key, v)
                        }
                    }

                    Component {
                        id: toggleOption

                        Toggle {
                            label: option.modelData.label
                            checked: !!root.opts[option.modelData.key]
                            onToggledTo: v => root.editor.setOption(root.index, option.modelData.key, v)
                        }
                    }

                    Component {
                        id: sliderOption

                        Slider {
                            label: option.modelData.label
                            value: root.opts[option.modelData.key] ?? option.modelData.from
                            from: option.modelData.from
                            to: option.modelData.to
                            step: option.modelData.step
                            onChanged: v => root.editor.setOption(root.index, option.modelData.key, v, true)
                        }
                    }

                    Component {
                        id: textKind

                        TextOption {
                            label: option.modelData.label
                            value: root.opts[option.modelData.key] ?? ""
                            onCommitted: v => root.editor.setOption(root.index, option.modelData.key, v)
                        }
                    }
                }
            }

            // ---- With nothing selected: the stack of elements ----

            StyledText {
                Layout.fillWidth: true
                visible: !root.element
                text: Tr.tr("Click an element on the screen to change it, drag it to move it, and pull its corner to resize it. Everything but the password field can be removed.")
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.small
                wrapMode: Text.WordWrap
            }

            Heading {
                visible: !root.element
                text: Tr.tr("On top first")
            }

            Repeater {
                model: root.element ? [] : root.editor.elements.map((e, i) => ({
                            element: e,
                            index: i
                        })).reverse()

                StyledRect {
                    id: layer

                    required property var modelData
                    readonly property var layerKind: ElementCatalog.kind(modelData.element.id)
                    readonly property bool hidden: modelData.element.enabled === false

                    Layout.fillWidth: true
                    implicitHeight: 40
                    radius: Tokens.rounding.medium
                    color: Colours.tPalette.m3surfaceContainerHigh

                    StateLayer {
                        radius: layer.radius
                        onClicked: root.editor.selected = layer.modelData.index
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Tokens.padding.medium
                        anchors.rightMargin: Tokens.padding.small
                        spacing: Tokens.spacing.medium

                        MaterialIcon {
                            text: layer.layerKind?.icon ?? "help"
                            color: Colours.palette.m3onSurfaceVariant
                            fontStyle: Tokens.font.icon.small
                            opacity: layer.hidden ? 0.4 : 1
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: layer.layerKind?.name ?? layer.modelData.element.id
                            color: Colours.palette.m3onSurface
                            font: Tokens.font.body.medium
                            opacity: layer.hidden ? 0.4 : 1
                            elide: Text.ElideRight
                        }

                        // Hidden rather than removed, to try the screen without it
                        IconBtn {
                            visible: layer.modelData.element.id !== "password"
                            icon: layer.hidden ? "visibility_off" : "visibility"
                            onActivated: root.editor.update(layer.modelData.index, {
                                    enabled: layer.hidden
                                })
                        }
                    }
                }
            }

            Heading {
                visible: !root.element
                text: Tr.tr("Keys")
            }

            StyledText {
                Layout.fillWidth: true
                visible: !root.element
                text: Tr.tr("Arrows nudge the selected element, Shift+arrows by ten. Delete removes it, Ctrl+D copies it. Ctrl+Z and Ctrl+Shift+Z undo and redo, Ctrl+S saves, Esc steps back out.")
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.medium
                wrapMode: Text.WordWrap
            }
        }
    }

    component Heading: StyledText {
        Layout.fillWidth: true
        Layout.topMargin: Tokens.spacing.medium
        color: Colours.palette.m3primary
        font: Tokens.font.label.large
    }

    component IconBtn: StyledRect {
        id: iconBtn

        required property string icon

        signal activated

        implicitWidth: 32
        implicitHeight: 32
        radius: Tokens.rounding.full
        color: "transparent"

        MaterialIcon {
            anchors.centerIn: parent
            text: iconBtn.icon
            color: Colours.palette.m3onSurfaceVariant
            fontStyle: Tokens.font.icon.small
        }

        StateLayer {
            radius: iconBtn.radius
            onClicked: iconBtn.activated()
        }
    }

    // A labelled choice of a few values as a wrap of chips, the current one filled
    component Choice: ColumnLayout {
        id: choice

        property string label
        property var items: []
        property var value

        signal picked(value: var)

        Layout.fillWidth: true
        spacing: Tokens.spacing.small

        StyledText {
            text: choice.label
            color: Colours.palette.m3onSurface
            font: Tokens.font.body.medium
        }

        Flow {
            Layout.fillWidth: true
            spacing: Tokens.spacing.extraSmall

            Repeater {
                model: choice.items

                StyledRect {
                    id: chip

                    required property var modelData
                    readonly property bool current: choice.value === modelData.value

                    implicitWidth: chipText.implicitWidth + Tokens.padding.medium * 2
                    implicitHeight: 30
                    radius: Tokens.rounding.full
                    color: current ? Colours.palette.m3secondaryContainer : Colours.tPalette.m3surfaceContainerHigh
                    border.width: current ? 0 : 1
                    border.color: Qt.alpha(Colours.palette.m3outline, 0.4)

                    StyledText {
                        id: chipText

                        anchors.centerIn: parent
                        text: chip.modelData.label
                        color: chip.current ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.label.large
                    }

                    StateLayer {
                        radius: chip.radius
                        onClicked: choice.picked(chip.modelData.value)
                    }
                }
            }
        }
    }

    component Toggle: RowLayout {
        id: toggle

        property string label
        property bool checked

        signal toggledTo(value: bool)

        Layout.fillWidth: true
        spacing: Tokens.spacing.medium

        StyledText {
            Layout.fillWidth: true
            text: toggle.label
            color: Colours.palette.m3onSurface
            font: Tokens.font.body.medium
            wrapMode: Text.WordWrap
        }

        StyledSwitch {
            checked: toggle.checked
            onToggled: {
                toggle.toggledTo(checked);
                // Back to following the element, which the click took over from
                checked = Qt.binding(() => toggle.checked);
            }
        }
    }

    // A labelled slider over [from, to], snapped to step, its value shown beside the label
    component Slider: ColumnLayout {
        id: slider

        property string label
        property real value
        property real from: 0
        property real to: 1
        property real step: 0.01
        property var display: v => `${Math.round(v * 100) / 100}`

        signal changed(value: real)

        Layout.fillWidth: true
        spacing: Tokens.spacing.extraSmall

        RowLayout {
            Layout.fillWidth: true

            StyledText {
                Layout.fillWidth: true
                text: slider.label
                color: Colours.palette.m3onSurface
                font: Tokens.font.body.medium
            }

            StyledText {
                text: slider.display(slider.value)
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.large
            }
        }

        StyledSlider {
            Layout.fillWidth: true
            implicitHeight: Tokens.padding.medium * 2
            radius: Tokens.rounding.small
            value: (slider.value - slider.from) / Math.max(0.0001, slider.to - slider.from)
            onInteraction: v => {
                const raw = slider.from + v * (slider.to - slider.from);
                const snapped = Math.round(raw / slider.step) * slider.step;
                slider.changed(Math.round(Math.max(slider.from, Math.min(slider.to, snapped)) * 10000) / 10000);
            }
        }
    }

    component TextOption: ColumnLayout {
        id: textOption

        property string label
        property string value

        signal committed(value: string)

        Layout.fillWidth: true
        spacing: Tokens.spacing.small

        StyledText {
            text: textOption.label
            color: Colours.palette.m3onSurface
            font: Tokens.font.body.medium
        }

        StyledTextField {
            Layout.fillWidth: true
            verticalPadding: Tokens.padding.small
            text: textOption.value
            onEditingFinished: {
                if (text !== textOption.value)
                    textOption.committed(text);
            }
        }
    }
}
