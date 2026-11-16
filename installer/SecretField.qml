import QtQuick

// The sudo password, shaped the way the shell's own lock screen shapes it: a
// pill with no border, the lock icon doubling as the reveal toggle, each
// character a dot that pops in, and a submit button that only fills in once
// there is something to send. The lock screen draws its dots with MaterialShape
// from the M3Shapes module, which is one of the packages this installer is
// still busy installing -- so the shape-into-circle morph is done here with a
// radius and a rotation instead.
//
// It is typed here, handed to the runner once and never kept: nothing writes it
// to disk, and the field clears the moment it is sent.
Rectangle {
    id: field

    property alias text: input.text
    property string placeholder: "Enter your password"
    property bool failed
    property bool reveal
    // the most the pill may grow to; the parent gives it the room it has
    property real maxWidth: Theme.dp(420)

    readonly property int dotSize: Theme.dp(11)
    readonly property int dotGap: Theme.dp(7)
    readonly property int pad: Theme.dp(6)
    readonly property real sideSize: field.implicitHeight - field.pad * 2
    // narrow around the placeholder until there is something to show, the way
    // the lock screen's grows as you type
    readonly property real contentWidth: input.text.length === 0 ? ph.width : field.reveal ? Math.max(Theme.dp(40), input.contentWidth) : input.text.length * (field.dotSize + field.dotGap) - field.dotGap

    signal accepted(string value)

    // the field is asked for at the moment it appears, so answering needs no
    // click first
    function focusInput(): void {
        input.forceActiveFocus();
    }

    function take(): string {
        const v = input.text;
        input.text = "";
        field.reveal = false;
        return v;
    }

    implicitHeight: Theme.dp(52)
    implicitWidth: Math.min(field.maxWidth, field.sideSize * 2 + field.pad * 2 + Theme.dp(28) + field.contentWidth)
    radius: height / 2
    color: Theme.bgTile

    Behavior on implicitWidth {
        NumberAnimation {
            duration: Theme.durLong
            easing.type: Theme.easeStandard
        }
    }

    TextMetrics {
        id: ph

        text: field.placeholder
        font: phText.font
    }

    // left: the lock, which is also how you reveal what you typed
    Rectangle {
        id: lockBtn

        anchors.left: parent.left
        anchors.leftMargin: field.pad
        anchors.verticalCenter: parent.verticalCenter
        width: field.sideSize
        height: field.sideSize
        radius: height / 2
        color: lockArea.containsMouse ? Theme.alpha(Theme.text, 0.08) : "transparent"

        Icon {
            anchors.centerIn: parent
            name: field.reveal ? "visibility" : field.failed ? "lock_open" : "lock"
            size: Theme.dp(20)
            fill: field.reveal ? 1 : 0
            color: field.failed ? Theme.error : Theme.subtext
        }

        MouseArea {
            id: lockArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: field.reveal = !field.reveal
        }
    }

    // middle: the placeholder, then the dots that replace it
    Item {
        id: middle

        anchors.left: lockBtn.right
        anchors.right: submit.left
        anchors.leftMargin: Theme.dp(10)
        anchors.rightMargin: Theme.dp(10)
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height
        clip: true

        Text {
            id: phText

            anchors.centerIn: parent
            text: ph.text
            color: field.failed ? Theme.error : Theme.subtextDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontBodyMd
            opacity: input.text.length === 0 ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.durShort
                }
            }
        }

        // the real field: it takes the keys, and shows them only when revealed
        TextInput {
            id: input

            anchors.centerIn: parent
            width: Math.min(parent.width, Math.max(Theme.dp(1), contentWidth))
            echoMode: field.reveal ? TextInput.Normal : TextInput.NoEcho
            color: Theme.text
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontBodyMd
            selectByMouse: true
            selectionColor: Theme.alpha(Theme.accent, 0.3)
            selectedTextColor: Theme.text
            opacity: field.reveal ? 1 : 0
            onAccepted: field.accepted(field.take())
        }

        // one dot a character, each popping in from a rounded square the way the
        // lock screen's shapes settle into circles
        Row {
            anchors.centerIn: parent
            spacing: field.dotGap
            visible: !field.reveal

            Repeater {
                model: input.text.length

                Rectangle {
                    id: dot

                    width: field.dotSize
                    height: field.dotSize
                    radius: width / 2
                    color: field.failed ? Theme.error : Theme.text

                    Component.onCompleted: pop.start()

                    ParallelAnimation {
                        id: pop

                        NumberAnimation {
                            target: dot
                            property: "scale"
                            from: 0.2
                            to: 1
                            duration: 320
                            easing.type: Easing.OutBack
                        }

                        NumberAnimation {
                            target: dot
                            property: "radius"
                            from: field.dotSize * 0.22
                            to: field.dotSize / 2
                            duration: 300
                            easing.type: Easing.OutCubic
                        }

                        NumberAnimation {
                            target: dot
                            property: "rotation"
                            from: 45
                            to: 0
                            duration: 300
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }
        }
    }

    // right: nothing to press until there is something to send
    Rectangle {
        id: submit

        readonly property bool ready: input.text.length > 0

        anchors.right: parent.right
        anchors.rightMargin: field.pad
        anchors.verticalCenter: parent.verticalCenter
        width: field.sideSize
        height: field.sideSize
        radius: height / 2
        color: submit.ready ? Theme.accent : Theme.alpha(Theme.text, 0.07)
        scale: !submit.ready ? 0.62 : sendArea.pressed ? 0.88 : sendArea.containsMouse ? 1.06 : 1

        Behavior on scale {
            NumberAnimation {
                duration: Theme.durShort
                easing.type: Easing.OutBack
            }
        }

        Behavior on color {
            ColorAnimation {
                duration: Theme.durShort
            }
        }

        Icon {
            anchors.centerIn: parent
            name: "arrow_forward"
            size: Theme.dp(19)
            color: submit.ready ? Theme.onAccent : Theme.subtextDim
            opacity: submit.ready ? 1 : 0.7
        }

        MouseArea {
            id: sendArea

            anchors.fill: parent
            enabled: submit.ready
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: field.accepted(field.take())
        }
    }
}
