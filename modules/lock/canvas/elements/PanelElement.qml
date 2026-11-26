import QtQuick
import QtQuick.Effects
import Caelestia.Config
import qs.components
import qs.services

// A card to set other elements on: the surface colour, a container shade, the accent, a wash of
// the accents, or nothing but its outline. Optionally with a shadow, an outline, accent hairlines
// along its top and bottom (a band across the screen), and a window's title bar with its three
// buttons (a terminal window)
Item {
    id: root

    property real s: 1

    property var lock: null
    property var opts: ({})

    readonly property real radius: Math.min((opts.radius ?? 36) * s, Math.min(width, height) / 2)
    readonly property real barHeight: 44 * s

    StyledRect {
        id: fill

        anchors.fill: parent
        radius: root.radius
        color: ({
                surface: Colours.tPalette.m3surface,
                container: Colours.tPalette.m3surfaceContainer,
                high: Colours.tPalette.m3surfaceContainerHigh,
                primary: Colours.tPalette.m3primaryContainer,
                none: "transparent"
            })[root.opts.colour] ?? Colours.tPalette.m3surface
        border.width: (root.opts.border ?? false) ? Math.max(1, root.s) : 0
        border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.6)
        gradient: root.opts.colour === "gradient" ? wash : null

        layer.enabled: (root.opts.shadow ?? true) && root.opts.colour !== "none"
        layer.effect: MultiEffect {
            shadowEnabled: true
            blurMax: 20
            shadowColor: Qt.alpha(Colours.palette.m3shadow, 0.6)
        }
    }

    Gradient {
        id: wash

        orientation: Gradient.Horizontal

        GradientStop {
            position: 0
            color: Colours.palette.m3primaryContainer
        }

        GradientStop {
            position: 1
            color: Colours.palette.m3tertiaryContainer
        }
    }

    Repeater {
        model: (root.opts.edges ?? false) ? [0, 1] : []

        Rectangle {
            required property int modelData

            x: root.radius
            width: root.width - root.radius * 2
            y: modelData === 0 ? 0 : root.height - height
            height: Math.max(1, 2 * root.s)
            color: Qt.alpha(Colours.palette.m3primary, 0.5)
        }
    }

    StyledRect {
        visible: root.opts.titleBar ?? false
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: root.barHeight
        topLeftRadius: root.radius
        topRightRadius: root.radius
        color: Colours.tPalette.m3surfaceContainer

        Row {
            anchors.left: parent.left
            anchors.leftMargin: Tokens.padding.large * root.s
            anchors.verticalCenter: parent.verticalCenter
            spacing: Tokens.spacing.small * root.s

            Repeater {
                model: [Colours.palette.m3error, Colours.palette.m3tertiary, Colours.palette.m3primary]

                Rectangle {
                    required property color modelData

                    width: 13 * root.s
                    height: width
                    radius: width / 2
                    color: Qt.alpha(modelData, 0.85)
                }
            }
        }
    }
}
