pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import M3Shapes
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.components.effects
import qs.components.images
import qs.services

Item {
    id: root

    readonly property alias shape: shape

    property bool hadPrevious
    property color fallbackColour: Colours.layer(Colours.palette.m3surfaceContainerHighest, 2)
    // Defaults to the active mpris player, but any image source can be shown instead
    property string source: Players.getArtUrl(Players.active)
    property bool spinning: Players.active?.isPlaying ?? false

    // Slight glow to separate from bg
    layer.enabled: true
    layer.effect: MultiEffect {
        shadowEnabled: true
        blurMax: 1
        shadowColor: Colours.palette.m3outline
        shadowOpacity: 0.3
    }

    Behavior on fallbackColour {
        CAnim {}
    }

    Item {
        id: shapeWrapper

        anchors.fill: parent
        layer.enabled: true
        opacity: root.fallbackColour.a

        MaterialShape {
            id: shape

            implicitSize: root.width
            shape: MaterialShape.Cookie12Sided
            color: Qt.alpha(root.fallbackColour, 1)

        }

        // One turn every 23.5 s, stepped at the shared decorative rate rather than animated at the screen's refresh
        // rate. It also holds still when animations are off in Power & battery, or while it isn't on screen.
        Timer {
            property real last

            interval: PowerSaving.frameMs
            repeat: true
            running: root.spinning && PowerSaving.animations && !PowerSaving.onBattery && root.visible
            onRunningChanged: last = Date.now()
            onTriggered: {
                const now = Date.now();
                shape.rotation = (shape.rotation - (now - last) / 23500 * 360) % 360;
                last = now;
            }
        }
    }

    MaterialIcon {
        anchors.centerIn: parent

        grade: 200
        text: image.status === Image.Error ? "broken_image" : "art_track"
        color: Colours.palette.m3onSurfaceVariant
        fontStyle: Tokens.font.icon.size((parent.width * 0.35) || 1).build()
        opacity: image.status === Image.Null || image.status === Image.Error ? 1 : 0
        animate: true

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }
    }

    Loader {
        anchors.centerIn: parent
        asynchronous: true
        // Not while animations are off in Power & battery: the indicator loops for as long as a cover is loading, and
        // a cover that never arrives (offline) would otherwise keep the screen redrawing indefinitely
        active: opacity > 0 && PowerSaving.animations
        opacity: image.status === Image.Loading ? 1 : 0

        sourceComponent: LoadingIndicator {
            implicitSize: root.width * 0.3
            color: Colours.palette.m3primaryContainer
        }

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }
    }

    FadeImage {
        id: image

        anchors.fill: parent

        source: root.source

        layer.enabled: true
        layer.effect: Mask {
            maskSource: shapeWrapper
        }
    }
}
