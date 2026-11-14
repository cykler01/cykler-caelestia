import QtQuick

// a small drawing of the thing each slide is about, in the palette the installer
// is wearing. a photograph would say nothing about the shell, and a single
// Material symbol says only "palette" where the slide means "every colour in the
// shell comes off your wallpaper" -- so each one is the feature in miniature.
//
// if assets/installer/<kind>.png exists, Tour shows that instead: a real
// screenshot beats a drawing of one.
Item {
    id: preview

    property string kind
    // the slide's subject is lit in the accent and the rest stays context, so a
    // glance at the drawing lands on the thing the words are talking about
    function lit(what: string): bool {
        return preview.kind === what;
    }

    // the mock desktop's own surface, a shade off the window behind it
    readonly property color deskTop: Theme.alpha(Theme.accent, Theme.isLight ? 0.18 : 0.22)
    readonly property color deskBottom: Theme.alpha(Theme.bgSunken, 0.92)
    readonly property color chrome: Theme.alpha(Theme.text, 0.14)
    readonly property color chromeDim: Theme.alpha(Theme.text, 0.07)

    // the screen everything is drawn inside
    Rectangle {
        id: screen

        anchors.centerIn: parent
        width: Math.min(parent.width, parent.height * 16 / 9)
        height: width * 9 / 16
        radius: Theme.dp(14)
        clip: true

        gradient: Gradient {
            GradientStop {
                position: 0
                color: preview.deskTop
            }

            GradientStop {
                position: 1
                color: preview.deskBottom
            }
        }

        border.width: Theme.dp(1)
        border.color: Theme.alpha(Theme.text, 0.12)

        // -- the bar, on every slide but the lock screen ----------------

        Rectangle {
            id: bar

            visible: preview.kind !== "lock"
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: Theme.dp(6)
            width: Theme.dp(16)
            radius: width / 2
            color: preview.lit("bar") ? Theme.alpha(Theme.accent, 0.25) : Theme.alpha(Theme.bgTile, 0.9)
            border.width: preview.lit("bar") ? Theme.dp(1) : 0
            border.color: Theme.alpha(Theme.accent, 0.5)

            // workspaces: the active one a pill, the occupied ones squares, the rest dots
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: Theme.dp(10)
                spacing: Theme.dp(5)

                Repeater {
                    model: 5

                    Rectangle {
                        required property int index

                        readonly property bool active: index === (preview.kind === "bar" ? 1 : 0)

                        width: Theme.dp(6)
                        height: active ? Theme.dp(10) : Theme.dp(6)
                        radius: width / 2
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: active ? Theme.accent : index < 3 ? Theme.alpha(Theme.text, preview.lit("bar") ? 0.7 : 0.45) : Theme.alpha(Theme.text, preview.lit("bar") ? 0.3 : 0.18)
                    }
                }
            }

            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Theme.dp(8)
                spacing: Theme.dp(5)

                Repeater {
                    model: 3

                    Rectangle {
                        width: Theme.dp(6)
                        height: Theme.dp(6)
                        radius: Theme.dp(2)
                        color: Theme.alpha(Theme.text, 0.35)
                    }
                }
            }
        }

        // -- two windows, the backdrop for most slides ------------------

        Row {
            id: windows

            visible: preview.kind === "bar" || preview.kind === "notch" || preview.kind === "colours"
            anchors.left: bar.right
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: Theme.dp(10)
            spacing: Theme.dp(8)
            opacity: preview.kind === "colours" ? 1 : 0.75

            Rectangle {
                width: (parent.width - Theme.dp(8)) * 0.58
                height: parent.height
                radius: Theme.dp(8)
                color: preview.chrome

                Column {
                    anchors.fill: parent
                    anchors.margins: Theme.dp(8)
                    spacing: Theme.dp(5)

                    Rectangle {
                        width: Theme.dp(34)
                        height: Theme.dp(5)
                        radius: height / 2
                        color: Theme.alpha(Theme.accent, 0.8)
                    }

                    Repeater {
                        model: 4

                        Rectangle {
                            required property int index

                            width: parent.width * (index % 2 === 0 ? 0.9 : 0.65)
                            height: Theme.dp(4)
                            radius: height / 2
                            color: Theme.alpha(Theme.text, 0.2)
                        }
                    }
                }
            }

            Rectangle {
                width: (parent.width - Theme.dp(8)) * 0.42
                height: parent.height
                radius: Theme.dp(8)
                color: preview.chromeDim

                // a little content, so it does not read as a blank panel
                Column {
                    anchors.fill: parent
                    anchors.margins: Theme.dp(8)
                    spacing: Theme.dp(5)
                    visible: preview.kind !== "colours"

                    Rectangle {
                        width: Theme.dp(24)
                        height: Theme.dp(5)
                        radius: height / 2
                        color: Theme.alpha(Theme.text, 0.3)
                    }

                    Rectangle {
                        width: parent.width
                        height: Theme.dp(26)
                        radius: Theme.dp(6)
                        color: Theme.alpha(Theme.text, 0.08)
                    }

                    Repeater {
                        model: 3

                        Rectangle {
                            required property int index

                            width: parent.width * (index === 1 ? 0.7 : 0.9)
                            height: Theme.dp(4)
                            radius: height / 2
                            color: Theme.alpha(Theme.text, 0.18)
                        }
                    }
                }

                // the palette slide puts the tonal ramp in this window
                Grid {
                    anchors.centerIn: parent
                    visible: preview.kind === "colours"
                    columns: 4
                    spacing: Theme.dp(4)

                    Repeater {
                        // the tonal ramp itself, not the window's own greys: the
                        // slide is about where the colours come from
                        model: [Theme.hex("primary", "9bd0cc"), Theme.hex("primaryContainer", "255b58"), Theme.hex("secondary", "b0ccc9"), Theme.hex("secondaryContainer", "27403e"), Theme.hex("tertiary", "d5efff"), Theme.hex("tertiaryContainer", "28485a"), Theme.hex("error", "ffb4ab"), Theme.hex("surfaceContainerHighest", "1d2827")]

                        Rectangle {
                            required property color modelData

                            width: Theme.dp(14)
                            height: Theme.dp(14)
                            radius: Theme.dp(4)
                            color: modelData
                        }
                    }
                }
            }
        }

        // -- the notch ---------------------------------------------------

        Rectangle {
            visible: preview.kind === "notch"
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            width: Theme.dp(120)
            height: Theme.dp(26)
            radius: Theme.dp(13)
            color: Theme.bgSunken
            border.width: Theme.dp(1)
            border.color: Theme.alpha(Theme.accent, 0.45)

            Row {
                anchors.centerIn: parent
                spacing: Theme.dp(6)

                Rectangle {
                    width: Theme.dp(14)
                    height: Theme.dp(14)
                    radius: Theme.dp(4)
                    color: Theme.accent
                    anchors.verticalCenter: parent.verticalCenter
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.dp(3)

                    Rectangle {
                        width: Theme.dp(54)
                        height: Theme.dp(4)
                        radius: height / 2
                        color: Theme.alpha(Theme.text, 0.75)
                    }

                    Rectangle {
                        width: Theme.dp(34)
                        height: Theme.dp(3)
                        radius: height / 2
                        color: Theme.alpha(Theme.text, 0.35)
                    }
                }
            }
        }

        // -- the launcher -------------------------------------------------
        //
        // the real one is a search pill sitting at the edge the bar is on, with
        // the results list floating free above it -- not a panel with a field
        // inside, which is what this used to draw

        Item {
            visible: preview.kind === "launcher"
            anchors.left: bar.right
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.leftMargin: Theme.dp(10)
            anchors.rightMargin: Theme.dp(10)
            anchors.bottomMargin: Theme.dp(8)

            Column {
                id: results

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: searchPill.top
                anchors.bottomMargin: Theme.dp(8)
                spacing: Theme.dp(4)

                Repeater {
                    model: 4

                    Rectangle {
                        required property int index

                        width: Theme.dp(168)
                        height: Theme.dp(22)
                        radius: Theme.dp(8)
                        // only the selected row carries a background, as in the shell
                        color: index === 0 ? Theme.alpha(Theme.accent, 0.3) : "transparent"

                        Rectangle {
                            id: appIcon

                            anchors.left: parent.left
                            anchors.leftMargin: Theme.dp(7)
                            anchors.verticalCenter: parent.verticalCenter
                            width: Theme.dp(14)
                            height: Theme.dp(14)
                            radius: Theme.dp(4)
                            color: index === 0 ? Theme.accent : Theme.alpha(Theme.text, 0.3)
                        }

                        Column {
                            anchors.left: appIcon.right
                            anchors.leftMargin: Theme.dp(7)
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.dp(3)

                            // the app's name, and its comment under it
                            Rectangle {
                                width: Theme.dp(index === 0 ? 72 : 58)
                                height: Theme.dp(4)
                                radius: height / 2
                                color: Theme.alpha(Theme.text, index === 0 ? 0.8 : 0.45)
                            }

                            Rectangle {
                                width: Theme.dp(index === 0 ? 96 : 80)
                                height: Theme.dp(3)
                                radius: height / 2
                                color: Theme.alpha(Theme.text, 0.2)
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: searchPill

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                width: Theme.dp(176)
                height: Theme.dp(22)
                radius: height / 2
                color: Theme.bgSunken
                border.width: Theme.dp(1)
                border.color: Theme.alpha(Theme.accent, 0.45)

                Rectangle {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.dp(9)
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.dp(8)
                    height: Theme.dp(8)
                    radius: width / 2
                    color: Theme.accent
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.dp(23)
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.dp(44)
                    height: Theme.dp(4)
                    radius: height / 2
                    color: Theme.alpha(Theme.text, 0.55)
                }
            }
        }

        // -- the dashboard --------------------------------------------------
        //
        // hangs from an edge (Config.dashboard.edge), a tab strip over four
        // zones: one tall down each side, two stacked between them

        Rectangle {
            visible: preview.kind === "dashboard"
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.horizontalCenterOffset: Theme.dp(8)
            anchors.top: parent.top
            width: Theme.dp(224)
            height: Theme.dp(124)
            bottomLeftRadius: Theme.dp(14)
            bottomRightRadius: Theme.dp(14)
            color: Theme.bgSunken
            border.width: Theme.dp(1)
            border.color: Theme.alpha(Theme.accent, 0.45)

            // Dashboard, Media, Performance, Weather
            Row {
                id: dashTabs

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: Theme.dp(8)
                spacing: Theme.dp(6)

                Repeater {
                    model: 4

                    Rectangle {
                        required property int index

                        width: Theme.dp(34)
                        height: Theme.dp(14)
                        radius: height / 2
                        color: index === 0 ? Theme.accent : Theme.alpha(Theme.text, 0.1)

                        Rectangle {
                            anchors.centerIn: parent
                            width: Theme.dp(18)
                            height: Theme.dp(4)
                            radius: height / 2
                            color: index === 0 ? Theme.alpha(Theme.onAccent, 0.8) : Theme.alpha(Theme.text, 0.35)
                        }
                    }
                }
            }

            Row {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: dashTabs.bottom
                anchors.bottom: parent.bottom
                anchors.margins: Theme.dp(8)
                spacing: Theme.dp(6)

                // the user, down the left
                Rectangle {
                    width: Theme.dp(50)
                    height: parent.height
                    radius: Theme.dp(10)
                    color: Theme.alpha(Theme.text, 0.1)

                    Column {
                        anchors.centerIn: parent
                        spacing: Theme.dp(5)

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: Theme.dp(22)
                            height: Theme.dp(22)
                            radius: width / 2
                            color: Theme.alpha(Theme.accent, 0.8)
                        }

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: Theme.dp(30)
                            height: Theme.dp(4)
                            radius: height / 2
                            color: Theme.alpha(Theme.text, 0.4)
                        }
                    }
                }

                // the time over the resources, between them
                Column {
                    width: Theme.dp(82)
                    height: parent.height
                    spacing: Theme.dp(6)

                    Rectangle {
                        width: parent.width
                        height: (parent.height - Theme.dp(6)) * 0.46
                        radius: Theme.dp(10)
                        color: Theme.alpha(Theme.text, 0.1)

                        Text {
                            anchors.centerIn: parent
                            text: "9:41"
                            color: Theme.alpha(Theme.text, 0.75)
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.dp(18)
                            font.variableAxes: Theme.axes(Theme.dp(18), 400, 0)
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: (parent.height - Theme.dp(6)) * 0.54
                        radius: Theme.dp(10)
                        color: Theme.alpha(Theme.text, 0.1)

                        Row {
                            anchors.centerIn: parent
                            spacing: Theme.dp(8)

                            Repeater {
                                model: 3

                                Rectangle {
                                    required property int index

                                    width: Theme.dp(16)
                                    height: Theme.dp(16)
                                    radius: width / 2
                                    color: "transparent"
                                    border.width: Theme.dp(3)
                                    border.color: index === 0 ? Theme.accent : Theme.alpha(Theme.text, 0.3)
                                }
                            }
                        }
                    }
                }

                // the calendar, down the right
                Rectangle {
                    width: Theme.dp(60)
                    height: parent.height
                    radius: Theme.dp(10)
                    color: Theme.alpha(Theme.text, 0.1)

                    Grid {
                        anchors.centerIn: parent
                        columns: 5
                        spacing: Theme.dp(4)

                        Repeater {
                            model: 15

                            Rectangle {
                                required property int index

                                width: Theme.dp(6)
                                height: Theme.dp(6)
                                radius: Theme.dp(2)
                                color: index === 7 ? Theme.accent : Theme.alpha(Theme.text, 0.25)
                            }
                        }
                    }
                }
            }
        }

        // -- the lock screen ---------------------------------------------

        Column {
            visible: preview.kind === "lock"
            anchors.centerIn: parent
            spacing: Theme.dp(8)

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "9:41"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.dp(40)
                font.variableAxes: Theme.axes(Theme.dp(40), 300, 0)
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Theme.dp(28)
                height: Theme.dp(28)
                radius: width / 2
                color: Theme.alpha(Theme.accent, 0.8)
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Theme.dp(110)
                height: Theme.dp(16)
                radius: height / 2
                color: Theme.alpha(Theme.text, 0.12)

                Row {
                    anchors.centerIn: parent
                    spacing: Theme.dp(5)

                    Repeater {
                        model: 5

                        Rectangle {
                            width: Theme.dp(5)
                            height: Theme.dp(5)
                            radius: width / 2
                            color: Theme.alpha(Theme.text, 0.5)
                        }
                    }
                }
            }
        }
    }
}
