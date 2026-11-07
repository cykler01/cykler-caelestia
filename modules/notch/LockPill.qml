pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services

// NOTE(fork): what the notch shows for a moment when a lock key is pressed - caps lock or num
// lock, and which way it went. The state itself comes from the compositor (Hypr.capsLock /
// Hypr.numLock, refreshed by the binds Hypr.qml installs for those keys); the island only has to
// say what changed, so there is nothing to poll here.
RowLayout {
    id: root

    readonly property bool caps: NotchIsland.lockKind !== "num"
    readonly property bool on: NotchIsland.lockState

    spacing: Tokens.spacing.medium

    StyledRect {
        Layout.alignment: Qt.AlignVCenter

        implicitWidth: implicitHeight
        implicitHeight: icon.implicitHeight + Tokens.padding.small * 2
        radius: Tokens.rounding.full
        color: root.on ? Colours.palette.m3primaryContainer : Colours.palette.m3surfaceContainerHighest

        MaterialIcon {
            id: icon

            anchors.centerIn: parent

            text: root.caps ? "keyboard_capslock_badge" : "dialpad"
            color: root.on ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant
            fontStyle: Tokens.font.icon.small
        }
    }

    ColumnLayout {
        Layout.alignment: Qt.AlignVCenter

        spacing: 0

        StyledText {
            text: root.caps ? Tr.tr("Caps lock") : Tr.tr("Num lock")
            color: Colours.palette.m3onSurface
            font: Tokens.font.label.large
        }

        StyledText {
            text: root.on ? Tr.trCtx("On", "lock key state") : Tr.trCtx("Off", "lock key state")
            color: root.on ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
            font: Tokens.font.label.small
        }
    }
}
