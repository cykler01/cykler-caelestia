import QtQuick

// the sudo password. it is typed here, handed to the runner once and never kept:
// nothing writes it to disk, and the field clears the moment it is sent
Rectangle {
    id: field

    property alias text: input.text
    property string placeholder: "Password"
    property bool failed

    signal accepted(string value)

    implicitHeight: Theme.dp(56)
    radius: Theme.dp(12)
    color: Theme.bgSunken
    border.width: input.activeFocus ? Theme.dp(2) : Theme.dp(1)
    border.color: field.failed ? Theme.error : input.activeFocus ? Theme.accent : Theme.outline

    function take(): string {
        const v = input.text;
        input.text = "";
        return v;
    }

    Icon {
        id: lock

        anchors.left: parent.left
        anchors.leftMargin: Theme.dp(16)
        anchors.verticalCenter: parent.verticalCenter
        name: field.failed ? "lock_open" : "lock"
        size: Theme.dp(20)
        color: field.failed ? Theme.error : Theme.subtext
    }

    TextInput {
        id: input

        anchors.left: lock.right
        anchors.right: reveal.left
        anchors.leftMargin: Theme.dp(12)
        anchors.rightMargin: Theme.dp(8)
        anchors.verticalCenter: parent.verticalCenter
        echoMode: reveal.shown ? TextInput.Normal : TextInput.Password
        passwordCharacter: "●"
        passwordMaskDelay: 320
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontBodyLg
        selectByMouse: true
        selectionColor: Theme.alpha(Theme.accent, 0.3)
        selectedTextColor: Theme.text
        focus: true
        onAccepted: field.accepted(field.take())

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: field.placeholder
            color: Theme.subtextDim
            font: input.font
            visible: input.text === "" && !input.activeFocus
        }
    }

    IconButton {
        id: reveal

        property bool shown

        anchors.right: parent.right
        anchors.rightMargin: Theme.dp(8)
        anchors.verticalCenter: parent.verticalCenter
        icon: reveal.shown ? "visibility_off" : "visibility"
        tooltip: reveal.shown ? "Hide" : "Show"
        onClicked: reveal.shown = !reveal.shown
    }
}
