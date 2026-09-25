pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services

// Focus timer: progress ring on the left, controls on the right
RowLayout {
    id: root

    property int durationSecs: 25 * 60
    property int remaining: durationSecs
    property bool running: false

    readonly property string display: {
        const m = Math.floor(remaining / 60);
        const s = remaining % 60;
        return `${m.toString().padStart(2, "0")}:${s.toString().padStart(2, "0")}`;
    }

    function toggle(): void {
        if (remaining <= 0)
            remaining = durationSecs;
        running = !running;
    }

    function reset(): void {
        running = false;
        remaining = durationSecs;
    }

    function adjust(mins: int): void {
        if (running)
            return;
        durationSecs = Math.max(60, durationSecs + mins * 60);
        remaining = durationSecs;
    }

    spacing: Tokens.spacing.large

    Timer {
        interval: 1000
        repeat: true
        running: root.running
        onTriggered: {
            root.remaining--;
            if (root.remaining <= 0)
                root.running = false;
        }
    }

    CircularProgress {
        implicitSize: 96
        strokeWidth: 7
        value: 1 - root.remaining / root.durationSecs
        fgColour: root.remaining <= 0 ? Colours.palette.m3tertiary : Colours.palette.m3primary
        bgColour: Colours.palette.m3surfaceContainerHighest

        Behavior on clampedVal {
            Anim {}
        }

        StyledText {
            anchors.centerIn: parent
            text: root.display
            color: Colours.palette.m3onSurface
            font: Tokens.font.clock.size(Tokens.font.title.medium.pointSize).weight(Font.Bold).build()
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.small

        StyledText {
            text: root.remaining <= 0 ? Tr.tr("Session complete") : root.running ? Tr.tr("Focusing") : Tr.tr("Ready to focus")
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.label.medium
        }

        RowLayout {
            spacing: Tokens.spacing.small

            IconButton {
                icon: root.running ? "pause" : "play_arrow"
                type: IconButton.Filled
                onClicked: root.toggle()
            }

            IconButton {
                icon: "restart_alt"
                type: IconButton.Tonal
                onClicked: root.reset()
            }
        }

        RowLayout {
            spacing: Tokens.spacing.small

            IconButton {
                icon: "remove"
                type: IconButton.Text
                onClicked: root.adjust(-5)
            }

            StyledText {
                text: Math.round(root.durationSecs / 60) + " min"
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.small
            }

            IconButton {
                icon: "add"
                type: IconButton.Text
                onClicked: root.adjust(5)
            }
        }
    }
}
