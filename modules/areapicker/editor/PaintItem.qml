pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Shapes

// NOTE(fork): draws one annotation in the screenshot editor, in capture pixels.
//
// An annotation is a plain object so the editor can snapshot it for undo:
//   kind      brush | text | rectangle | ellipse | arrow | blur, or cut for the
//             outline the cut tool is drawing, which is never kept as an annotation
//   colour    the colour it is drawn in, transparency included
//   width     stroke width
//   fill      whether a rectangle or ellipse is filled
//   x1 y1     where it was started (the text's top left)
//   x2 y2     where it was finished
//   points    the brush's path, as [x, y] pairs
//   text      the text's content
//   fontSize  the text's pixel size
Item {
    id: root

    required property var paint
    // What a blur samples: the capture and the images on it, never the annotations,
    // so a blur can't end up sampling itself.
    property Item blurSource
    // Width of the cut tool's outline, in capture pixels, so it stays thin on screen.
    property real lineWidth: 2

    readonly property string kind: paint?.kind ?? ""
    readonly property real boxLeft: Math.min(paint?.x1 ?? 0, paint?.x2 ?? 0)
    readonly property real boxTop: Math.min(paint?.y1 ?? 0, paint?.y2 ?? 0)
    readonly property real boxWidth: Math.abs((paint?.x2 ?? 0) - (paint?.x1 ?? 0))
    readonly property real boxHeight: Math.abs((paint?.y2 ?? 0) - (paint?.y1 ?? 0))

    anchors.fill: parent

    Loader {
        anchors.fill: parent
        active: root.paint !== null && root.paint !== undefined
        sourceComponent: {
            switch (root.kind) {
            case "brush":
                return brushComp;
            case "text":
                return textComp;
            case "rectangle":
                return rectComp;
            case "ellipse":
                return ellipseComp;
            case "arrow":
                return arrowComp;
            case "blur":
                return blurComp;
            case "cut":
                return cutComp;
            }
            return null;
        }
    }

    Component {
        id: brushComp

        Shape {
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: root.paint.colour
                strokeWidth: root.paint.width
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin

                PathPolyline {
                    // A single click still leaves a dot behind.
                    path: {
                        const pts = root.paint.points.map(p => Qt.point(p[0], p[1]));
                        if (pts.length === 1)
                            pts.push(Qt.point(pts[0].x + 0.01, pts[0].y));
                        return pts;
                    }
                }
            }
        }
    }

    Component {
        id: textComp

        Item {
            Text {
                x: root.paint.x1
                y: root.paint.y1
                text: root.paint.text
                textFormat: Text.PlainText
                color: root.paint.colour
                font.family: "sans-serif"
                font.pixelSize: root.paint.fontSize
            }
        }
    }

    Component {
        id: rectComp

        Item {
            // Grown by half the stroke on every side so the stroke is centred on the
            // outline that was drawn, rather than inside it.
            Rectangle {
                x: root.boxLeft - root.paint.width / 2
                y: root.boxTop - root.paint.width / 2
                width: root.boxWidth + root.paint.width
                height: root.boxHeight + root.paint.width
                color: root.paint.fill ? root.paint.colour : "transparent"
                border.width: root.paint.fill ? 0 : root.paint.width
                border.color: root.paint.colour
                antialiasing: true
            }
        }
    }

    Component {
        id: ellipseComp

        Shape {
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: root.paint.fill ? "transparent" : root.paint.colour
                strokeWidth: root.paint.fill ? 0 : root.paint.width
                fillColor: root.paint.fill ? root.paint.colour : "transparent"

                PathAngleArc {
                    centerX: root.boxLeft + root.boxWidth / 2
                    centerY: root.boxTop + root.boxHeight / 2
                    radiusX: root.boxWidth / 2
                    radiusY: root.boxHeight / 2
                    startAngle: 0
                    sweepAngle: 360
                }
            }
        }
    }

    Component {
        id: arrowComp

        Shape {
            id: arrow

            readonly property real dx: root.paint.x2 - root.paint.x1
            readonly property real dy: root.paint.y2 - root.paint.y1
            readonly property real length: Math.max(0.0001, Math.hypot(dx, dy))
            // Unit vector along the arrow, and the one across it.
            readonly property real ux: dx / length
            readonly property real uy: dy / length
            // The head grows with the stroke, but never past the length of the arrow.
            readonly property real headLength: Math.min(length, Math.max(12, root.paint.width * 4))
            readonly property real headHalf: headLength * 0.55
            readonly property real baseX: root.paint.x2 - ux * headLength
            readonly property real baseY: root.paint.y2 - uy * headLength

            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: root.paint.colour
                strokeWidth: root.paint.width
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                startX: root.paint.x1
                startY: root.paint.y1

                // Stops a little inside the head so the line's end doesn't poke out of its tip.
                PathLine {
                    x: root.paint.x2 - arrow.ux * arrow.headLength * 0.8
                    y: root.paint.y2 - arrow.uy * arrow.headLength * 0.8
                }
            }

            ShapePath {
                strokeColor: "transparent"
                strokeWidth: 0
                fillColor: root.paint.colour
                startX: root.paint.x2
                startY: root.paint.y2

                PathLine {
                    x: arrow.baseX - arrow.uy * arrow.headHalf
                    y: arrow.baseY + arrow.ux * arrow.headHalf
                }
                PathLine {
                    x: arrow.baseX + arrow.uy * arrow.headHalf
                    y: arrow.baseY - arrow.ux * arrow.headHalf
                }
                PathLine {
                    x: root.paint.x2
                    y: root.paint.y2
                }
            }
        }
    }

    // A dashed loop, closed back to where it started, so it is clear what will be kept.
    Component {
        id: cutComp

        Shape {
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: "white"
                strokeWidth: root.lineWidth
                strokeStyle: ShapePath.DashLine
                dashPattern: [4, 3]
                fillColor: Qt.alpha("white", 0.15)
                joinStyle: ShapePath.RoundJoin

                PathPolyline {
                    path: {
                        const pts = root.paint.points.map(p => Qt.point(p[0], p[1]));
                        pts.push(pts[0]);
                        return pts;
                    }
                }
            }
        }
    }

    Component {
        id: blurComp

        Item {
            // Samples a margin around the area and clips it off again, so the blur
            // doesn't fade out towards its edges and let what it hides show through.
            Item {
                readonly property real pad: 64

                x: root.boxLeft
                y: root.boxTop
                width: root.boxWidth
                height: root.boxHeight
                clip: true

                ShaderEffectSource {
                    id: blurSampler

                    x: -parent.pad
                    y: -parent.pad
                    width: root.boxWidth + parent.pad * 2
                    height: root.boxHeight + parent.pad * 2
                    sourceItem: root.blurSource
                    sourceRect: Qt.rect(root.boxLeft - parent.pad, root.boxTop - parent.pad, width, height)
                    visible: false
                }

                MultiEffect {
                    anchors.fill: blurSampler
                    source: blurSampler
                    autoPaddingEnabled: false
                    blurEnabled: true
                    blur: 1
                    blurMax: 64
                    blurMultiplier: 1
                }
            }
        }
    }
}
