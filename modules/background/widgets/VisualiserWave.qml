pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import Caelestia.Config
import qs.components
import qs.services

// The visualiser's wave: the same spectrum as the bars, drawn as one smooth filled curve. A second curve
// sits behind it in the tertiary colour and follows the levels more slowly, so a beat shows as the front
// wave pulling ahead of the back one and the two settling together again
Item {
    id: root

    required property var levels
    required property int barCount
    // NOTE(fork): just the front curve's outline, without its fill or the slower curve behind it
    // (the floor equalizer's line style)
    property bool outlineOnly: false
    // NOTE(fork): how slowly both curves ease towards the levels, as a multiple of their own
    // rates - 1 as they always were, 0 straight onto every reading (the floor equalizer's
    // smoothness setting)
    property real smoothing: 1
    // NOTE(fork): when set, a function (t, alpha) giving the colour at a point across the spectrum,
    // 0 at the low end and 1 at the high end, and both curves are painted with it from side to
    // side in place of the theme's flat colours (the floor equalizer's gradient and chroma colours)
    property var colourAt: null

    // Left to right along the spectrum, sampled at seven points (enough for the full hue wheel to
    // read as one smooth sweep)
    readonly property LinearGradient spectrumStroke: LinearGradient {
        x1: 0
        y1: 0
        x2: root.width
        y2: 0

        GradientStop {
            position: 0
            color: root.spectrum(0, 1)
        }

        GradientStop {
            position: 1 / 6
            color: root.spectrum(1 / 6, 1)
        }

        GradientStop {
            position: 2 / 6
            color: root.spectrum(2 / 6, 1)
        }

        GradientStop {
            position: 3 / 6
            color: root.spectrum(3 / 6, 1)
        }

        GradientStop {
            position: 4 / 6
            color: root.spectrum(4 / 6, 1)
        }

        GradientStop {
            position: 5 / 6
            color: root.spectrum(5 / 6, 1)
        }

        GradientStop {
            position: 1
            color: root.spectrum(1, 1)
        }
    }
    readonly property LinearGradient spectrumFront: LinearGradient {
        x1: 0
        y1: 0
        x2: root.width
        y2: 0

        GradientStop {
            position: 0
            color: root.spectrum(0, root.outlineOnly ? 0 : 0.45)
        }

        GradientStop {
            position: 1 / 6
            color: root.spectrum(1 / 6, root.outlineOnly ? 0 : 0.45)
        }

        GradientStop {
            position: 2 / 6
            color: root.spectrum(2 / 6, root.outlineOnly ? 0 : 0.45)
        }

        GradientStop {
            position: 3 / 6
            color: root.spectrum(3 / 6, root.outlineOnly ? 0 : 0.45)
        }

        GradientStop {
            position: 4 / 6
            color: root.spectrum(4 / 6, root.outlineOnly ? 0 : 0.45)
        }

        GradientStop {
            position: 5 / 6
            color: root.spectrum(5 / 6, root.outlineOnly ? 0 : 0.45)
        }

        GradientStop {
            position: 1
            color: root.spectrum(1, root.outlineOnly ? 0 : 0.45)
        }
    }
    readonly property LinearGradient spectrumBack: LinearGradient {
        x1: 0
        y1: 0
        x2: root.width
        y2: 0

        GradientStop {
            position: 0
            color: root.spectrum(0, root.outlineOnly ? 0 : 0.22)
        }

        GradientStop {
            position: 1 / 6
            color: root.spectrum(1 / 6, root.outlineOnly ? 0 : 0.22)
        }

        GradientStop {
            position: 2 / 6
            color: root.spectrum(2 / 6, root.outlineOnly ? 0 : 0.22)
        }

        GradientStop {
            position: 3 / 6
            color: root.spectrum(3 / 6, root.outlineOnly ? 0 : 0.22)
        }

        GradientStop {
            position: 4 / 6
            color: root.spectrum(4 / 6, root.outlineOnly ? 0 : 0.22)
        }

        GradientStop {
            position: 5 / 6
            color: root.spectrum(5 / 6, root.outlineOnly ? 0 : 0.22)
        }

        GradientStop {
            position: 1
            color: root.spectrum(1, root.outlineOnly ? 0 : 0.22)
        }
    }

    function spectrum(t: real, alpha: real): color {
        return root.colourAt ? root.colourAt(t, alpha) : "transparent";
    }

    // Each curve eases towards the latest levels at its own rate. Eased here rather than through a
    // Behavior, since what moves is a whole array and a Behavior can only ease a number
    property var front: []
    property var back: []

    // The curve through the levels as points on the card: Catmull-Rom between each pair of levels, which
    // passes through every level (unlike a Bezier fitted to them) and never overshoots far enough for a
    // quiet band to dip below the floor
    function curve(values: var, w: real, h: real): var {
        const n = values.length;
        if (n === 0 || w <= 0 || h <= 0)
            return [Qt.point(-3, h + 3), Qt.point(w + 3, h + 3)];

        const steps = 4;
        const step = w / Math.max(1, n - 1);
        const at = i => values[Math.max(0, Math.min(n - 1, i))];
        // Started and ended just outside the item, so the outline is only drawn along the top of the
        // curve and not up its sides and across the foot
        const pts = [Qt.point(-3, h + 3)];
        // Headroom over the loudest band, so a peak is a rounded crest rather than flattened on the edge
        const amp = h - 6;

        for (let i = 0; i < n - 1; i++) {
            const p0 = at(i - 1);
            const p1 = at(i);
            const p2 = at(i + 1);
            const p3 = at(i + 2);
            for (let s = 0; s < steps; s++) {
                const t = s / steps;
                const t2 = t * t;
                const t3 = t2 * t;
                const v = 0.5 * (2 * p1 + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3);
                pts.push(Qt.point((i + t) * step, h - Math.max(0, Math.min(1, v)) * amp));
            }
        }
        pts.push(Qt.point(w, h - Math.max(0, Math.min(1, at(n - 1))) * amp));
        pts.push(Qt.point(w + 3, h + 3));
        return pts;
    }

    implicitWidth: 500
    implicitHeight: 110
    clip: true

    // Fed at the shared decorative rate, like the card's sampling. With the analyser paused the curves
    // hold where they are, the same as the bars do
    Timer {
        interval: PowerSaving.frameMs
        repeat: true
        triggeredOnStart: true
        running: root.visible && !PowerSaving.pauseVisualisers

        onTriggered: {
            const n = root.barCount;
            // Each rate is the share of the gap closed per tick. Raised to 1 / smoothing, so twice
            // the smoothing takes twice as many ticks to close the same share
            const ease = k => root.smoothing <= 0 ? 1 : 1 - Math.pow(1 - k, 1 / root.smoothing);
            const kf = ease(0.45);
            const kb = ease(0.12);
            const f = new Array(n);
            const b = new Array(n);
            // A small floor, so a quiet room leaves a low swell along the bottom rather than nothing
            for (let i = 0; i < n; i++) {
                const target = Math.max(0.03, root.levels[i] ?? 0);
                const pf = root.front[i] ?? 0;
                const pb = root.back[i] ?? 0;
                f[i] = pf + (target - pf) * kf;
                b[i] = pb + (target * 1.08 - pb) * kb;
            }
            root.front = f;
            root.back = b;
        }
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillGradient: root.colourAt ? root.spectrumBack : backFill

            readonly property LinearGradient backFill: LinearGradient {
                x1: 0
                y1: 0
                x2: 0
                y2: root.height

                GradientStop {
                    position: 0
                    color: Qt.alpha(Colours.palette.m3tertiary, root.outlineOnly ? 0 : 0.5)
                }
                GradientStop {
                    position: 1
                    color: Qt.alpha(Colours.palette.m3tertiary, root.outlineOnly ? 0 : 0.04)
                }
            }

            PathPolyline {
                path: root.curve(root.back, root.width, root.height)
            }
        }

        ShapePath {
            strokeWidth: root.outlineOnly ? 3 : 2
            strokeColor: Colours.palette.m3primary
            strokeGradient: root.colourAt ? root.spectrumStroke : null
            joinStyle: ShapePath.RoundJoin
            capStyle: ShapePath.RoundCap
            fillGradient: root.colourAt ? root.spectrumFront : frontFill

            readonly property LinearGradient frontFill: LinearGradient {
                x1: 0
                y1: 0
                x2: 0
                y2: root.height

                GradientStop {
                    position: 0
                    color: Qt.alpha(Colours.palette.m3primary, root.outlineOnly ? 0 : 0.7)
                }
                GradientStop {
                    position: 1
                    color: Qt.alpha(Colours.palette.m3primary, root.outlineOnly ? 0 : 0.1)
                }
            }

            PathPolyline {
                path: root.curve(root.front, root.width, root.height)
            }
        }
    }
}
