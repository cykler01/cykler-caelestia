import QtQuick
import QtQuick.Layouts

// The filled intraday line used by both the stocks spotlight and the combined portfolio. Keeping the
// drawing in one place means a change to the chart cannot make the two cards disagree about their shape.
Canvas {
    id: root

    property var values: []
    property color accent

    Layout.fillWidth: true
    Layout.fillHeight: true
    Layout.minimumHeight: 34
    Layout.preferredHeight: 46

    onValuesChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onAccentChanged: requestPaint()
    onVisibleChanged: {
        if (visible)
            requestPaint();
    }

    onPaint: {
        const ctx = getContext("2d");
        ctx.clearRect(0, 0, width, height);
        const values = root.values;
        if (values.length < 2)
            return;

        let min = Number.POSITIVE_INFINITY;
        let max = Number.NEGATIVE_INFINITY;
        for (const value of values) {
            min = Math.min(min, value);
            max = Math.max(max, value);
        }
        if (max - min < 0.000001) {
            min -= 1;
            max += 1;
        }

        const pad = 3;
        const step = (width - pad * 2) / (values.length - 1);
        const y = value => height - pad - (value - min) / (max - min) * (height - pad * 2);

        ctx.beginPath();
        values.forEach((value, index) => {
            if (index === 0)
                ctx.moveTo(pad, y(value));
            else
                ctx.lineTo(pad + index * step, y(value));
        });
        ctx.lineTo(width - pad, height);
        ctx.lineTo(pad, height);
        ctx.closePath();
        ctx.fillStyle = Qt.alpha(root.accent, 0.12);
        ctx.fill();

        ctx.beginPath();
        values.forEach((value, index) => {
            if (index === 0)
                ctx.moveTo(pad, y(value));
            else
                ctx.lineTo(pad + index * step, y(value));
        });
        ctx.strokeStyle = root.accent;
        ctx.lineWidth = 2;
        ctx.lineJoin = "round";
        ctx.lineCap = "round";
        ctx.stroke();
    }
}
