import QtQuick

// M3 button in the three variants the installer uses: filled for the one action
// that matters, tonal beside it, text for the way out
Item {
    id: btn

    property string text
    property string icon
    property string variant: "filled" // filled | tonal | text
    property bool disabled

    signal clicked

    readonly property color fg: btn.variant === "filled" ? Theme.onAccent : Theme.accent
    readonly property color bgc: btn.variant === "filled" ? Theme.accent : btn.variant === "tonal" ? Theme.bgHigh : "transparent"

    implicitWidth: row.implicitWidth + Theme.dp(48)
    implicitHeight: Theme.dp(40)
    opacity: btn.disabled ? 0.38 : 1

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: btn.bgc

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: Theme.alpha(btn.fg, area.pressed ? 0.12 : area.containsMouse ? 0.08 : 0)

            Behavior on color {
                ColorAnimation {
                    duration: Theme.durShort
                }
            }
        }
    }

    Row {
        id: row

        anchors.centerIn: parent
        spacing: Theme.dp(8)

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: btn.icon
            size: Theme.dp(18)
            color: btn.fg
            visible: btn.icon !== ""
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: btn.text
            color: btn.fg
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontBodyMd
            font.variableAxes: Theme.axes(Theme.fontBodyMd, 560, 0)
        }
    }

    MouseArea {
        id: area

        anchors.fill: parent
        enabled: !btn.disabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.clicked()
    }
}
