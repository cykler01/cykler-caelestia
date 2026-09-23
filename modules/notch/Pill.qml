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

    // The visualiser packs its bars into 40% of the width on each side of a centre gap, so the
    // count has to follow the size of the pill: the shell's own 60 bars come out narrower than
    // their own spacing in a box this small and draw nothing at all.
    readonly property int barCount: Math.max(3, Math.round(root.coverSize / 10))

    // Groups the shell's full-width spectrum down to the bars the pill has room for, taking the
    // peak of each group so a band sitting next to a loud one doesn't disappear
    function sampleSpectrum(values: var, count: int): var {
        const bars = [];
        if (!values || values.length === 0)
            return bars;

        const step = values.length / count;
        for (let i = 0; i < count; i++) {
            const start = Math.floor(i * step);
            const end = Math.max(start + 1, Math.floor((i + 1) * step));
            let peak = 0;
            for (let j = start; j < end && j < values.length; j++)
                peak = Math.max(peak, values[j]);
            bars.push(peak);
        }
        return bars;
    }

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

                values: root.sampleSpectrum(Audio.cava.values, root.barCount)
                primaryColor: Colours.palette.m3primary
                secondaryColor: Colours.palette.m3inversePrimary
                rounding: Tokens.rounding.small
                // A quarter of the smallest spacing token: the bars here are only a few pixels
                // wide, so a full-sized gap between them would swallow them whole
                spacing: Tokens.spacing.extraSmall / 4
                animationDuration: Tokens.anim.durations.normal
            }

            FrameAnimation {
                running: !bars.settled
                onTriggered: bars.advance(frameTime)
            }
        }
    }
}
