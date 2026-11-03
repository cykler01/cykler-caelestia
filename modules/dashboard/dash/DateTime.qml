pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.modules.lock.center as LockCenter

Item {
    id: root

    // Analogue dial instead of the stacked digital readout, as on the lock screen
    readonly property bool analogue: Config.dashboard.analogueClock

    anchors.top: parent.top
    anchors.bottom: parent.bottom
    implicitWidth: Tokens.sizes.dashboard.dateTimeWidth

    // This card shows seconds, so the shared clock has to tick every second for as long as it exists
    Component.onCompleted: Time.secondsUsers++
    Component.onDestruction: Time.secondsUsers--

    ColumnLayout {
        visible: !root.analogue
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        StyledText {
            Layout.bottomMargin: -(font.pointSize * 0.4)
            Layout.alignment: Qt.AlignHCenter
            text: Time.hourStr
            color: Colours.palette.m3secondary
            font: Tokens.font.clock.size(28).weight(Font.DemiBold).build()
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: "•••"
            color: Colours.palette.m3primary
            font: Tokens.font.clock.size(28 * 0.9).build()
        }

        StyledText {
            Layout.topMargin: -(font.pointSize * 0.4)
            Layout.alignment: Qt.AlignHCenter
            text: Time.minuteStr
            color: Colours.palette.m3secondary
            font: Tokens.font.clock.size(28).weight(Font.DemiBold).build()
        }

        Loader {
            Layout.topMargin: -(((item as StyledText)?.font.pointSize ?? 0) * 0.4)
            Layout.alignment: Qt.AlignHCenter
            asynchronous: true
            active: Config.dashboard.showClockSeconds
            visible: active

            sourceComponent: StyledText {
                text: "•••"
                color: Colours.palette.m3primary
                font: Tokens.font.clock.size(28 * 0.9).build()
            }
        }
        Loader {
            Layout.topMargin: -(((item as StyledText)?.font.pointSize ?? 0) * 0.4)
            Layout.alignment: Qt.AlignHCenter
            asynchronous: true
            active: Config.dashboard.showClockSeconds
            visible: active

            sourceComponent: StyledText {
                text: Time.format("ss")
                color: Colours.palette.m3secondary
                font: Tokens.font.clock.size(28).weight(Font.DemiBold).build()
            }
        }

        Loader {
            asynchronous: true
            Layout.alignment: Qt.AlignHCenter

            active: Units.twelveHourClock
            visible: active

            sourceComponent: StyledText {
                text: Time.amPmStr
                color: Colours.palette.m3primary
                font: Tokens.font.clock.size(18).weight(Font.DemiBold).build()
            }
        }
    }

    // Same dial the lock screen uses, scaled to fit inside the card
    LockCenter.AnalogueClock {
        anchors.centerIn: parent
        visible: root.analogue
        centerScale: Math.max(0.4, Math.min(1, (Math.min(root.width, root.height) - Tokens.padding.largeIncreased * 2) / 220))
    }
}
