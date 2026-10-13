import "weather"
import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

StyledRect {
    id: root

    required property int rootHeight
    // Whether the forecast fits is decided from its real, measured height (loaded eagerly just
    // to measure it) rather than a flat pixel constant - and it's an all-or-nothing decision: if
    // it doesn't fully fit, hide it rather than show a partially cropped sliver of it
    readonly property bool showForecast: forecast.item !== null && root.rootHeight >= content.anchors.topMargin + brief.implicitHeight + content.spacing + forecast.item.implicitHeight + content.anchors.bottomMargin

    implicitHeight: {
        const base = brief.implicitHeight + content.anchors.topMargin;
        if (showForecast)
            return base + content.spacing + forecast.implicitHeight + content.anchors.bottomMargin;
        return base + content.anchors.bottomMargin;
    }
    radius: Tokens.rounding.extraLarge
    color: Colours.tPalette.m3surfaceContainer
    // The card's actual height is a fixed share of its column, not this implicitHeight - if the
    // forecast threshold is a bit generous for that share, clip rather than overlap or bleed into
    // the widget below
    clip: true

    Timer {
        running: true
        triggeredOnStart: true
        repeat: true
        interval: 900000 // 15 minutes
        onTriggered: Weather.reload()
    }

    ColumnLayout {
        id: content

        // Stacked top-to-bottom (rather than BriefInfo anchored to the top and the forecast
        // anchored to the bottom independently) so when the card's actual height is smaller than
        // both wanted together, the forecast just gets clipped instead of overlapping BriefInfo
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: Tokens.padding.large
        anchors.bottomMargin: Tokens.padding.large
        spacing: Tokens.spacing.largeIncreased

        // With no forecast to fill the card, top-anchored brief info looks stranded near the top
        // of whatever share this widget got - centre it instead
        states: State {
            name: "noForecast"
            when: !root.showForecast

            AnchorChanges {
                target: content
                anchors.top: undefined
                anchors.verticalCenter: root.verticalCenter
            }
        }

        transitions: Transition {
            AnchorAnimation {}
        }

        BriefInfo {
            id: brief

            Layout.alignment: Qt.AlignHCenter

            rootHeight: root.rootHeight
        }

        Loader {
            id: forecast

            Layout.fillWidth: true
            // Excluded from the layout entirely when hidden (rather than just invisible) so it
            // doesn't leave a dangling gap of spacing below BriefInfo once centred. Loaded
            // eagerly regardless, purely so its real implicitHeight is known for showForecast's
            // fits-or-doesn't comparison above
            visible: root.showForecast

            active: true
            asynchronous: true

            sourceComponent: Forecast {}
        }
    }
}
