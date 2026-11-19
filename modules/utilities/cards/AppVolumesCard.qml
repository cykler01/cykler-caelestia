pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services
import qs.modules.dashboard.media

// NOTE(fork): the utilities panel's app volumes card, the panel counterpart of the media tab's
// drawer: the streams that are playing right now, each with its own slider. Nothing is listed while
// nothing is playing, so the card is only worth its space once some app has audio. Compact keeps it
// to its title until the caret is pressed, so the card can stay in the panel without taking room
// from the ones above and below it, while vertical lays the sliders out in columns for a shorter,
// wider card.
StyledRect {
    id: root

    property bool compact
    property bool vertical
    property bool expanded

    implicitHeight: layout.implicitHeight + layout.anchors.margins * 2

    onCompactChanged: {
        if (root.compact)
            root.expanded = false;
    }

    radius: Tokens.rounding.large
    color: Colours.tPalette.m3surfaceContainer

    ColumnLayout {
        id: layout

        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.medium

        RowLayout {
            spacing: Tokens.spacing.extraSmall

            MaterialIcon {
                text: "tune"
                color: Colours.palette.m3onSurfaceVariant
                fontStyle: Tokens.font.icon.medium
            }

            StyledText {
                Layout.fillWidth: true
                text: Tr.tr("App volumes")
                font: Tokens.font.body.medium
                elide: Text.ElideRight
            }

            StyledText {
                visible: Audio.streams.length > 0
                text: Tr.trN("%n app", "%n apps", Audio.streams.length)
                color: Colours.palette.m3outline
                font: Tokens.font.label.small
            }

            IconButton {
                visible: root.compact
                icon: root.expanded ? "unfold_less" : "unfold_more"
                type: IconButton.Text
                onClicked: root.expanded = !root.expanded
            }
        }

        StyledText {
            Layout.fillWidth: true
            visible: Audio.streams.length === 0
            text: Tr.tr("No apps playing audio")
            color: Colours.palette.m3outline
            font: Tokens.font.body.small
        }

        StyledListView {
            id: streams

            Layout.fillWidth: true
            // Compact starts folded away; the header keeps its caret to bring the list back
            Layout.preferredHeight: root.compact && !root.expanded ? 0 : implicitHeight
            // Room for a few apps; more than that scroll rather than stretching the panel
            implicitHeight: Math.min(streams.contentHeight, 3 * 56 + 2 * Tokens.spacing.medium)
            visible: Audio.streams.length > 0 && !root.vertical
            clip: true
            spacing: Tokens.spacing.medium
            model: Audio.streams

            StyledScrollBar.vertical: StyledScrollBar {
                flickable: streams
            }

            delegate: AppVolumeRow {
                width: streams.width
            }

            Behavior on Layout.preferredHeight {
                Anim {}
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 160
            visible: root.vertical && Audio.streams.length > 0
            spacing: Tokens.spacing.small

            Repeater {
                model: Audio.streams

                AppVolumeBand {}
            }
        }
    }
}
