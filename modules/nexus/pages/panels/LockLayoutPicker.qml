pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.modules.lock.layouts
import qs.modules.nexus.common

// The lock screen's arrangement (Config.lock.layout) as a row of tiles, each with a small sketch
// of where things go, rather than a dropdown of names that say nothing about what they look like.
// The sketches mirror themselves with the panel side setting, so they match what will show
ConnectedRect {
    id: root

    readonly property string current: {
        return LayoutRegistry.resolve(Config.lock.layout ?? "card");
    }
    readonly property bool panelRight: (Config.lock.panelSide ?? "right") !== "left"

    readonly property var layouts: [
        {
            id: "card",
            name: Tr.tr("Classic")
        },
        {
            id: "split",
            name: Tr.tr("Split")
        },
        {
            id: "sidebar",
            name: Tr.tr("Sidebar")
        },
        {
            id: "minimal",
            name: Tr.tr("Minimal")
        },
        {
            id: "stage",
            name: Tr.tr("Stage")
        },
        {
            id: "curtain",
            name: Tr.tr("Curtain")
        },
        {
            id: "watch",
            name: Tr.tr("Watch face")
        },
        {
            id: "band",
            name: Tr.tr("Band")
        },
        {
            id: "console",
            name: Tr.tr("Console")
        },
        {
            id: "fuzzy",
            name: Tr.tr("Fuzzy clock")
        }
    ]

    searchLabel: Tr.tr("Layout")
    Layout.fillWidth: true
    implicitHeight: grid.implicitHeight + Tokens.padding.large * 2

    GridLayout {
        id: grid

        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        columns: width > 720 ? 5 : width > 440 ? 3 : 2
        rowSpacing: Tokens.spacing.medium
        columnSpacing: Tokens.spacing.medium

        Repeater {
            model: root.layouts

            Tile {}
        }
    }

    component Tile: StyledRect {
        id: tile

        required property var modelData
        readonly property bool selected: root.current === modelData.id

        Layout.fillWidth: true
        Layout.preferredWidth: 1
        implicitHeight: tileColumn.implicitHeight + Tokens.padding.medium * 2
        radius: selected ? Tokens.rounding.largeIncreased : Tokens.rounding.medium
        color: selected ? Colours.palette.m3secondaryContainer : Colours.tPalette.m3surfaceContainerHigh

        Behavior on radius {
            Anim {
                type: Anim.SlowEffects
            }
        }

        StateLayer {
            topLeftRadius: parent.radius
            topRightRadius: parent.radius
            bottomLeftRadius: parent.radius
            bottomRightRadius: parent.radius
            onClicked: GlobalConfig.lock.layout = tile.modelData.id
        }

        ColumnLayout {
            id: tileColumn

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Tokens.padding.medium
            spacing: Tokens.spacing.small

            Sketch {
                Layout.fillWidth: true
                Layout.preferredHeight: width * 10 / 16
                kind: tile.modelData.id
                selected: tile.selected
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.extraSmall

                StyledText {
                    Layout.fillWidth: true
                    text: tile.modelData.name
                    color: tile.selected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                    font: Tokens.font.body.builders.medium.weight(Font.DemiBold).build()
                    elide: Text.ElideRight
                }

                MaterialIcon {
                    text: "check_circle"
                    fill: 1
                    color: Colours.palette.m3primary
                    fontStyle: Tokens.font.icon.small
                    opacity: tile.selected ? 1 : 0

                    Behavior on opacity {
                        Anim {
                            type: Anim.DefaultEffects
                        }
                    }
                }
            }
        }
    }

    // A screen in miniature: the wallpaper as a tinted rect, with blocks where the clock, login
    // and widgets go. Coordinates are fractions of the screen so it scales with the tile
    component Sketch: StyledRect {
        id: sketch

        required property string kind
        required property bool selected

        readonly property color ink: selected ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
        readonly property color card: Qt.alpha(ink, 0.22)
        readonly property color solid: Qt.alpha(ink, 0.8)

        // [x, y, w, h, kind] with x measured from the panel edge's opposite side; mirrored for a
        // left-hand panel. kind 0 = card, 1 = solid (clock digits, field), 2 = round card (dial, avatar)
        readonly property var blocks: ({
                card: [[0.12, 0.14, 0.76, 0.72, 0], [0.16, 0.2, 0.2, 0.26, 0], [0.16, 0.5, 0.2, 0.3, 0], [0.64, 0.2, 0.2, 0.3, 0], [0.64, 0.54, 0.2, 0.26, 0], [0.42, 0.24, 0.16, 0.1, 1], [0.44, 0.6, 0.12, 0.05, 1]],
                split: [[0.07, 0.3, 0.13, 0.13, 1], [0.07, 0.46, 0.15, 0.13, 1], [0.07, 0.63, 0.12, 0.03, 1], [0.5, 0.2, 0.2, 0.62, 0], [0.73, 0.2, 0.2, 0.3, 0], [0.76, 0.4, 0.14, 0.04, 1], [0.73, 0.54, 0.2, 0.13, 0], [0.73, 0.7, 0.2, 0.12, 0]],
                sidebar: [[0.66, 0.04, 0.31, 0.92, 0], [0.71, 0.1, 0.21, 0.08, 1], [0.73, 0.3, 0.17, 0.04, 1], [0.7, 0.4, 0.23, 0.2, 0], [0.7, 0.63, 0.23, 0.2, 0], [0.06, 0.08, 0.18, 0.05, 0]],
                minimal: [[0.3, 0.26, 0.4, 0.16, 1], [0.38, 0.46, 0.24, 0.04, 1], [0.44, 0.6, 0.12, 0.05, 1], [0.36, 0.7, 0.28, 0.06, 0]],
                stage: [[0.06, 0.07, 0.12, 0.04, 0], [0.76, 0.07, 0.18, 0.04, 0], [0.4, 0.1, 0.2, 0.03, 1], [0.32, 0.16, 0.36, 0.14, 1], [0.47, 0.62, 0.06, 0.096, 2], [0.42, 0.76, 0.16, 0.05, 1], [0.44, 0.86, 0.12, 0.04, 0]],
                curtain: [[0.06, 0.52, 0.34, 0.14, 1], [0.06, 0.71, 0.22, 0.04, 1], [0.06, 0.79, 0.14, 0.04, 0], [0.76, 0.88, 0.18, 0.04, 0], [0.4, 0.9, 0.2, 0.025, 1]],
                watch: [[0.76, 0.07, 0.18, 0.04, 0], [0.4, 0.1, 0.2, 0.32, 2], [0.495, 0.15, 0.01, 0.11, 1], [0.49, 0.245, 0.02, 0.032, 1], [0.37, 0.48, 0.08, 0.045, 0], [0.46, 0.48, 0.08, 0.045, 0], [0.55, 0.48, 0.08, 0.045, 0], [0.38, 0.6, 0.04, 0.064, 2], [0.44, 0.61, 0.18, 0.05, 1], [0.84, 0.88, 0.1, 0.04, 0]],
                band: [[0.0, 0.37, 1.0, 0.27, 0], [0.07, 0.45, 0.18, 0.1, 1], [0.3, 0.44, 0.17, 0.03, 1], [0.3, 0.5, 0.12, 0.03, 1], [0.3, 0.56, 0.08, 0.025, 1], [0.62, 0.46, 0.05, 0.08, 2], [0.69, 0.475, 0.23, 0.05, 1], [0.76, 0.07, 0.18, 0.04, 0]],
                console: [[0.2, 0.14, 0.6, 0.62, 0], [0.2, 0.14, 0.6, 0.06, 0], [0.24, 0.25, 0.34, 0.025, 1], [0.24, 0.33, 0.2, 0.025, 1], [0.24, 0.38, 0.26, 0.025, 1], [0.24, 0.43, 0.18, 0.025, 1], [0.24, 0.52, 0.24, 0.025, 1], [0.24, 0.645, 0.08, 0.03, 1], [0.34, 0.635, 0.42, 0.05, 0], [0.44, 0.82, 0.12, 0.04, 0]],
                fuzzy: [[0.06, 0.07, 0.12, 0.04, 0], [0.76, 0.07, 0.18, 0.04, 0], [0.07, 0.24, 0.6, 0.11, 1], [0.07, 0.38, 0.36, 0.11, 1], [0.07, 0.54, 0.26, 0.03, 1], [0.07, 0.8, 0.04, 0.064, 2], [0.13, 0.81, 0.2, 0.05, 1], [0.84, 0.88, 0.1, 0.04, 0]]
            })[kind] ?? []
        readonly property bool mirror: LayoutRegistry.isSided(kind) && !root.panelRight

        radius: Tokens.rounding.small
        color: Qt.alpha(Colours.palette.m3onSurface, 0.06)
        clip: true

        Repeater {
            model: sketch.blocks

            Rectangle {
                required property var modelData

                x: (sketch.mirror ? 1 - modelData[0] - modelData[2] : modelData[0]) * sketch.width
                y: modelData[1] * sketch.height
                width: modelData[2] * sketch.width
                height: modelData[3] * sketch.height
                radius: Math.min(width, height) * (modelData[4] === 2 ? 0.5 : modelData[4] === 1 ? 0.3 : 0.2)
                color: modelData[4] === 1 ? sketch.solid : sketch.card

                Behavior on x {
                    Anim {}
                }
            }
        }
    }
}
