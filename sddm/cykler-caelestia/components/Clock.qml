import QtQuick

// the hour over the minute, material you's own lock clock. it steps aside —
// smaller, quieter — the moment the field becomes the point of the screen
Item {
    id: clock

    property real unit: Theme.dp(160)
    property real k: Lock.focused ? 0.52 : 1

    implicitWidth: Math.max(stack.implicitWidth, meta.implicitWidth)
    implicitHeight: stack.implicitHeight * clock.k + Theme.dp(18) + meta.implicitHeight

    Behavior on k {
        NumberAnimation {
            duration: Theme.ms(520)
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.easeEmphasizedDecel
        }

    }

    Item {
        id: stack

        implicitWidth: Math.max(hour.implicitWidth, minute.implicitWidth + (ampm.visible ? ampm.implicitWidth + Theme.dp(12) : 0))
        implicitHeight: Math.round(clock.unit * 1.64)
        width: implicitWidth
        height: implicitHeight * clock.k
        anchors.horizontalCenter: parent.horizontalCenter
        transformOrigin: Item.Top
        scale: clock.k

        Text {
            id: hour

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.horizontalCenterOffset: minute.anchors.horizontalCenterOffset

            y: 0
            height: Math.round(clock.unit * 0.82)
            verticalAlignment: Text.AlignVCenter
            text: Lock.hourText
            color: Theme.clockHour
            font.family: Theme.fontFamily
            font.pixelSize: Math.round(clock.unit)
            font.variableAxes: Theme.axes(Math.round(clock.unit), 560, 100)
            font.weight: Font.DemiBold
            font.letterSpacing: -Math.round(clock.unit * 0.03)
        }

        Text {
            id: minute

            // the minute and the am/pm beside it centre as a pair, so the
            // meridiem does not drag the whole clock off to the left
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.horizontalCenterOffset: ampm.visible ? -Math.round((ampm.implicitWidth + Theme.dp(12)) / 2) : 0
            y: Math.round(clock.unit * 0.82)
            height: Math.round(clock.unit * 0.82)
            verticalAlignment: Text.AlignVCenter
            text: Lock.minuteText
            color: Theme.accent
            font.family: Theme.fontFamily
            font.pixelSize: Math.round(clock.unit)
            font.variableAxes: Theme.axes(Math.round(clock.unit), 560, 100)
            font.weight: Font.DemiBold
            font.letterSpacing: -Math.round(clock.unit * 0.03)
        }

        Text {
            id: ampm

            anchors.left: minute.right
            anchors.leftMargin: Theme.dp(12)
            anchors.bottom: minute.bottom
            anchors.bottomMargin: Math.round(clock.unit * 0.16)
            text: Lock.meridiem
            visible: Lock.meridiem !== ""
            color: Theme.alpha(Theme.accentMuted, 0.7)
            font.family: Theme.fontFamily
            font.pixelSize: Math.round(clock.unit * 0.16)
            font.variableAxes: Theme.axes(Math.round(clock.unit * 0.16), 520, 0)
            font.weight: Font.Medium
        }

    }

    Column {
        id: meta

        anchors.top: stack.bottom
        anchors.topMargin: Theme.dp(18)
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Theme.dp(4)

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Lock.dateText
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontTitleLg
            font.variableAxes: Theme.axes(Theme.fontTitleLg, 520, 0)
            font.weight: Font.Medium
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Lock.greeting + (Lock.displayName !== "" ? ", " + Lock.displayName.split(" ")[0] : "")
            color: Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontBodyLg
            font.variableAxes: Theme.axes(Theme.fontBodyLg, 420, 0)
        }

    }

}
