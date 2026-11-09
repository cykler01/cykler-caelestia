pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services

// NOTE(fork): the stopwatch (see services/Stopwatch.qml), counting up in hundredths with laps.
// One button under the reading, with the second one beside it being whichever of lap and reset
// makes sense at the time - lap while it runs, reset once it has stopped.
Item {
    id: root

    readonly property string statusText: {
        if (Stopwatch.running)
            return Tr.tr("Running");
        if (Stopwatch.active)
            return Tr.tr("Stopped");
        return Tr.tr("Ready to start");
    }

    ColumnLayout {
        anchors.fill: parent

        spacing: Tokens.spacing.medium

        // The reading, in the monospaced face: hundredths change too fast for a proportional one,
        // where every digit that comes and goes shifts everything beside it
        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.extraLargeIncreased

            horizontalAlignment: Text.AlignHCenter
            text: Stopwatch.display
            color: Stopwatch.running ? Colours.palette.m3primary : Colours.palette.m3onSurface
            font: Tokens.font.mono.builders.large.size(Tokens.font.headline.small.pointSize).weight(Font.Bold).build()

            Behavior on color {
                CAnim {}
            }
        }

        StyledText {
            Layout.fillWidth: true

            horizontalAlignment: Text.AlignHCenter
            // No crossfade on change: while a lap is running this reads a new value every frame,
            // and StyledText's animate fades the old text out and the new one in on every one of
            // them, which leaves it faded out for good
            text: Stopwatch.laps.length > 0
                // TRANSLATORS: %1 = a lap number, %2 = how long that lap has been running
                ? Tr.tr("Lap %1 · %2").arg(Stopwatch.laps.length + 1).arg(Stopwatch.format(Stopwatch.currentSplit))
                : root.statusText
            color: Colours.palette.m3outline
            font: Stopwatch.laps.length > 0 ? Tokens.font.mono.small : Tokens.font.label.medium
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.medium
            Layout.leftMargin: Tokens.padding.large
            Layout.rightMargin: Tokens.padding.large

            spacing: Tokens.spacing.small

            TextButton {
                Layout.fillWidth: true

                text: Stopwatch.running ? Tr.tr("Pause") : Stopwatch.active ? Tr.tr("Resume") : Tr.tr("Start")
                type: TextButton.Filled
                font: Tokens.font.body.medium
                verticalPadding: Tokens.padding.medium
                onClicked: Stopwatch.toggle()
            }

            // Lap while it runs, reset once it has stopped: the same place, so there is only ever
            // the one thing to reach for beside the main button
            IconButton {
                icon: Stopwatch.running ? "flag" : "refresh"
                type: IconButton.Tonal
                isRound: true
                shapeMorph: true
                padding: Tokens.padding.medium
                scale: Stopwatch.active ? 1 : 0
                visible: scale > 0.01
                Layout.preferredWidth: implicitWidth * scale
                onClicked: {
                    if (Stopwatch.running)
                        Stopwatch.lap();
                    else
                        Stopwatch.reset();
                }

                Behavior on scale {
                    Anim {
                        type: Anim.DefaultSpatial
                    }
                }
            }
        }

        // The laps taken, newest first. The quickest and the slowest are picked out once there are
        // two to compare
        VerticalFadeListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: Tokens.spacing.small

            spacing: 0
            model: Stopwatch.laps

            delegate: Item {
                id: lapRow

                required property var modelData

                readonly property bool fastest: lapRow.modelData.index === Stopwatch.fastestLap
                readonly property bool slowest: lapRow.modelData.index === Stopwatch.slowestLap
                readonly property color splitColour: lapRow.fastest ? Colours.palette.m3primary : lapRow.slowest ? Colours.palette.m3error : Colours.palette.m3onSurface

                anchors.left: ListView.view.contentItem.left
                anchors.right: ListView.view.contentItem.right

                implicitHeight: lapLayout.implicitHeight + Tokens.padding.small

                RowLayout {
                    id: lapLayout

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter

                    spacing: Tokens.spacing.small

                    StyledText {
                        Layout.fillWidth: true

                        // TRANSLATORS: %1 = a lap number
                        text: Tr.tr("Lap %1").arg(lapRow.modelData.index)
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.label.medium
                    }

                    StyledText {
                        text: Stopwatch.format(lapRow.modelData.split)
                        color: lapRow.splitColour
                        font: Tokens.font.mono.small
                    }

                    // The reading the lap was taken at, so the list also reads as a running total
                    StyledText {
                        text: Stopwatch.format(lapRow.modelData.at)
                        color: Colours.palette.m3outline
                        font: Tokens.font.mono.small
                    }
                }
            }
        }
    }
}
