pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia
import Caelestia.Config
import qs.components
import qs.services

// NOTE(fork): a toast as the notch shows it - the icon in its type's colour beside one line of
// title and one of message. The same content the corner list carries, at the size a pill across
// the top of the screen can hold, so a screenshot saving says so where you are already looking
// rather than in the far corner of the other side of the screen.
//
// It draws a snapshot held by services/NotchIsland.qml rather than the Toast object: the toast is
// claimed the moment it arrives and the corner list never draws it, so nothing here outlives it.
RowLayout {
    id: root

    readonly property int avatarSize: Tokens.padding.extraLarge
    // Wrapped lines would grow the pill down the screen, so both lines elide instead
    readonly property int textWidth: Math.max(160, Config.notch.maxTitleWidth)

    readonly property color accent: {
        if (NotchIsland.toastType === Toast.Success)
            return Colours.palette.m3success;
        if (NotchIsland.toastType === Toast.Warning)
            return Colours.palette.m3secondaryContainer;
        if (NotchIsland.toastType === Toast.Error)
            return Colours.palette.m3error;
        return Colours.palette.m3surfaceContainerHigh;
    }
    readonly property color onAccent: {
        if (NotchIsland.toastType === Toast.Success)
            return Colours.palette.m3onSuccess;
        if (NotchIsland.toastType === Toast.Warning)
            return Colours.palette.m3onSecondaryContainer;
        if (NotchIsland.toastType === Toast.Error)
            return Colours.palette.m3onError;
        return Colours.palette.m3onSurfaceVariant;
    }

    spacing: Tokens.spacing.medium

    StyledRect {
        Layout.alignment: Qt.AlignVCenter

        implicitWidth: root.avatarSize
        implicitHeight: root.avatarSize
        radius: Tokens.rounding.full
        color: root.accent

        MaterialIcon {
            anchors.centerIn: parent

            text: NotchIsland.toastIcon || "info"
            color: root.onAccent
            fontStyle: Tokens.font.icon.builders.large.build()
        }

        Behavior on color {
            CAnim {}
        }
    }

    ColumnLayout {
        Layout.alignment: Qt.AlignVCenter

        spacing: 0

        StyledText {
            Layout.maximumWidth: root.textWidth

            animate: true
            text: NotchIsland.toastTitle
            color: Colours.palette.m3onSurface
            font: Tokens.font.label.large
            elide: Text.ElideRight
        }

        StyledText {
            Layout.maximumWidth: root.textWidth

            visible: text !== ""
            animate: true
            text: NotchIsland.toastMessage
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.label.small
            elide: Text.ElideRight
        }
    }
}
