import QtQuick

Item {
    id: btn

    property string icon
    property string tooltip
    property real size: Theme.dp(40)

    signal clicked

    implicitWidth: btn.size
    implicitHeight: btn.size

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: area.containsMouse ? Theme.bgHigh : "transparent"

        Behavior on color {
            ColorAnimation {
                duration: Theme.durShort
            }
        }
    }

    Icon {
        anchors.centerIn: parent
        name: btn.icon
        size: Theme.dp(20)
        color: Theme.subtext
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.clicked()
    }

    Rectangle {
        id: tip

        visible: btn.tooltip !== "" && area.containsMouse
        anchors.top: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: Theme.dp(4)
        width: tipText.implicitWidth + Theme.dp(16)
        height: tipText.implicitHeight + Theme.dp(8)
        radius: Theme.dp(6)
        color: Theme.text
        z: 10

        Text {
            id: tipText

            anchors.centerIn: parent
            text: btn.tooltip
            color: Theme.bg
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontBodySm
        }
    }
}
