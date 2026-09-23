import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services

StyledRect {
    id: root

    readonly property real nonAnimHeight: layout.implicitHeight + (IdleInhibitor.active ? activeChip.implicitHeight + activeChip.anchors.topMargin : 0) + Tokens.padding.extraLargeIncreased

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
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.small
                elide: Text.ElideRight
            }
        }

        Row {
            spacing: Tokens.spacing.extraSmall / 2

            IconButton {
                isRound: true
                type: IconButton.Tonal
                icon: "close"
                inactiveColour: IdleInhibitor.mode === IdleInhibitor.off ? Colours.palette.m3primary : Colours.tPalette.m3surfaceContainerHigh
                inactiveOnColour: IdleInhibitor.mode === IdleInhibitor.off ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant

                onClicked: IdleInhibitor.mode = IdleInhibitor.off
            }

            IconButton {
                isRound: true
                type: IconButton.Tonal
                icon: "coffee"
                inactiveColour: IdleInhibitor.mode === IdleInhibitor.preventSleepMode ? Colours.palette.m3secondary : Colours.tPalette.m3surfaceContainerHigh
                inactiveOnColour: IdleInhibitor.mode === IdleInhibitor.preventSleepMode ? Colours.palette.m3onSecondary : Colours.palette.m3onSurfaceVariant

                onClicked: IdleInhibitor.mode = IdleInhibitor.preventSleepMode
            }

            IconButton {
                isRound: true
                type: IconButton.Tonal
                icon: "lock_clock"
                inactiveColour: IdleInhibitor.mode === IdleInhibitor.preventLockAndSleepMode ? Colours.palette.m3secondary : Colours.tPalette.m3surfaceContainerHigh
                inactiveOnColour: IdleInhibitor.mode === IdleInhibitor.preventLockAndSleepMode ? Colours.palette.m3onSecondary : Colours.palette.m3onSurfaceVariant

                onClicked: IdleInhibitor.mode = IdleInhibitor.preventLockAndSleepMode
            }
        }
    }

    Loader {
        id: activeChip

        asynchronous: true
        anchors.top: layout.bottom
        anchors.left: parent.left
        anchors.topMargin: IdleInhibitor.active ? Tokens.spacing.large : -implicitHeight
        anchors.leftMargin: Tokens.padding.large

        opacity: IdleInhibitor.active ? 1 : 0
        scale: IdleInhibitor.active ? 1 : 0.5

        Component.onCompleted: active = Qt.binding(() => opacity > 0)

        sourceComponent: StyledRect {
            implicitWidth: activeText.implicitWidth + Tokens.padding.medium * 2
            implicitHeight: activeText.implicitHeight + Tokens.padding.small

            radius: Tokens.rounding.full
            color: Colours.palette.m3primary

            StyledText {
                id: activeText

                anchors.centerIn: parent
                // TRANSLATORS: %1 = a clock time, e.g. 14:30
                text: Tr.tr("Active since %1").arg(Qt.formatTime(IdleInhibitor.enabledSince, Units.twelveHourClock ? "hh:mm a" : "hh:mm"))
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
}
