pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import Caelestia.Services
import qs.components
import qs.components.controls
import qs.services
import qs.utils

// NOTE(fork): what is downloading, in the standing notch - a browser part file or a Steam install
// (see plugin/src/Caelestia/Services/downloads.cpp for where the figures come from).
//
// Only one is shown, the one furthest along, with a count beside it when there are others behind
// it: the notch has room for a glance, and the rest is the downloads list's job. A source that
// cannot say how big the file will be (a Chromium part file only grows) gets an indeterminate bar
// and what has arrived so far in place of a percentage.
RowLayout {
    id: root

    // Sitting inside the bar rather than hanging from it: a shorter bar and a smaller label
    property bool compact

    readonly property var item: Downloads.primary
    readonly property bool steam: (root.item.kind ?? "") === "steam"
    readonly property real progress: root.item.progress ?? -1
    readonly property bool known: root.progress >= 0
    readonly property int others: Math.max(0, Downloads.count - 1)

    readonly property int barWidth: compact ? 44 : 64
    readonly property int nameWidth: compact ? 90 : 150

    spacing: Tokens.spacing.small

    StyledRect {
        Layout.alignment: Qt.AlignVCenter

        implicitWidth: implicitHeight
        implicitHeight: icon.implicitHeight + Tokens.padding.small * 2
        radius: Tokens.rounding.full
        color: Colours.palette.m3secondaryContainer

        MaterialIcon {
            id: icon

            anchors.centerIn: parent

            text: root.steam ? "sports_esports" : "download"
            color: Colours.palette.m3onSecondaryContainer
            fontStyle: Tokens.font.icon.small
        }
    }

    ColumnLayout {
        Layout.alignment: Qt.AlignVCenter

        spacing: Tokens.spacing.extraSmall / 2

        StyledText {
            Layout.maximumWidth: root.nameWidth

            text: root.item.name ?? ""
            color: Colours.palette.m3onSurface
            font: root.compact ? Tokens.font.label.medium : Tokens.font.label.large
            elide: Text.ElideRight
        }

        StyledProgressBar {
            Layout.preferredWidth: root.barWidth
            Layout.preferredHeight: Math.max(3, Math.round(Tokens.padding.extraSmall * 0.8))

            // Nothing to fill proportionally when the total is unknown, so it sweeps instead
            indeterminate: !root.known && PowerSaving.animations
            value: root.known ? root.progress : 0
            fgColour: Colours.palette.m3primary
            bgColour: Colours.palette.m3secondaryContainer
        }
    }

    StyledText {
        Layout.alignment: Qt.AlignVCenter

        text: root.known ? Strings.percentOne(root.progress) : Strings.bytes(root.item.done ?? 0)
        color: Colours.palette.m3onSurfaceVariant
        font: Tokens.font.label.small
    }

    // The ones not being shown
    StyledRect {
        Layout.alignment: Qt.AlignVCenter

        visible: root.others > 0
        implicitWidth: othersText.implicitWidth + Tokens.padding.small
        implicitHeight: othersText.implicitHeight + Tokens.padding.extraSmall / 2
        radius: Tokens.rounding.full
        color: Colours.palette.m3surfaceContainerHighest

        StyledText {
            id: othersText

            anchors.centerIn: parent

            // TRANSLATORS: %1 = how many further downloads there are, e.g. +2
            text: Tr.trCtx("+%1", "further downloads the notch has no room for").arg(root.others)
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.label.small
        }
    }
}
