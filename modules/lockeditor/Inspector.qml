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

                // Back to the list of elements
                IconBtn {
                    visible: !!root.element || root.editor.multiple
                    icon: "arrow_back"
                    onActivated: root.editor.clearPick()
                }

                MaterialIcon {
                    visible: !root.element && !root.editor.multiple
                    text: root.kind?.icon ?? "layers"
                    color: Colours.palette.m3primary
                    fontStyle: Tokens.font.icon.medium
                }

                StyledText {
                    Layout.fillWidth: true
                    // TRANSLATORS: %1 = how many elements are picked
                    text: root.editor.multiple ? Tr.tr("%1 picked").arg(root.editor.selection.length) : root.kind?.name ?? Tr.tr("Elements")
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

            // ---- With several picked ----

            StyledText {
                Layout.fillWidth: true
                visible: root.editor.multiple
                text: root.editor.selectionGrouped ? Tr.tr("A group: clicking any of it picks all of it, and it moves as one. Double-click one to change it on its own.") : Tr.tr("They move together while picked. Group them to keep them together.")
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.small
                wrapMode: Text.WordWrap
            }

            GridLayout {
                Layout.fillWidth: true
                visible: root.editor.multiple
                columns: 2
                rowSpacing: Tokens.spacing.small
                columnSpacing: Tokens.spacing.small

                EditorButton {
                    Layout.fillWidth: true
                    Layout.columnSpan: 2
                    icon: root.editor.selectionGrouped ? "ungroup" : "group_work"
                    text: root.editor.selectionGrouped ? Tr.tr("Ungroup") : Tr.tr("Group")
                    tone: root.editor.selectionGrouped ? "tonal" : "primary"
                    onActivated: {
                        if (root.editor.selectionGrouped)
                            root.editor.ungroupSelection();
                        else
                            root.editor.groupSelection();
                    }
                }

                EditorButton {
                    Layout.fillWidth: true
                    icon: "content_copy"
                    text: Tr.tr("Duplicate")
                    onActivated: root.editor.duplicateSelection()
                }

                EditorButton {
                    Layout.fillWidth: true
                    icon: "delete"
                    text: Tr.tr("Remove")
                    tone: "error"
                    onActivated: root.editor.removeSelection()
                }
            }

            Heading {
                visible: root.editor.multiple
                text: Tr.tr("Mirror")
            }

            RowLayout {
                Layout.fillWidth: true
                visible: root.editor.multiple
                spacing: Tokens.spacing.small

                EditorButton {
                    Layout.fillWidth: true
                    icon: "flip"
                    text: Tr.tr("Other side")
                    onActivated: root.editor.mirrorSelection(false)
                }

                EditorButton {
                    Layout.fillWidth: true
                    icon: "swap_horiz"
                    text: Tr.tr("In place")
                    onActivated: root.editor.mirrorSelection(true)
                }
            }

            Heading {
                visible: root.editor.multiple
                text: Tr.tr("Line up")
            }

            // Along the sides and middles of the box round them all, then spaced out evenly
            Flow {
                Layout.fillWidth: true
                visible: root.editor.multiple
                spacing: Tokens.spacing.small

                Repeater {
                    model: [
                        {
                            icon: "align_horizontal_left",
                            how: "left"
                        },
                        {
                            icon: "align_horizontal_center",
                            how: "hcentre"
                        },
                        {
                            icon: "align_horizontal_right",
                            how: "right"
                        },
                        {
                            icon: "align_vertical_top",
                            how: "top"
                        },
                        {
                            icon: "align_vertical_center",
                            how: "vcentre"
                        },
                        {
                            icon: "align_vertical_bottom",
                            how: "bottom"
                        },
                        {
                            icon: "horizontal_distribute",
                            how: "across"
                        },
                        {
                            icon: "vertical_distribute",
                            how: "down"
                        }
                    ]

                    EditorButton {
                        id: alignButton

                        required property var modelData
                        readonly property bool spreads: modelData.how === "across" || modelData.how === "down"

                        icon: modelData.icon
                        // Spacing out needs a first, a last and something between
                        disabled: alignButton.spreads && root.editor.selection.length < 3
                        onActivated: {
                            if (alignButton.spreads)
                                root.editor.distributeSelection(alignButton.modelData.how === "across");
                            else
                                root.editor.alignSelection(alignButton.modelData.how);
                        }
                    }
                }
            }

            Heading {
                visible: root.editor.multiple
                text: Tr.tr("Picked")
            }

            // Each of them, top layer first, to change one on its own
            Repeater {
                model: root.editor.multiple ? root.editor.selection.slice().sort((a, b) => b - a) : []

                StyledRect {
                    id: pickedRow

                    required property int modelData
                    readonly property var el: root.editor.elements[modelData]
                    readonly property var rowKind: ElementCatalog.kind(el?.id ?? "")
                    readonly property string detail: ElementCatalog.summary(el)

                    Layout.fillWidth: true
                    implicitHeight: 44
                    radius: Tokens.rounding.medium
                    color: Colours.palette.m3surfaceContainerHighest

                    StateLayer {
                        radius: pickedRow.radius
                        onClicked: root.editor.pickOnly(pickedRow.modelData)
                        onContainsMouseChanged: {
                            if (containsMouse)
                                root.editor.hovered = pickedRow.modelData;
                            else if (root.editor.hovered === pickedRow.modelData)
                                root.editor.hovered = -1;
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Tokens.padding.medium
                        anchors.rightMargin: Tokens.padding.medium
                        spacing: Tokens.spacing.medium

                        MaterialIcon {
                            text: pickedRow.rowKind?.icon ?? "help"
                            color: Colours.palette.m3primary
                            fontStyle: Tokens.font.icon.small
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: pickedRow.detail !== "" ? `${pickedRow.rowKind?.name ?? ""} · ${pickedRow.detail}` : pickedRow.rowKind?.name ?? ""
                            color: Colours.palette.m3onSurface
                            font: Tokens.font.body.medium
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            // ---- With an element selected ----

            // One member of a group, picked on its own
            RowLayout {
                Layout.fillWidth: true
                visible: !!root.element && (root.element.options?.group ?? "") !== ""
                spacing: Tokens.spacing.small

                EditorButton {
                    Layout.fillWidth: true
                    icon: "select_all"
                    text: Tr.tr("Pick its group")
                    onActivated: root.editor.pick(root.index, false)
                }

                EditorButton {
                    Layout.fillWidth: true
                    icon: "ungroup"
                    text: Tr.tr("Take out")
                    onActivated: root.editor.ungroupSelection()
                }
            }

            // A panel, with whatever's sitting on it
            EditorButton {
                Layout.fillWidth: true
                visible: root.element?.id === "panel" && (root.element.options?.group ?? "") === ""
                icon: "group_work"
                text: Tr.tr("Group with what's on it")
                onActivated: root.editor.groupWithContents(root.index)
            }

            // What the floating strip used to have: copy, restack and remove
            GridLayout {
                Layout.fillWidth: true
                visible: !!root.element
                columns: 2
                rowSpacing: Tokens.spacing.small
                columnSpacing: Tokens.spacing.small

                EditorButton {
                    Layout.fillWidth: true
                    icon: "content_copy"
                    text: Tr.tr("Duplicate")
                    disabled: root.element?.id === "password"
                    onActivated: root.editor.duplicate(root.index)
                }

                EditorButton {
                    Layout.fillWidth: true
                    icon: "delete"
                    text: Tr.tr("Remove")
                    tone: "error"
                    disabled: root.element?.id === "password"
                    onActivated: root.editor.remove(root.index)
                }

                EditorButton {
                    Layout.fillWidth: true
                    icon: "flip_to_front"
                    text: Tr.tr("Forward")
                    disabled: root.index >= root.editor.elements.length - 1
                    onActivated: root.editor.restack(root.index, 1)
                }

                EditorButton {
                    Layout.fillWidth: true
                    icon: "flip_to_back"
                    text: Tr.tr("Backward")
                    disabled: root.index <= 0
                    onActivated: root.editor.restack(root.index, -1)
                }
            }

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

                            implicitWidth: 24
                            implicitHeight: 24
                            radius: 7
                            color: current ? Colours.palette.m3primary : "transparent"
                            border.width: current ? 0 : 1.5
                            border.color: Colours.palette.m3outline

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
                            text: textKind,
                            multi: multiOption
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
                        id: multiOption

                        Multi {
                            label: option.modelData.label
                            items: option.modelData.items
                            // Only the widget column has one; what it shows until it's been given its own list
                            value: option.modelData.key === "widgets" ? ElementCatalog.widgetsFor(root.opts) : root.opts[option.modelData.key] ?? []
                            onChangedTo: v => root.editor.setOption(root.index, option.modelData.key, v)
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
                visible: !root.element && !root.editor.multiple
                text: Tr.tr("Click an element on the screen, or in the list below, to change it. Drag it to move it and pull its round corner to resize it. While snapping is on it lines up with the screen's middle, its margins, the other elements and the grid as it comes near them.")
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.small
                wrapMode: Text.WordWrap
            }

            Heading {
                visible: !root.element && !root.editor.multiple
                text: Tr.tr("Elements, top layer first")
            }

            Repeater {
                model: root.element || root.editor.multiple ? [] : root.editor.elements.map((e, i) => ({
                            element: e,
                            index: i
                        })).reverse()

                StyledRect {
                    id: layer

                    required property var modelData
                    readonly property var layerKind: ElementCatalog.kind(modelData.element.id)
                    readonly property bool hidden: modelData.element.enabled === false
                    readonly property string detail: ElementCatalog.summary(modelData.element)

                    Layout.fillWidth: true
                    implicitHeight: Math.max(48, layerText.implicitHeight + Tokens.padding.small * 2)
                    radius: Tokens.rounding.medium
                    color: Colours.palette.m3surfaceContainerHighest

                    // Hovering a row outlines its element on the screen, so the list can be matched
                    // to what's drawn
                    StateLayer {
                        radius: layer.radius
                        onClicked: root.editor.selected = layer.modelData.index
                        onContainsMouseChanged: {
                            if (containsMouse)
                                root.editor.hovered = layer.modelData.index;
                            else if (root.editor.hovered === layer.modelData.index)
                                root.editor.hovered = -1;
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Tokens.padding.medium
                        anchors.rightMargin: Tokens.padding.small
                        spacing: Tokens.spacing.medium

                        MaterialIcon {
                            text: layer.layerKind?.icon ?? "help"
                            color: Colours.palette.m3primary
                            fontStyle: Tokens.font.icon.small
                            opacity: layer.hidden ? 0.4 : 1
                        }

                        ColumnLayout {
                            id: layerText

                            Layout.fillWidth: true
                            spacing: 0
                            opacity: layer.hidden ? 0.4 : 1

                            StyledText {
                                Layout.fillWidth: true
                                text: layer.layerKind?.name ?? layer.modelData.element.id
                                color: Colours.palette.m3onSurface
                                font: Tokens.font.body.medium
                                elide: Text.ElideRight
                            }

                            StyledText {
                                Layout.fillWidth: true
                                visible: text !== ""
                                text: layer.hidden ? Tr.tr("Hidden") : layer.detail
                                color: Colours.palette.m3onSurfaceVariant
                                font: Tokens.font.label.medium
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }
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
                visible: !root.element && !root.editor.multiple
                text: Tr.tr("Keys")
            }

            StyledText {
                Layout.fillWidth: true
                visible: !root.element && !root.editor.multiple
                text: Tr.tr("Shift+click picks more than one, and so does dragging a box over empty space; Ctrl+A picks everything. Ctrl+G groups what's picked and Ctrl+Shift+G ungroups it. Arrows move it a grid step (ten pixels with snapping off) and Shift+arrows a single pixel, and holding Ctrl while dragging places it freely. Delete removes it and Ctrl+D copies it. Ctrl+Z and Ctrl+Shift+Z undo and redo, Ctrl+S saves, and Esc steps back out.")
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
                    implicitHeight: 32
                    radius: Tokens.rounding.full
                    color: current ? Colours.palette.m3primary : "transparent"
                    border.width: current ? 0 : 1
                    border.color: Colours.palette.m3outline

                    StyledText {
                        id: chipText

                        anchors.centerIn: parent
                        text: chip.modelData.label
                        color: chip.current ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
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

    // Several of a list picked at once, in the order they were picked: a wrap of chips, the picked
    // ones filled and numbered. Picking one adds it at the end; picking it again takes it out
    component Multi: ColumnLayout {
        id: multi

        property string label
        property var items: []
        property var value: []

        signal changedTo(value: var)

        Layout.fillWidth: true
        spacing: Tokens.spacing.small

        StyledText {
            Layout.fillWidth: true
            text: multi.label
            color: Colours.palette.m3onSurface
            font: Tokens.font.body.medium
            wrapMode: Text.WordWrap
        }

        Flow {
            Layout.fillWidth: true
            spacing: Tokens.spacing.extraSmall

            Repeater {
                model: multi.items

                StyledRect {
                    id: pick

                    required property var modelData
                    readonly property int position: multi.value.indexOf(modelData.value)
                    readonly property bool current: position >= 0

                    implicitWidth: pickRow.implicitWidth + Tokens.padding.medium * 2
                    implicitHeight: 32
                    radius: Tokens.rounding.full
                    color: current ? Colours.palette.m3primary : "transparent"
                    border.width: current ? 0 : 1
                    border.color: Colours.palette.m3outline

                    Row {
                        id: pickRow

                        anchors.centerIn: parent
                        spacing: Tokens.spacing.small

                        StyledText {
                            visible: pick.current
                            text: pick.position + 1
                            color: Colours.palette.m3onPrimary
                            font: Tokens.font.label.large
                        }

                        StyledText {
                            text: pick.modelData.label
                            color: pick.current ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                            font: Tokens.font.label.large
                        }
                    }

                    StateLayer {
                        radius: pick.radius
                        onClicked: multi.changedTo(pick.current ? multi.value.filter(v => v !== pick.modelData.value) : [...multi.value, pick.modelData.value])
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
