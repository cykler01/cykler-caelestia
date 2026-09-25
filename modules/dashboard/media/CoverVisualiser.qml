pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import Quickshell
import M3Shapes
import Caelestia.Config
import Caelestia.Services
import qs.components
import qs.components.widgets
import qs.services

Item {
    id: root

    required property MediaSource source

    readonly property real centerX: width / 2
    readonly property real centerY: height / 2
    readonly property real spacing: Tokens.spacing.medium
    readonly property real maxMagnitude: (implicitWidth - cover.implicitWidth) / 2 - spacing

    ServiceRef {
        service: PowerSaving.pauseVisualisers || !PowerSaving.animations ? null : Audio.cava
    }

    readonly property int barCount: GlobalConfig.services.visualiserBars
    // The bars read these snapshots rather than the analyser and the cover's rotation directly. Reading those
    // straight made every bar recompute (and the whole ring be rebuilt) on each analyser update and on every frame
    // of the cover's spin; the timer refreshes the levels at the shared decorative rate, and the edge distances only
    // when the cover has turned far enough for them to differ.
    property var levels: Array(barCount).fill(1e-2)
    property var edges: Array(barCount).fill(0)
    property real edgesAt: -1000

    function refreshEdges(): void {
        const rot = cover.shape.rotation;
        if (Math.abs(rot - edgesAt) < 3 && edges.length === barCount)
            return;

        edgesAt = rot;
        const next = new Array(barCount);
        for (let i = 0; i < barCount; i++)
            next[i] = cover.shape.distanceAtAngle(i * 360 / barCount + 90) + spacing + (360 / barCount - root.Tokens.spacing.small / 4) / 2;
        edges = next;
    }

    Timer {
        interval: PowerSaving.frameMs
        repeat: true
        triggeredOnStart: true
        running: root.visible
        onTriggered: {
            root.refreshEdges();

            const live = !PowerSaving.pauseVisualisers && PowerSaving.animations;
            const values = Audio.cava.values;
            const next = new Array(root.barCount);
            for (let i = 0; i < root.barCount; i++)
                next[i] = live ? Math.max(1e-2, Math.min(1, values[i] ?? 0)) : 1e-2;
            root.levels = next;
        }
    }

    Shape {
        anchors.fill: parent
        asynchronous: true
        preferredRendererType: Shape.CurveRenderer
        data: bars.instances
    }

    Variants {
        id: bars

        model: Array.from({
            length: GlobalConfig.services.visualiserBars
        }, (_, i) => i)

        ShapePath {
            id: bar

            required property int modelData
            readonly property real value: root.levels[modelData] ?? 1e-2

            readonly property real angle: modelData * 2 * Math.PI / GlobalConfig.services.visualiserBars
            readonly property real dist: shapeEdgeDist + value * root.maxMagnitude
            readonly property real shapeEdgeDist: root.edges[modelData] ?? 0
            readonly property real cos: Math.cos(angle)
            readonly property real sin: Math.sin(angle)

            asynchronous: true
            capStyle: root.Tokens.rounding.scale === 0 ? ShapePath.SquareCap : ShapePath.RoundCap
            strokeWidth: 360 / GlobalConfig.services.visualiserBars - root.Tokens.spacing.small / 4
            strokeColor: Colours.palette.m3primary

            startX: root.centerX + shapeEdgeDist * cos
            startY: root.centerY + shapeEdgeDist * sin

            PathLine {
                x: root.centerX + bar.dist * bar.cos
                y: root.centerY + bar.dist * bar.sin
            }

            Behavior on strokeColor {
                CAnim {}
            }
        }
    }

    CoverArt {
        id: cover

        anchors.centerIn: parent
        shape.shape: MaterialShape.Cookie9Sided
        source: root.source.coverSource
        spinning: root.source.isPlaying
        implicitWidth: Tokens.sizes.dashboard.mediaCoverArtSize
        implicitHeight: Tokens.sizes.dashboard.mediaCoverArtSize
    }
}
