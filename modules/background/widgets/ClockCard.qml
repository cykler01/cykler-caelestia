pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import Caelestia.Config
import Caelestia.I18n
import Caelestia.Models
import Caelestia.Services
import qs.components
import qs.components.controls
import qs.components.effects
import qs.services
import qs.utils
import qs.modules.background
import qs.modules.dashboard.media
import qs.modules.launcher.services

// --- Clock: digital, time only, or an analogue face ---
WidgetCard {
    id: clock

    // Its own tick, rather than Time.date: the face has a second hand
    property date now: new Date()

    readonly property string style: clock.variant === "" ? "digital" : clock.variant

    title: clock.style === "analogue" ? Tr.tr("Clock") : ""
    icon: ""

    Timer {
        interval: 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: clock.now = new Date()
    }

    StyledText {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: clock.style === "minimal"
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: Qt.formatTime(clock.now, "HH:mm")
        color: Colours.palette.m3onSurface
        font: Tokens.font.title.large
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: clock.style === "digital"
        spacing: Tokens.spacing.extraSmall

        StyledText {
            Layout.fillWidth: true
            Layout.fillHeight: true
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
            text: Qt.formatTime(clock.now, "HH:mm")
            color: Colours.palette.m3onSurface
            font: Tokens.font.title.large
        }

        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: Qt.formatDate(clock.now, "dddd d MMMM")
            color: Colours.palette.m3outline
            font: Tokens.font.label.medium
        }
    }

    Canvas {
        id: face

        function hand(ctx, cx, cy, angle: real, length: real, width: real, colour: color): void {
            ctx.strokeStyle = colour;
            ctx.lineWidth = width;
            ctx.lineCap = "round";
            ctx.beginPath();
            ctx.moveTo(cx - Math.sin(angle) * length * 0.12, cy + Math.cos(angle) * length * 0.12);
            ctx.lineTo(cx + Math.sin(angle) * length, cy - Math.cos(angle) * length);
            ctx.stroke();
        }

        Layout.alignment: Qt.AlignHCenter
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: 120
        Layout.preferredHeight: 120
        visible: clock.style === "analogue"

        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);

            const cx = width / 2;
            const cy = height / 2;
            const r = Math.min(cx, cy) - 2;
            if (r <= 0)
                return;

            ctx.strokeStyle = Qt.alpha(Colours.palette.m3outlineVariant, 0.6);
            ctx.lineWidth = 1;
            ctx.beginPath();
            ctx.arc(cx, cy, r, 0, Math.PI * 2);
            ctx.stroke();

            // Twelve ticks, the quarters longer, so the face reads as a clock at a glance
            ctx.strokeStyle = Colours.palette.m3outline;
            for (let i = 0; i < 12; i++) {
                const a = (i / 12) * Math.PI * 2;
                const inner = r * (i % 3 === 0 ? 0.78 : 0.87);
                ctx.lineWidth = i % 3 === 0 ? 2 : 1;
                ctx.beginPath();
                ctx.moveTo(cx + Math.sin(a) * inner, cy - Math.cos(a) * inner);
                ctx.lineTo(cx + Math.sin(a) * r * 0.94, cy - Math.cos(a) * r * 0.94);
                ctx.stroke();
            }

            const seconds = clock.now.getSeconds();
            const minutes = clock.now.getMinutes() + seconds / 60;
            const hours = (clock.now.getHours() % 12) + minutes / 60;

            face.hand(ctx, cx, cy, (hours / 12) * Math.PI * 2, r * 0.5, 3, Colours.palette.m3onSurface);
            face.hand(ctx, cx, cy, (minutes / 60) * Math.PI * 2, r * 0.72, 2, Colours.palette.m3onSurface);
            face.hand(ctx, cx, cy, (seconds / 60) * Math.PI * 2, r * 0.8, 1, Colours.palette.m3primary);

            ctx.fillStyle = Colours.palette.m3primary;
            ctx.beginPath();
            ctx.arc(cx, cy, 2.5, 0, Math.PI * 2);
            ctx.fill();
        }

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onVisibleChanged: {
            if (visible)
                requestPaint();
        }

        Connections {
            function onNowChanged(): void {
                face.requestPaint();
            }

            target: clock
        }
    }
}
