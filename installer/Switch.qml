import QtQuick

// M3 switch: the thumb grows when it is on, and again under the finger
Item {
    id: sw

    property bool checked
    property bool disabled

    signal toggled

    implicitWidth: Theme.dp(52)
    implicitHeight: Theme.dp(32)
    opacity: sw.disabled ? 0.38 : 1

    Rectangle {
        id: track

        anchors.fill: parent
        radius: height / 2
        color: sw.checked ? Theme.accent : Theme.bgSunken
        border.width: sw.checked ? 0 : Theme.dp(2)
        border.color: Theme.outline

        Behavior on color {
            ColorAnimation {
                duration: Theme.durShort
            }
        }
    }

    Rectangle {
        id: thumb

        readonly property real grown: area.pressed ? Theme.dp(28) : sw.checked ? Theme.dp(24) : Theme.dp(16)

        width: thumb.grown
        height: thumb.grown
        radius: height / 2
        anchors.verticalCenter: parent.verticalCenter
        x: sw.checked ? parent.width - width - Theme.dp(4) : Theme.dp(8)
        color: sw.checked ? Theme.onAccent : Theme.outline

        Behavior on x {
            NumberAnimation {
                duration: Theme.durShort
                easing.type: Theme.easeStandard
            }
        }

        Behavior on width {
            NumberAnimation {
                duration: Theme.durShort
                easing.type: Theme.easeStandard
            }
        }

        Behavior on height {
            NumberAnimation {
                duration: Theme.durShort
                easing.type: Theme.easeStandard
            }
        }

        Behavior on color {
            ColorAnimation {
                duration: Theme.durShort
            }
        }

        Icon {
            anchors.centerIn: parent
            name: "check"
            size: Theme.dp(16)
            weight: 600
            color: Theme.accent
            opacity: sw.checked && !area.pressed ? 1 : 0
            visible: opacity > 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.durShort
                }
            }
        }
    }

    MouseArea {
        id: area

        anchors.fill: parent
        enabled: !sw.disabled
        cursorShape: Qt.PointingHandCursor
        onClicked: sw.toggled()
    }
}
