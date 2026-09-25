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


    spacing: Tokens.spacing.large

    CircularProgress {
        implicitSize: 96
        strokeWidth: 7
        value: 1 - FocusTimer.remaining / FocusTimer.durationSecs
        fgColour: FocusTimer.remaining <= 0 ? Colours.palette.m3tertiary : Colours.palette.m3primary
        bgColour: Colours.palette.m3surfaceContainerHighest

        Behavior on clampedVal {
            Anim {}
        }

        StyledText {
            anchors.centerIn: parent
            text: FocusTimer.display
            color: Colours.palette.m3onSurface
            font: Tokens.font.clock.size(Tokens.font.title.medium.pointSize).weight(Font.Bold).build()
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.small

        StyledText {
            text: FocusTimer.remaining <= 0 ? Tr.tr("Session complete") : FocusTimer.running ? Tr.tr("Focusing") : Tr.tr("Ready to focus")
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.label.medium
        }

        RowLayout {
            spacing: Tokens.spacing.small

            IconButton {
                icon: FocusTimer.running ? "pause" : "play_arrow"
                type: IconButton.Filled
                onClicked: FocusTimer.toggle()
            }

            IconButton {
                icon: "restart_alt"
                type: IconButton.Tonal
                onClicked: FocusTimer.reset()
            }
        }

        RowLayout {
            spacing: Tokens.spacing.small

            IconButton {
                icon: "remove"
                type: IconButton.Text
                onClicked: FocusTimer.adjust(-5)
            }

            StyledText {
                text: Math.round(FocusTimer.durationSecs / 60) + " min"
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.small
            }

            IconButton {
                icon: "add"
                type: IconButton.Text
                onClicked: FocusTimer.adjust(5)
            }
        }
    }
}
