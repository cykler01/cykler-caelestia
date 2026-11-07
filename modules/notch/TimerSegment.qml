pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services

// NOTE(fork): the running countdown in the standing notch - a ring filling as the time goes, with
// what is left of it beside. It reads the shell's one countdown (services/CountdownTimer.qml), so
// a timer started anywhere - the utilities panel, the sidebar's timer pane - shows up here.
//
// Colours follow the bar's own ring (modules/bar/components/TimerRing.qml): primary while it
// counts, outline while it is paused, tertiary once it has rung.
RowLayout {
    id: root

    // Sitting inside the bar rather than hanging from it: a smaller ring and a smaller label
    property bool compact

    readonly property int ringSize: compact ? Tokens.padding.largeIncreased : Tokens.padding.extraLarge
    readonly property color accent: CountdownTimer.finished ? Colours.palette.m3tertiary : CountdownTimer.running ? Colours.palette.m3primary : Colours.palette.m3outline

    spacing: Tokens.spacing.small

    Item {
        Layout.alignment: Qt.AlignVCenter
        implicitWidth: root.ringSize
        implicitHeight: root.ringSize

        CircularProgress {
            anchors.fill: parent

            strokeWidth: Math.max(2, Math.round(root.ringSize / 8))
            value: CountdownTimer.progress
            fgColour: root.accent
            bgColour: Qt.alpha(Colours.palette.m3outlineVariant, 0.6)
        }

        MaterialIcon {
            anchors.centerIn: parent

            text: CountdownTimer.finished ? "alarm" : "timer"
            color: root.accent
            fontStyle: Tokens.font.icon.small
        }
    }

    StyledText {
        Layout.alignment: Qt.AlignVCenter

        // No fade on change: this reads a new value every second, and a crossfade per tick would
        // be a redraw loop for nothing
        text: CountdownTimer.finished ? Tr.tr("Time's up") : CountdownTimer.display
        color: CountdownTimer.finished ? Colours.palette.m3tertiary : Colours.palette.m3onSurface
        font: root.compact ? Tokens.font.label.medium : Tokens.font.label.large
    }
}
