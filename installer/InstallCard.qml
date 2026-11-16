import QtQuick
import Quickshell

// everything from the password on: what it is doing, what it wants answered,
// and the log underneath it all
Item {
    id: card

    property bool shown
    // where the window is running, when that is not Hyprland
    property string elsewhere

    readonly property var ask: Install.ask
    readonly property bool asking: !!card.ask

    signal leave(bool start)

    function dismiss(): void {
        if (Install.running)
            Install.cancel();
        else
            card.leave(false);
    }

    opacity: card.shown ? 1 : 0
    visible: opacity > 0.01
    enabled: card.shown

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

                anchors.horizontalCenter: parent.horizontalCenter
                maxWidth: Math.min(parent.width, Theme.dp(340))
                visible: card.asking && card.ask.kind === "password"
                failed: card.asking && card.ask.retry
                onAccepted: (value) => Install.answer(value)
                onVisibleChanged: {
                    if (secret.visible)
                        secret.focusInput();
                }
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
                    // a pacman error puts what actually went wrong at the END of
                    // the line, so eliding one line hid the only part worth
                    // reading. Long lines wrap; a runaway one still stops at six
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    maximumLineCount: 6
                    elide: Text.ElideRight
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

        // -- what to type once it is running -----------------------------
        //
        // every one of these is a real subcommand of the installed cli, taken
        // from `caelestia --help` and `caelestia shell --help`
        Column {
            width: parent.width
            spacing: Theme.dp(5)
            visible: Install.ok

            Text {
                text: "From a terminal, after this:"
                color: Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontBodySm
                font.variableAxes: Theme.axes(Theme.fontBodySm, 560, 0)
            }

            Item {
                width: 1
                height: Theme.dp(2)
            }

            Repeater {
                model: [
                    {
                        "cmd": "caelestia shell -d",
                        "what": "start it detached"
                    },
                    {
                        "cmd": "caelestia shell -r",
                        "what": "restart it after a change"
                    },
                    {
                        "cmd": "caelestia shell -l",
                        "what": "print its log"
                    },
                    {
                        "cmd": "caelestia scheme list",
                        "what": "the colour schemes it ships with"
                    },
                    {
                        "cmd": "caelestia -h",
                        "what": "everything else the cli does"
                    }
                ]

                Row {
                    id: hint

                    required property var modelData

                    width: parent.width
                    spacing: Theme.dp(8)

                    Text {
                        width: Theme.dp(150)
                        text: hint.modelData.cmd
                        color: Theme.accent
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontBodySm
                        elide: Text.ElideRight
                    }

                    Text {
                        text: hint.modelData.what
                        color: Theme.subtextDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontBodySm
                        elide: Text.ElideRight
                    }
                }
            }
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
