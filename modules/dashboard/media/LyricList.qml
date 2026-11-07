pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import Caelestia.Services
import qs.components
import qs.components.containers
import qs.components.controls
import qs.components.effects
import qs.services

Item {
    id: root

    required property MediaSource source

    // Funny binding hack to make lyrics update
    readonly property var _: {
        if (root.source.available)
            Lyrics.setTrack(root.source.artist, root.source.title, root.source.album, root.source.length, root.source.spotifyId);
        else
            Lyrics.clearTrack();
    }

    // The word sweep has to be placed from a clock that ticks faster than the player's readings
    // arrive, or every word would jump a half second at a time
    readonly property LyricsClock clock: LyricsClock {
        source: root.source
        wordTimed: Lyrics.wordTimed
    }

    readonly property real fadeAmount: 0.1
    // The lines with their word timings, so a line can be swept rather than lit whole
    property var lyricList: Lyrics.lines

    layer.enabled: true
    layer.effect: Mask {
        maskSource: mask

        Rectangle {
            id: mask

            layer.enabled: true
            visible: false
            implicitWidth: root.width
            implicitHeight: root.height

            gradient: Gradient {
                orientation: Gradient.Vertical

                GradientStop {
                    color: Qt.alpha("black", 0)
                    position: 0
                }
                GradientStop {
                    color: Qt.alpha("black", 1)
                    position: root.fadeAmount
                }
                GradientStop {
                    color: Qt.alpha("black", 1)
                    position: 1 - root.fadeAmount
                }
                GradientStop {
                    color: Qt.alpha("black", 0)
                    position: 1
                }
            }
        }
    }

    state: {
        if (Lyrics.hasLyrics)
            return "hasLyrics";
        if (Lyrics.loading)
            return "loading";
        return "noLyrics";
    }

    states: [
        State {
            name: "loading"

            PropertyChanges {
                loadingIndicator.opacity: 1
                lyrics.opacity: 0
                noLyrics.opacity: 0
            }
        },
        State {
            name: "hasLyrics"

            PropertyChanges {
                loadingIndicator.opacity: 0
                lyrics.opacity: 1
                noLyrics.opacity: 0
            }
        },
        State {
            name: "noLyrics"

            PropertyChanges {
                loadingIndicator.opacity: 0
                lyrics.opacity: 0
                noLyrics.opacity: 1
            }
        }
    ]

    transitions: [
        Transition {
            from: "loading"

            SequentialAnimation {
                Anim {
                    target: loadingIndicator
                    property: "opacity"
                    type: Anim.DefaultEffects
                }
                Anim {
                    targets: [lyrics, noLyrics]
                    property: "opacity"
                    type: Anim.SlowEffects
                }
            }
        },
        Transition {
            from: "hasLyrics"

            SequentialAnimation {
                Anim {
                    target: lyrics
                    property: "opacity"
                    type: Anim.DefaultEffects
                }
                Anim {
                    targets: [loadingIndicator, noLyrics]
                    property: "opacity"
                    type: Anim.SlowEffects
                }
            }
        },
        Transition {
            from: "noLyrics"

            SequentialAnimation {
                Anim {
                    target: noLyrics
                    property: "opacity"
                    type: Anim.DefaultEffects
                }
                Anim {
                    targets: [loadingIndicator, lyrics]
                    property: "opacity"
                    type: Anim.SlowEffects
                }
            }
        }
    ]

    Loader {
        id: loadingIndicator

        anchors.centerIn: parent
        asynchronous: true
        active: opacity > 0
        opacity: 0

        sourceComponent: ColumnLayout {
            spacing: Tokens.spacing.large

            StyledRect {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: shape.implicitSize + Tokens.padding.medium * 2
                implicitHeight: shape.implicitSize + Tokens.padding.medium * 2
                color: Colours.palette.m3primaryContainer
                radius: Tokens.rounding.full

                LoadingIndicator {
                    id: shape

                    anchors.centerIn: parent
                    implicitSize: Math.round(Tokens.sizes.dashboard.mediaSectionWidth / 5)
                    containsIcon: true // This removes the pentagon, which is not centered
                }
            }

            StyledText {
                text: Tr.tr("Loading lyrics...")
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.title.medium
            }
        }

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }
    }

    Loader {
        id: noLyrics

        anchors.centerIn: parent
        asynchronous: true
        active: opacity > 0
        opacity: 0

        sourceComponent: ColumnLayout {
            spacing: Tokens.spacing.small

            MaterialIcon {
                Layout.alignment: Qt.AlignHCenter
                text: "sentiment_sad"
                fontStyle: Tokens.font.icon.builders.large.scale(2).build()
                color: Colours.palette.m3outline
            }

            StyledText {
                text: Tr.tr("No lyrics found")
                color: Colours.palette.m3outline
                font: Tokens.font.title.medium
            }
        }
    }

    StyledListView {
        id: lyrics

        anchors.fill: parent
        anchors.topMargin: parent.height * root.fadeAmount / 2
        anchors.bottomMargin: parent.height * root.fadeAmount / 2

        displayMarginBeginning: anchors.topMargin
        displayMarginEnd: anchors.bottomMargin

        model: root.lyricList
        Component.onCompleted: {
            currentIndex = Qt.binding(() => {
                model; // Force update when lyrics change
                return Lyrics.indexForTime(clock.position);
            });
            positionViewAtIndex(currentIndex, ListView.Center);
        }
        onModelChanged: Qt.callLater(() => positionViewAtIndex(currentIndex, ListView.Center))

        highlightRangeMode: ListView.ApplyRange
        highlightMoveDuration: Tokens.anim.durations.large
        highlightMoveVelocity: -1
        preferredHighlightBegin: (height - (currentItem?.implicitHeight ?? 0)) / 2
        preferredHighlightEnd: (height + (currentItem?.implicitHeight ?? 0)) / 2

        spacing: Tokens.spacing.small
        opacity: 0
        enabled: opacity > 0

        delegate: LyricLine {
            id: lyric

            required property var modelData
            required property int index
            // 1 for the line being sung and 0 for the rest; the halo follows it the same way
            property real effectScale: ListView.isCurrentItem ? 1 : 0

            anchors.left: lyrics.contentItem.left
            anchors.right: lyrics.contentItem.right

            line: modelData
            lineIndex: index
            time: clock.position
            current: ListView.isCurrentItem
            // The sweep runs from the outline colour up to the brightest text colour, rather
            // than from the text colour across to the accent. A neutral scheme has no accent to
            // speak of - on this one primary and onSurface are 1.3:1 apart and primary is the
            // darker of the two, so a word got slightly *dimmer* as it was sung and the sweep was
            // invisible. Lightness is the one channel every scheme has, so the sung words simply
            // get brighter; which line is current is carried by the halo (glow below).
            dim: mouse.containsMouse ? Colours.palette.m3onSurfaceVariant : Colours.palette.m3outline
            lit: Colours.palette.m3onSurface
            glow: lyric.effectScale

            Behavior on effectScale {
                Anim {
                    type: Anim.SlowEffects
                }
            }

            MouseArea {
                id: mouse

                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: {
                    if (root.source.available)
                        root.source.seek(Lyrics.timeForIndex(lyric.index));
                }
            }
        }

        Behavior on opacity {
            Anim {
                type: Anim.SlowEffects
            }
        }
    }

    Behavior on lyricList {
        SequentialAnimation {
            Anim {
                target: lyrics
                property: "opacity"
                to: 0
                type: Anim.DefaultEffects
            }
            PropertyAction {}
            Anim {
                target: lyrics
                property: "opacity"
                to: 1
                type: Anim.SlowEffects
            }
        }
    }
}
