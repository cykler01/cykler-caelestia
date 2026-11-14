import QtQuick
import Quickshell.Io

// what you are getting, in turn while the installer works. screenshots are not
// in the repo, so each slide is its symbol over the shipped wallpaper; drop a
// <name>.png into assets/installer and that slide shows the picture instead.
Item {
    id: tour

    readonly property var slides: [{
        "file": "bar",
        "title": "The bar",
        "blurb": "Workspaces, tray and the status of everything, along one edge"
    }, {
        "file": "notch",
        "title": "The notch",
        "blurb": "Notifications, music and the session drop out of the top"
    }, {
        "file": "launcher",
        "title": "The launcher",
        "blurb": "Apps, calculator, emoji and actions behind one keystroke"
    }, {
        "file": "dashboard",
        "title": "The dashboard",
        "blurb": "Media, weather, resources and the calendar on one surface"
    }, {
        "file": "lock",
        "title": "The lock screen",
        "blurb": "Your wallpaper, your palette, and the clock over it"
    }, {
        "file": "colours",
        "title": "Colours from your wallpaper",
        "blurb": "A Material palette drawn from the picture, everywhere at once"
    }]

    property int index: 0
    readonly property var slide: tour.slides[tour.index]
    // the screenshots that are actually there, asked once: a missing one is
    // ordinary, and Image would complain about each of them by name
    property var shots: []
    readonly property real footHeight: Theme.dp(96)

    Process {
        running: true
        command: ["sh", "-c", "cd \"$1\" 2>/dev/null && ls *.png 2>/dev/null | sed 's/\\.png$//'", "sh", Qt.resolvedUrl("../assets/installer").toString().replace("file://", "")]

        stdout: StdioCollector {
            onStreamFinished: tour.shots = this.text.split("\n").filter(l => l !== "")
        }
    }

    Timer {
        interval: 5200
        running: true
        repeat: true
        onTriggered: tour.index = (tour.index + 1) % tour.slides.length
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.shapeXl
        color: Theme.bgTile
        clip: true

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Theme.alpha(Theme.accent, Theme.isLight ? 0.1 : 0.08)
                }

                GradientStop {
                    position: 1
                    color: Theme.alpha(Theme.bgSunken, 0.9)
                }
            }
        }

        // the slide itself, swapped on a fade so nothing jumps
        Item {
            id: stage

            anchors.fill: parent
            anchors.margins: Theme.dp(32)

            Image {
                id: shot

                anchors.centerIn: parent
                width: Math.min(parent.width, parent.height * 16 / 9)
                height: width * 9 / 16
                source: tour.shots.indexOf(tour.slide.file) === -1 ? "" : Qt.resolvedUrl("../assets/installer/" + tour.slide.file + ".png")
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                visible: shot.status === Image.Ready
                opacity: visible ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.durLong
                    }
                }
            }

            Preview {
                id: drawing

                anchors.fill: parent
                anchors.bottomMargin: tour.footHeight
                kind: tour.slide.file
                visible: shot.status !== Image.Ready
                opacity: visible ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.durLong
                    }
                }
            }
        }

        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Theme.dp(32)
            spacing: Theme.dp(6)

            Text {
                text: tour.slide.title
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontTitleLg
                font.variableAxes: Theme.axes(Theme.fontTitleLg, 560, 0)
            }

            Text {
                width: parent.width
                text: tour.slide.blurb
                color: Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontBodyMd
                wrapMode: Text.WordWrap
            }

            Item {
                width: 1
                height: Theme.dp(10)
            }

            Row {
                spacing: Theme.dp(6)

                Repeater {
                    model: tour.slides.length

                    Rectangle {
                        required property int index

                        width: index === tour.index ? Theme.dp(22) : Theme.dp(6)
                        height: Theme.dp(6)
                        radius: height / 2
                        color: index === tour.index ? Theme.accent : Theme.outline

                        Behavior on width {
                            NumberAnimation {
                                duration: Theme.durShort
                                easing.type: Theme.easeStandard
                            }
                        }
                    }
                }
            }
        }
    }
}
