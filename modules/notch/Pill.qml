import QtQuick
import QtQuick.Layouts
import Caelestia.Components
import Caelestia.Config
import Caelestia.I18n
import Caelestia.Services
import qs.components
import qs.components.widgets
import qs.services

// No background/border/shadow here - the shared blob group in
// modules/drawers/ContentWindow.qml (PanelBg { panel: panels.notch }) paints
// the fluid, deforming background behind this, same as every other drawer
// panel (dashboard, osd, popouts, etc.). This is just the foreground content.
Item {
    id: root

    readonly property int coverSize: Tokens.padding.extraLarge

    implicitWidth: layout.implicitWidth + Tokens.padding.large * 2
    implicitHeight: layout.implicitHeight + Tokens.padding.medium * 2

    RowLayout {
        id: layout

        anchors.centerIn: parent
        spacing: Tokens.spacing.medium

        CoverArt {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: root.coverSize
            Layout.preferredHeight: root.coverSize
        }

        StyledText {
            // Grows with the track title (and artist, if shown), elided past
            // this so one long name can't stretch the pill indefinitely
            Layout.alignment: Qt.AlignVCenter
            Layout.maximumWidth: Config.notch.maxTitleWidth
            text: {
                const title = Players.active?.trackTitle ?? "";
                const artist = Players.active?.trackArtist ?? "";
                return Config.notch.showArtist && artist ? Tr.trCtx("%1 - %2", "track artist and title").arg(artist).arg(title) : title;
            }
            color: Colours.palette.m3onSurface
            font: Tokens.font.title.small
            elide: Text.ElideRight
        }

        Item {
            id: visualiserWrapper

            // Matches root.coverSize so the cover and visualiser carry the
            // same visual weight either side of the title
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: root.coverSize
            Layout.preferredHeight: root.coverSize

            ServiceRef {
                service: Audio.cava
            }

            VisualiserBars {
                id: bars

                anchors.fill: parent

                values: Audio.cava.values
                primaryColor: Colours.palette.m3primary
                secondaryColor: Colours.palette.m3inversePrimary
                rounding: Tokens.rounding.small
                spacing: Tokens.spacing.extraSmall
                animationDuration: Tokens.anim.durations.normal
            }

            FrameAnimation {
                running: !bars.settled
                onTriggered: bars.advance(frameTime)
            }
        }
    }
}
