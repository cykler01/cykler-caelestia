import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services

StyledRect {
    id: root

    // Gap between the row above and the "active since" chip under it, shared by where the chip sits
    // and the height the card settles at
    readonly property real chipSpacing: Tokens.spacing.large
    // The height the card settles at, not the one it is passing through on the way there. The chip's
    // position is animated, so reading it here had the card chase its own animation, and anything
    // laid out from this height (the notifications panel) measured it mid-move.
    readonly property real nonAnimHeight: layout.implicitHeight + (IdleInhibitor.active ? activeChip.implicitHeight + root.chipSpacing : 0) + Tokens.padding.extraLargeIncreased

    implicitHeight: nonAnimHeight

    radius: Tokens.rounding.large
    color: Colours.tPalette.m3surfaceContainer
    clip: true

    RowLayout {
        id: layout

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.medium

        StyledRect {
            implicitWidth: implicitHeight
            implicitHeight: icon.implicitHeight + Tokens.padding.large

            radius: Tokens.rounding.full
            color: IdleInhibitor.active ? Colours.palette.m3secondary : Colours.palette.m3secondaryContainer

            MaterialIcon {
                id: icon

                anchors.centerIn: parent
                animate: true
                text: IdleInhibitor.preventLock ? "lock_clock" : "coffee"
                color: IdleInhibitor.active ? Colours.palette.m3onSecondary : Colours.palette.m3onSecondaryContainer
                fontStyle: Tokens.font.icon.large
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                text: Tr.trCtx("Keep awake", "idle inhibitor")
                font: Tokens.font.body.medium
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                text: {
                    if (IdleInhibitor.preventLock)
                        return Tr.trCtx("Won't lock or sleep when idle", "idle inhibitor");
                    if (IdleInhibitor.preventSleep)
                        return Tr.trCtx("Won't sleep when idle, still locks", "idle inhibitor");
                    return Tr.trCtx("Normal power management", "idle inhibitor");
                }
                animate: true
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.small
                elide: Text.ElideRight
            }
        }

        // The three modes sit in one pill, with a thumb that slides to whichever of them is on,
        // instead of each being a button of its own
        StyledRect {
            id: modePill

            readonly property real inset: Tokens.padding.extraSmall / 2
            readonly property var modes: [
                {
                    mode: IdleInhibitor.off,
                    icon: "close"
                },
                {
                    mode: IdleInhibitor.preventSleepMode,
                    icon: "coffee"
                },
                {
                    mode: IdleInhibitor.preventLockAndSleepMode,
                    icon: "lock_clock"
                }
            ]
            // Clamped so a mode the pill doesn't know about can't put the thumb off the end of it
            readonly property int currentIndex: Math.max(0, modes.findIndex(m => m.mode === IdleInhibitor.mode))
            readonly property real stageWidth: modes.length > 0 ? stages.implicitWidth / modes.length : 0

            Layout.alignment: Qt.AlignVCenter
            implicitWidth: stages.implicitWidth + inset * 2
            implicitHeight: stages.implicitHeight + inset * 2
            radius: Tokens.rounding.full
            color: Colours.tPalette.m3surfaceContainerHighest

            StyledRect {
                id: thumb

                x: modePill.inset + modePill.currentIndex * modePill.stageWidth
                y: modePill.inset
                width: modePill.stageWidth
                height: modePill.height - modePill.inset * 2
                radius: Tokens.rounding.full
                // Off keeps the primary colour the round buttons used, the two inhibiting modes
                // keep the secondary one
                color: IdleInhibitor.active ? Colours.palette.m3secondary : Colours.palette.m3primary

                Behavior on x {
                    Anim {}
                }
            }

            Row {
                id: stages

                anchors.centerIn: parent

                Repeater {
                    model: modePill.modes

                    ModeStage {}
                }
            }
        }
    }

    Loader {
        id: activeChip

        // Loaded with the card instead of the moment a mode is turned on: a chip loading
        // asynchronously has no height for a frame or two, which is what made enabling a mode
        // resize the card to the wrong height first and then jump to the right one
        anchors.top: layout.bottom
        anchors.left: parent.left
        anchors.topMargin: IdleInhibitor.active ? root.chipSpacing : -implicitHeight
        anchors.leftMargin: Tokens.padding.large

        opacity: IdleInhibitor.active ? 1 : 0
        scale: IdleInhibitor.active ? 1 : 0.5

        sourceComponent: StyledRect {
            implicitWidth: activeText.implicitWidth + Tokens.padding.medium * 2
            implicitHeight: activeText.implicitHeight + Tokens.padding.small

            radius: Tokens.rounding.full
            color: Colours.palette.m3primary

            StyledText {
                id: activeText

                anchors.centerIn: parent
                // The chip exists before any mode has been used, and formatTime on the start time
                // it doesn't have yet throws, so it stays empty until there is a time to show
                // TRANSLATORS: %1 = a clock time, e.g. 14:30
                text: IdleInhibitor.enabledSince ? Tr.tr("Active since %1").arg(Qt.formatTime(IdleInhibitor.enabledSince, Units.twelveHourClock ? "hh:mm a" : "hh:mm")) : ""
                color: Colours.palette.m3onPrimary
                font: Tokens.font.body.builders.small.size(Math.round(Tokens.font.body.small.pointSize * 0.9)).build()
            }
        }

        Behavior on anchors.topMargin {
            Anim {}
        }

        Behavior on opacity {
            Anim {
                type: Anim.StandardSmall
            }
        }

        Behavior on scale {
            Anim {}
        }
    }

    Behavior on implicitHeight {
        Anim {}
    }

    // One stage of the mode pill: the icon, plus the hover and press feedback of a button, over the
    // thumb when its mode is the one that is on. Sized the way the round buttons this replaced
    // were, so the pill stays the height of the rest of the card's controls.
    component ModeStage: StyledRect {
        id: stage

        required property var modelData

        readonly property bool selected: IdleInhibitor.mode === stage.modelData.mode

        implicitWidth: icon.implicitHeight + Tokens.padding.small * 2
        implicitHeight: icon.implicitHeight + Tokens.padding.small * 2
        radius: Tokens.rounding.full

        MaterialIcon {
            id: icon

            anchors.centerIn: parent
            text: stage.modelData.icon
            color: stage.selected ? (IdleInhibitor.active ? Colours.palette.m3onSecondary : Colours.palette.m3onPrimary) : Colours.palette.m3onSurfaceVariant
            fill: stage.selected ? 1 : 0
            fontStyle: Tokens.font.icon.medium

            Behavior on fill {
                Anim {}
            }
        }

        StateLayer {
            onClicked: IdleInhibitor.mode = stage.modelData.mode
        }
    }
}
