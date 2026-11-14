import QtQuick
import Quickshell

// everything from the password on: what it is doing, what it wants answered,
// and the log underneath it all
Item {
    id: card

    property bool shown
    // where the window is running, when that is not Hyprland
    property string elsewhere

    signal leave(bool start)

    readonly property var ask: Install.ask
    readonly property bool asking: !!card.ask

    opacity: card.shown ? 1 : 0
    visible: opacity > 0.01
    enabled: card.shown

    function dismiss(): void {
        if (Install.running)
            Install.cancel();
        else
            card.leave(false);
    }

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.durShort
        }
    }

    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: Theme.dp(28)
        spacing: Theme.dp(14)

        // -- what it is doing ------------------------------------------

        Row {
            spacing: Theme.dp(12)
            width: parent.width

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: Install.ok ? "check_circle" : Install.finished ? "error" : card.asking && card.ask.kind === "password" ? "lock" : "downloading"
                size: Theme.dp(26)
                fill: Install.finished ? 1 : 0
                color: Install.ok ? Theme.accent : Install.finished ? Theme.error : Theme.accent
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Install.ok ? "Caelestia is installed" : Install.cancelled ? "Stopped" : Install.finished ? "That did not finish" : Install.phaseText
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontTitleLg
                font.variableAxes: Theme.axes(Theme.fontTitleLg, 560, 0)
            }
        }

        // -- how far through -------------------------------------------

        Rectangle {
            width: parent.width
            height: Theme.dp(6)
            radius: height / 2
            color: Theme.bgSunken
            visible: !Install.finished

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, Install.progress))
                height: parent.height
                radius: height / 2
                color: Theme.accent

                Behavior on width {
                    NumberAnimation {
                        duration: Theme.durLong
                        easing.type: Theme.easeStandard
                    }
                }
            }
        }

        // -- what it is asking -----------------------------------------

        Column {
            width: parent.width
            spacing: Theme.dp(10)
            visible: card.asking

            Text {
                width: parent.width
                text: card.asking ? (card.ask.kind === "password" ? (card.ask.retry ? "That password was not right. Try again." : "Your password, so it can install as root.") : card.ask.text) : ""
                color: card.asking && card.ask.retry ? Theme.error : Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontBodyMd
                wrapMode: Text.WordWrap
                lineHeight: 1.3
            }

            SecretField {
                id: secret

                width: parent.width
                visible: card.asking && card.ask.kind === "password"
                failed: card.asking && card.ask.retry
                onAccepted: (value) => Install.answer(value)
            }

            Row {
                spacing: Theme.dp(8)
                visible: card.asking && card.ask.kind === "yesno"

                Button {
                    text: "Yes"
                    variant: "filled"
                    onClicked: Install.answer("y")
                }

                Button {
                    text: "No"
                    variant: "tonal"
                    onClicked: Install.answer("n")
                }
            }

            Button {
                text: "Send"
                variant: "filled"
                icon: "arrow_forward"
                visible: card.asking && card.ask.kind === "password"
                onClicked: Install.answer(secret.take())
            }
        }

        // -- the log ----------------------------------------------------

        Rectangle {
            width: parent.width
            height: Theme.dp(190)
            radius: Theme.dp(16)
            color: Theme.bgSunken
            clip: true
            visible: !card.asking || card.ask.kind !== "password"

            ListView {
                id: logView

                anchors.fill: parent
                anchors.margins: Theme.dp(14)
                model: Install.log
                spacing: Theme.dp(1)
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                delegate: Text {
                    required property string modelData

                    width: logView.width
                    text: modelData
                    color: Theme.subtextDim
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontBodySm
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                // follow the tail, the way a terminal does
                onCountChanged: logView.positionViewAtEnd()
            }

            Text {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: Theme.dp(14)
                text: Install.live
                color: Theme.subtext
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontBodySm
                elide: Text.ElideRight
                visible: Install.live !== ""
            }
        }

        // -- what went wrong, or what comes next -------------------------

        Text {
            width: parent.width
            text: Install.finished && !Install.ok ? (Install.reason !== "" ? Install.reason : "The log above says where it stopped. Nothing was left half-installed that a second run cannot put right.") : Install.warnings.length > 0 ? Install.warnings.join("\n") : ""
            color: Install.ok ? Theme.subtext : Theme.error
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontBodySm
            wrapMode: Text.WordWrap
            visible: text !== ""
        }

        Text {
            width: parent.width
            text: card.elsewhere !== "" ? "This is " + card.elsewhere + ", not Hyprland. Log out and back into Hyprland to see the shell." : "Start it now, or it comes up by itself at your next login."
            color: Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontBodySm
            wrapMode: Text.WordWrap
            visible: Install.ok
        }

        Item {
            width: parent.width
            height: Theme.dp(44)

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.dp(8)

                Button {
                    text: Install.finished ? "Close" : "Stop"
                    variant: "text"
                    onClicked: card.dismiss()
                }

                Button {
                    text: card.elsewhere !== "" ? "Log out" : "Start the shell"
                    variant: "filled"
                    icon: card.elsewhere !== "" ? "logout" : "play_arrow"
                    visible: Install.ok
                    onClicked: card.leave(true)
                }
            }
        }
    }
}
