pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.modules.lock

// After the Windows 10/11 and GNOME lock screens: at rest it's only a big clock and the date down
// in the bottom-left corner over the wallpaper, with the weather under them and the status pills in
// the opposite corner. The first key or click lifts the curtain: the clock slides up and away and
// the sign-in (large profile picture, greeting, password field) comes up in the middle. It drops
// back once it's been left alone with nothing typed.
//
// The password field is there, and holds the keyboard, the whole time - only hidden while the
// curtain is down - so the key that lifts it still lands in the field
Item {
    id: root

    required property var lock

    readonly property real uiScale: Math.max(0.6, Math.min(1.6, height / 1080))
    readonly property real margin: 72 * uiScale

    readonly property var pam: lock?.pam ?? null
    // Anything going on with the sign-in holds the curtain up: something typed, a check under way,
    // or a message (wrong password, too many tries) that has to be seen
    readonly property bool busy: !!pam && (pam.buffer.length > 0 || pam.passwd.active || pam.state !== Pam.None)
    property bool lifted: false
    readonly property bool up: lifted || busy

    function lift(): void {
        root.lifted = true;
        dropTimer.restart();
    }

    onBusyChanged: {
        if (root.busy)
            root.lift();
        else
            dropTimer.restart();
    }

    Timer {
        id: dropTimer

        interval: 20000
        onTriggered: {
            if (root.busy)
                restart();
            else
                root.lifted = false;
        }
    }

    // A little more shade over the wallpaper while signing in, so the card in the middle reads
    Rectangle {
        anchors.fill: parent
        color: Colours.palette.m3scrim
        opacity: root.up ? 0.25 : 0

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }
    }

    // The curtain: clock, date and weather in the corner
    ColumnLayout {
        id: curtain

        x: root.margin
        y: root.height - height - root.margin * 1.2 + (root.up ? -root.height * 0.12 : 0)
        spacing: Tokens.spacing.medium * root.uiScale
        opacity: root.up ? 0 : 1

        Behavior on y {
            Anim {
                type: Anim.SlowSpatial
            }
        }

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }

        BigClock {
            fontScale: 6 * root.uiScale
            stacked: false
        }

        StyledText {
            Layout.topMargin: Tokens.spacing.medium * root.uiScale
            text: Time.format("dddd, d MMMM")
            color: Colours.palette.m3onSurface
            font: Tokens.font.title.builders.large.scale(root.uiScale * 1.25).weight(Font.DemiBold).build()
        }

        WeatherPill {
            Layout.topMargin: Tokens.spacing.large * root.uiScale
            uiScale: root.uiScale * 0.9
        }
    }

    StatusChips {
        x: root.width - width - root.margin
        y: root.height - height - root.margin
        uiScale: root.uiScale * 0.9
        layoutDirection: Qt.RightToLeft
    }

    StyledText {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.margin
        text: Tr.tr("Press any key or click to unlock")
        color: Colours.palette.m3onSurfaceVariant
        font: Tokens.font.label.builders.large.scale(root.uiScale).build()
        opacity: root.up ? 0 : 0.7

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }
    }

    // The sign-in, under the curtain
    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: root.up ? 0 : root.height * 0.06
        spacing: Tokens.spacing.extraLarge * root.uiScale
        opacity: root.up ? 1 : 0

        Behavior on anchors.verticalCenterOffset {
            Anim {
                type: Anim.SlowSpatial
            }
        }

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }

        LoginCard {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 380 * root.uiScale
            lock: root.lock
            uiScale: root.uiScale
            framed: false
            showGreeting: true
            avatarSize: 130 * root.uiScale
        }

        SessionBar {
            Layout.alignment: Qt.AlignHCenter
            uiScale: root.uiScale * 0.85
            // Out of reach, not only out of sight, while the curtain is down
            enabled: root.up
        }
    }

    // While the curtain is down a click anywhere lifts it, rather than landing on the hidden
    // sign-in under it. Plain presses only: the hover handlers further up still see the pointer
    MouseArea {
        anchors.fill: parent
        enabled: !root.up
        visible: enabled
        onPressed: root.lift()
    }
}
