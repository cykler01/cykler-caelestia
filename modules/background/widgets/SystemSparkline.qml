import QtQuick
import qs.services

// A small filled line of recent readings, newest at the right edge. Shared by the resource tiles and the
// network graph, which both want the shape of the last minute or so rather than an axis to read it against.
//
// It repaints only when its values change, which is once per sample (every few seconds), so it costs
// nothing between readings and needs no animation of its own.
Canvas {
    id: root

    // Oldest first
    property var values: []
    // What a full-height point means. Zero scales to the busiest value shown, for readings that have no
    // natural ceiling (bytes a second)
    property real maximum: 1
    property color colour: Colours.palette.m3primary
    property real lineWidth: 2
    // Drawn hanging from the top edge instead of standing on the bottom one, so two of them can meet
    // back to back along a shared baseline
    property bool inverted: false
    // How many samples a full width holds. A history shorter than this sits against the right edge, so a
    // card that has only just started fills in from "now" rather than stretching three points across
    property int capacity: 24

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();

        const values = root.values ?? [];
        if (values.length < 2 || width <= 0 || height <= 0)
            return;

        const peak = root.maximum > 0 ? root.maximum : Math.max(...values, 0) || 1;
        const slots = Math.max(root.capacity, values.length) - 1;
        const step = width / slots;
        const offset = (slots - (values.length - 1)) * step;
        const inset = root.lineWidth / 2;
        const span = height - inset * 2;
        const base = root.inverted ? 0 : height;

        const points = values.map((v, i) => {
            const f = Math.max(0, Math.min(1, v / peak));
            return {
                x: offset + i * step,
                y: root.inverted ? inset + f * span : height - inset - f * span
            };
        });

        // Through the midpoints between samples, so a jumpy reading reads as a curve instead of a saw
        const trace = () => {
            ctx.moveTo(points[0].x, points[0].y);
            for (let i = 1; i < points.length - 1; i++) {
                const mx = (points[i].x + points[i + 1].x) / 2;
                const my = (points[i].y + points[i + 1].y) / 2;
                ctx.quadraticCurveTo(points[i].x, points[i].y, mx, my);
            }
            const last = points[points.length - 1];
            ctx.lineTo(last.x, last.y);
        };

        const fade = ctx.createLinearGradient(0, root.inverted ? height : 0, 0, base);
        fade.addColorStop(0, Qt.alpha(root.colour, 0.32));
        fade.addColorStop(1, Qt.alpha(root.colour, 0.02));

        ctx.beginPath();
        trace();
        ctx.lineTo(points[points.length - 1].x, base);
        ctx.lineTo(points[0].x, base);
        ctx.closePath();
        ctx.fillStyle = fade;
        ctx.fill();

        ctx.beginPath();
        trace();
        ctx.lineWidth = root.lineWidth;
        ctx.lineJoin = "round";
        ctx.lineCap = "round";
        ctx.strokeStyle = root.colour;
        ctx.stroke();
    }

    onValuesChanged: requestPaint()
    onMaximumChanged: requestPaint()
    onColourChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
}
