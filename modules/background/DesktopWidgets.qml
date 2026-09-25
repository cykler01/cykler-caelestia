pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import Caelestia.Config
import Caelestia.I18n
import Caelestia.Services
import qs.components
import qs.components.controls
import qs.components.containers
import qs.services

// Stack of glass widget cards; wraps into extra columns when the screen is short
Flow {
    id: root

    required property Item wallpaper

    readonly property int cardWidth: 320
    readonly property var widgetConfig: Config.background.desktopWidgets

    flow: Flow.TopToBottom
    spacing: Tokens.spacing.medium

    // --- Calendar: month grid ---
    Loader {
        active: root.widgetConfig.calendar
        visible: active

        sourceComponent: DesktopCard {
            id: cal

            readonly property date now: Time.date
            readonly property var cells: {
                const first = new Date(now.getFullYear(), now.getMonth(), 1);
                const offset = (first.getDay() + 6) % 7; // Monday first
                return Array.from({
                    length: 42
                }, (_, i) => {
                    const d = new Date(first.getFullYear(), first.getMonth(), 1 - offset + i);
                    return {
                        day: d.getDate(),
                        inMonth: d.getMonth() === first.getMonth(),
                        today: d.toDateString() === now.toDateString()
                    };
                });
            }

            wallpaper: root.wallpaper
            implicitWidth: root.cardWidth
            title: Time.format("MMMM yyyy")
            icon: "calendar_month"

            GridLayout {
                Layout.fillWidth: true
                columns: 7
                rowSpacing: 2
                columnSpacing: 0

                Repeater {
                    model: [1, 2, 3, 4, 5, 6, 0]

                    StyledText {
                        required property int modelData

                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: Qt.locale().dayName(modelData, Locale.NarrowFormat)
                        color: Colours.palette.m3primary
                        font: Tokens.font.label.small
                    }
                }

                Repeater {
                    model: cal.cells

                    Item {
                        id: cell

                        required property var modelData

                        Layout.fillWidth: true
                        implicitHeight: 30

                        StyledRect {
                            anchors.centerIn: parent
                            implicitWidth: 28
                            implicitHeight: 28
                            radius: Tokens.rounding.full
                            color: cell.modelData.today ? Colours.palette.m3primary : "transparent"
                        }

                        StyledText {
                            anchors.centerIn: parent
                            text: cell.modelData.day
                            font: Tokens.font.label.medium
                            color: cell.modelData.today ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                            opacity: cell.modelData.inMonth ? 1 : 0.3
                        }
                    }
                }
            }
        }
    }

    // --- Weather ---
    Loader {
        active: root.widgetConfig.weather
        visible: active

        sourceComponent: DesktopCard {
            wallpaper: root.wallpaper
            implicitWidth: root.cardWidth
            title: Weather.city || Tr.tr("Weather")
            icon: "location_on"
            Component.onCompleted: Weather.reload()

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.medium

                MaterialIcon {
                    text: Weather.icon
                    color: Colours.palette.m3secondary
                    fontStyle: Tokens.font.icon.builders.extraLarge.scale(1.4).build()
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    spacing: 0

                    StyledText {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: Weather.temp
                        color: Colours.palette.m3onSurface
                        font: Tokens.font.headline.builders.medium.weight(Font.DemiBold).build()
                    }

                    StyledText {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: Weather.description
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.label.medium
                    }
                }

                ColumnLayout {
                    spacing: Tokens.spacing.extraSmall

                    Stat {
                        icon: "humidity_percentage"
                        text: `${Weather.humidity}%`
                    }

                    Stat {
                        icon: "air"
                        text: `${Math.round(Weather.windSpeed)} km/h`
                    }
                }
            }

            StyledRect {
                Layout.fillWidth: true
                implicitHeight: forecastRow.implicitHeight + Tokens.padding.small * 2
                radius: Tokens.rounding.large
                color: Colours.palette.m3surfaceContainerHigh
                opacity: 0.85

                RowLayout {
                    id: forecastRow

                    anchors.fill: parent
                    anchors.margins: Tokens.padding.small
                    spacing: 0

                    Repeater {
                        model: Weather.forecast.slice(0, 5)

                        ColumnLayout {
                            id: fc

                            required property var modelData
                            required property int index

                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            Layout.minimumWidth: 0
                            spacing: 2

                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: fc.index === 0 ? Tr.tr("Today") : Qt.locale().dayName(new Date(fc.modelData.date).getDay(), Locale.ShortFormat)
                                color: Colours.palette.m3onSurfaceVariant
                                font: Tokens.font.label.small
                            }

                            MaterialIcon {
                                Layout.alignment: Qt.AlignHCenter
                                text: fc.modelData.icon
                                color: Colours.palette.m3secondary
                            }

                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: Weather.formatTemp(fc.modelData.maxTempC, true)
                                color: Colours.palette.m3onSurface
                                font: Tokens.font.label.small
                            }

                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: Weather.formatTemp(fc.modelData.minTempC, true)
                                color: Colours.palette.m3outline
                                font: Tokens.font.label.small
                            }
                        }
                    }
                }
            }
        }
    }

    // --- Focus timer ---
    Loader {
        active: root.widgetConfig.pomodoro
        visible: active

        sourceComponent: DesktopCard {
            wallpaper: root.wallpaper
            implicitWidth: root.cardWidth
            title: Tr.tr("Focus")
            icon: "timer"

            Pomodoro {
                Layout.fillWidth: true
            }
        }
    }

    // --- System resources ---
    Loader {
        active: root.widgetConfig.resources
        visible: active

        sourceComponent: DesktopCard {
            wallpaper: root.wallpaper
            implicitWidth: root.cardWidth
            title: Tr.tr("System")
            icon: "monitoring"

            ServiceRef {
                service: Cpu
            }

            ServiceRef {
                service: Memory
            }

            ServiceRef {
                service: Storage
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                Meter {
                    label: "CPU"
                    icon: "memory"
                    value: Cpu.percentage
                    colour: Colours.palette.m3primary
                }

                Meter {
                    label: "RAM"
                    icon: "memory_alt"
                    value: Memory.percentage
                    colour: Colours.palette.m3tertiary
                }

                Meter {
                    label: Tr.tr("Disk")
                    icon: "hard_disk"
                    value: Storage.percentage
                    colour: Colours.palette.m3secondary
                }
            }
        }
    }

    // --- Now playing ---
    Loader {
        active: root.widgetConfig.media
        visible: active && Players.active !== null

        sourceComponent: DesktopCard {
            id: media

            readonly property var player: Players.active

            wallpaper: root.wallpaper
            implicitWidth: root.cardWidth
            title: Tr.tr("Now playing")
            icon: "music_note"

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.medium

                StyledClippingRect {
                    implicitWidth: 76
                    implicitHeight: 76
                    radius: Tokens.rounding.large
                    color: Colours.palette.m3surfaceContainerHigh

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: "album"
                        color: Colours.palette.m3outline
                        fontStyle: Tokens.font.icon.large
                    }

                    Image {
                        anchors.fill: parent
                        asynchronous: true
                        fillMode: Image.PreserveAspectCrop
                        source: Players.getArtUrl(media.player)
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    StyledText {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: media.player?.trackTitle || Tr.tr("Unknown title")
                        color: Colours.palette.m3onSurface
                        font: Tokens.font.body.builders.medium.weight(Font.DemiBold).build()
                    }

                    StyledText {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: media.player?.trackArtist || Tr.tr("Unknown artist")
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.label.medium
                    }

                    RowLayout {
                        spacing: Tokens.spacing.extraSmall

                        IconButton {
                            icon: "skip_previous"
                            type: IconButton.Text
                            disabled: !media.player?.canGoPrevious
                            onClicked: media.player?.previous()
                        }

                        IconButton {
                            icon: media.player?.isPlaying ? "pause" : "play_arrow"
                            type: IconButton.Filled
                            onClicked: media.player?.togglePlaying()
                        }

                        IconButton {
                            icon: "skip_next"
                            type: IconButton.Text
                            disabled: !media.player?.canGoNext
                            onClicked: media.player?.next()
                        }
                    }
                }
            }
        }
    }

    // --- Battery (laptops only) ---
    Loader {
        active: root.widgetConfig.battery
        visible: active && UPower.displayDevice.isLaptopBattery

        sourceComponent: DesktopCard {
            readonly property real pct: UPower.displayDevice.percentage
            readonly property bool charging: UPower.displayDevice.state === UPowerDeviceState.Charging || UPower.displayDevice.state === UPowerDeviceState.FullyCharged

            wallpaper: root.wallpaper
            implicitWidth: root.cardWidth
            title: Tr.tr("Battery")
            icon: charging ? "battery_charging_full" : "battery_full"

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.medium

                StyledText {
                    text: `${Math.round(pct * 100)}%`
                    color: pct < 0.2 && !charging ? Colours.palette.m3error : Colours.palette.m3onSurface
                    font: Tokens.font.headline.builders.medium.weight(Font.DemiBold).build()
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.extraSmall

                    StyledText {
                        text: charging ? Tr.tr("Charging") : Tr.tr("On battery")
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.label.medium
                    }

                    StyledRect {
                        Layout.fillWidth: true
                        implicitHeight: 8
                        radius: Tokens.rounding.full
                        color: Colours.palette.m3surfaceContainerHighest

                        StyledRect {
                            width: parent.width * Math.max(0, Math.min(1, pct))
                            height: parent.height
                            radius: Tokens.rounding.full
                            color: pct < 0.2 && !charging ? Colours.palette.m3error : charging ? Colours.palette.m3tertiary : Colours.palette.m3primary
                        }
                    }
                }
            }
        }
    }

    component Stat: RowLayout {
        property string icon
        property string text

        spacing: Tokens.spacing.extraSmall

        MaterialIcon {
            text: parent.icon
            color: Colours.palette.m3outline
            fontStyle: Tokens.font.icon.small
        }

        StyledText {
            text: parent.text
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.label.small
        }
    }

    component Meter: ColumnLayout {
        id: meter

        property string label
        property string icon
        property real value
        property color colour

        Layout.fillWidth: true
        spacing: Tokens.spacing.extraSmall

        CircularProgress {
            Layout.alignment: Qt.AlignHCenter
            implicitSize: 64
            strokeWidth: 6
            value: meter.value
            fgColour: meter.colour
            bgColour: Colours.palette.m3surfaceContainerHighest

            Behavior on clampedVal {
                Anim {}
            }

            MaterialIcon {
                anchors.centerIn: parent
                text: meter.icon
                color: meter.colour
                fontStyle: Tokens.font.icon.medium
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: `${meter.label} ${Math.round(meter.value * 100)}%`
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.label.small
        }
    }
}
