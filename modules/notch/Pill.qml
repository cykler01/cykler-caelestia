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

    // Set by the Wrapper: whether cava has a real level to draw yet (see cavaWarm there)
    property bool cavaWarm

    readonly property int coverSize: Tokens.padding.extraLarge

    // Drives the placeholder pattern below; only ticks while that pattern is actually on screen
    property real placeholderPhase

    // The bars are drawn as one row across the full width of the visualiser box (see singleRow
    // below), so the count has to follow the size of the pill: more than this and they come out
    // narrower than the gaps between them
    readonly property int barCount: Math.max(3, Math.round(root.coverSize / 5))

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

    // Stands in for the spectrum until cava has a level to report, so the first pill of a session
    // (where cava is starting cold and its autosensitivity takes about a second to ramp the bars
    // up from nothing) shows a moving equaliser rather than an empty box. Two detuned waves per
    // bar, under an envelope that lifts the middle bars, so it reads as a spectrum rather than a
    // row of pulsing dots. Runs 0.25 to 0.65, the height range the real bars hand over in, so the
    // swap does not read as a jump.
    function placeholderSpectrum(count: int): var {
        const bars = [];
        for (let i = 0; i < count; i++) {
            const envelope = 0.55 + 0.45 * (1 - Math.abs((i + 0.5) / count * 2 - 1));
            const wave = 0.5 + 0.32 * Math.sin(root.placeholderPhase * (1 + i * 0.19) + i * 1.7) + 0.18 * Math.sin(root.placeholderPhase * (2.2 + i * 0.11) + i * 0.7);
            bars.push(0.25 + 0.4 * envelope * wave);
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

                // Centred on the middle line and reflected above and below it rather than rising
                // from the bottom of the pill, where the bars sat low enough to be easy to miss,
                // and as one spectrum across the width: the component's default layout would
                // draw this same spectrum twice, mirrored beside itself
                // (see mirrored/singleRow in plugin/src/Caelestia/Components/visualiserbars.hpp)
                mirrored: true
                singleRow: true
                values: root.cavaWarm ? root.sampleSpectrum(Audio.cava.values, root.barCount) : root.placeholderSpectrum(root.barCount)
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

            FrameAnimation {
                running: !root.cavaWarm
                onTriggered: root.placeholderPhase += frameTime * 4
            }
        }
    }
}
