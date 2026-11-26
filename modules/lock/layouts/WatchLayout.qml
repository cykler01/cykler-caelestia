pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import Caelestia.Config
import qs.components
import qs.services
import qs.utils
import qs.modules.lock.center

// After a smartwatch face (watchOS, Wear OS, Pebble): a big analogue dial in the middle of the
// screen with a row of small complications under it - the date, the weather and the battery -
// and the sign-in below those. The status pills and session actions keep to the corners
Item {
    id: root

    required property var lock

    readonly property real uiScale: Math.max(0.6, Math.min(1.6, height / 1080))
    readonly property real margin: 72 * uiScale

    readonly property var battery: UPower.displayDevice
    readonly property bool charging: [UPowerDeviceState.Charging, UPowerDeviceState.FullyCharged, UPowerDeviceState.PendingCharge].includes(battery.state)

    StatusChips {
        x: root.width - width - root.margin
        y: root.margin
        uiScale: root.uiScale * 0.9
        layoutDirection: Qt.RightToLeft
    }

    SessionBar {
        x: root.width - width - root.margin
        y: root.height - height - root.margin
        uiScale: root.uiScale
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: Tokens.spacing.extraLarge * root.uiScale

        // The dial on a disc of its own, like a watch face, so the hands read against any wallpaper
        StyledRect {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: dial.implicitWidth + Tokens.padding.extraLarge * 2 * root.uiScale
            implicitHeight: implicitWidth
            radius: implicitWidth / 2
            color: Qt.alpha(Colours.palette.m3surface, 0.45)

            AnalogueClock {
                id: dial

                anchors.centerIn: parent
                centerScale: 1.75 * root.uiScale
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Tokens.spacing.medium * root.uiScale

            Complication {
                icon: "calendar_today"
                text: Time.format("ddd d")
            }

            Complication {
                visible: !!Weather.cc
                icon: Weather.icon
                text: Weather.temp
            }

            Complication {
                visible: root.battery.isLaptopBattery
                icon: Icons.getBatteryIcon(root.battery.percentage, root.charging)
                text: Strings.percentOne(root.battery.percentage)
            }
        }

        LoginCard {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 360 * root.uiScale
            Layout.topMargin: Tokens.spacing.large * root.uiScale
            lock: root.lock
            uiScale: root.uiScale
            framed: false
            inline: true
            avatarSize: 52 * root.uiScale
        }
    }

    // One small round-ended reading under the dial, icon then value
    component Complication: StyledRect {
        id: comp

        property string icon
        property string text

        implicitWidth: compRow.implicitWidth + Tokens.padding.large * 2 * root.uiScale
        implicitHeight: compRow.implicitHeight + Tokens.padding.small * 2 * root.uiScale
        radius: Tokens.rounding.full
        color: Colours.tPalette.m3surfaceContainer

        RowLayout {
            id: compRow

            anchors.centerIn: parent
            spacing: Tokens.spacing.small * root.uiScale

            MaterialIcon {
                text: comp.icon
                color: Colours.palette.m3primary
                fontStyle: Tokens.font.icon.builders.medium.scale(root.uiScale).build()
            }

            StyledText {
                text: comp.text
                color: Colours.palette.m3onSurface
                font: Tokens.font.label.builders.large.scale(root.uiScale).weight(Font.DemiBold).build()
            }
        }
    }
}
