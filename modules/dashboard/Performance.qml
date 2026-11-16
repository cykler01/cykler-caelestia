import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import Caelestia.Config
import Caelestia.I18n
import Caelestia.Services
import qs.components
import qs.components.controls
import qs.services
import qs.modules.dashboard.performance

Item {
    id: root

    required property ShellScreen screen

    property bool processesExpanded

    readonly property real processListHeight: Math.max(96, Math.min(240, screen.height - content.implicitHeight - 260))
    // Space the card keeps clear at its top for the control above it
    readonly property real cardInset: processesButton.implicitHeight + Tokens.spacing.small

    implicitWidth: placeholder.active ? Tokens.sizes.dashboard.perfPlaceholderWidth : Math.max(content.implicitWidth, processesExpanded ? processList.implicitWidth : 0)
    implicitHeight: (placeholder.active ? placeholder.implicitHeight + Tokens.padding.extraLarge * 2 : content.implicitHeight) + (processesExpanded ? Tokens.spacing.small + processList.implicitHeight : 0)

    // The battery card, always the last card on the right in either layout, has an empty top right corner, so
    // the button sits there whenever it is shown rather than over the first card's contents
    readonly property bool buttonOnRight: UPower.displayDevice.isLaptopBattery && Config.dashboard.performance.showBattery

    // A small control inside the card's top corner, like the media tab's equalizer button, so
    // opening the list neither takes a row out of the tab nor moves the graphs down
    IconButton {
        id: processesButton

        x: root.buttonOnRight ? content.x + content.width - width - Tokens.padding.medium : content.x + Tokens.padding.medium
        y: content.y + Tokens.padding.medium
        z: 10
        icon: "list_alt"
        type: root.processesExpanded ? IconButton.Filled : IconButton.Tonal
        isToggle: true
        checked: root.processesExpanded
        // The battery card is drawn in the secondary colours, the same ones a tonal button uses, so on it the
        // idle button takes the primary ones instead. Opened, it is filled with primary either way
        inactiveColour: root.buttonOnRight ? Colours.palette.m3primaryContainer : Colours.palette.m3secondaryContainer
        inactiveOnColour: root.buttonOnRight ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSecondaryContainer
        onClicked: root.processesExpanded = !root.processesExpanded
    }

    Loader {
        id: placeholder

        anchors.centerIn: parent
        active: !Config.dashboard.performance.showCpu && !(Config.dashboard.performance.showGpu && Gpu.type !== GpuType.None) && !Config.dashboard.performance.showMemory && !Config.dashboard.performance.showStorage && !Config.dashboard.performance.showNetwork && !(UPower.displayDevice.isLaptopBattery && Config.dashboard.performance.showBattery)
        asynchronous: true

        sourceComponent: ColumnLayout {
            spacing: Tokens.spacing.medium

            MaterialIcon {
                Layout.alignment: Qt.AlignHCenter
                text: "tune"
                fontStyle: Tokens.font.icon.builders.extraLarge.scale(2).build()
                color: Colours.palette.m3onSurfaceVariant
            }

            StyledText {
                Layout.topMargin: -Tokens.spacing.small
                Layout.alignment: Qt.AlignHCenter
                text: Tr.tr("No widgets enabled")
                font: Tokens.font.title.large
                color: Colours.palette.m3onSurface
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Tr.tr("Enable widgets in the dashboard settings")
                font: Tokens.font.body.small
                color: Colours.palette.m3onSurfaceVariant
            }
        }
    }

    Loader {
        id: content

        anchors.left: parent.left
        anchors.right: parent.right
        visible: !placeholder.active
        // ResourceHistory is off when the graph view is disabled or paused by Power Saver
        sourceComponent: ResourceHistory.enabled ? graphLayout : classicLayout
    }

    ProcessList {
        id: processList

        // Under the card, or under the placeholder while that is what is showing
        anchors.top: placeholder.active ? placeholder.bottom : content.bottom
        anchors.topMargin: Tokens.spacing.small
        width: root.implicitWidth
        height: root.processesExpanded ? implicitHeight : 0
        visible: root.processesExpanded
        maxListHeight: root.processListHeight
    }

    // CPU, GPU, memory, network and storage combined into one graph card
    Component {
        id: graphLayout

        RowLayout {
            spacing: Tokens.spacing.medium

            WrappedLoader {
                id: graphCard

                active: Config.dashboard.performance.showCpu || (Config.dashboard.performance.showGpu && Gpu.type !== GpuType.None) || Config.dashboard.performance.showMemory || Config.dashboard.performance.showNetwork || Config.dashboard.performance.showStorage
                sourceComponent: ResourceGraph {
                    // Only needs the strip at its top when the button sits in its corner rather than the battery card's
                    topInset: root.buttonOnRight ? 0 : root.cardInset
                }
            }

            WrappedLoader {
                Layout.fillWidth: !graphCard.active
                active: UPower.displayDevice.isLaptopBattery && Config.dashboard.performance.showBattery
                sourceComponent: BatteryTank {}
            }
        }
    }

    // The original Caelestia layout
    Component {
        id: classicLayout

        RowLayout {
            spacing: Tokens.spacing.medium

            ColumnLayout {
                id: mainColumn

                Layout.fillWidth: true
                spacing: Tokens.spacing.medium

                RowLayout {
                    spacing: Tokens.spacing.medium
                    visible: cpuCard.active || gpuCard.active

                    WrappedLoader {
                        id: cpuCard

                        active: Config.dashboard.performance.showCpu

                        sourceComponent: HeroCard {
                            icon: "memory"
                            label: Tr.tr("CPU")
                            subLabel: Cpu.name
                            usage: Cpu.percentage
                            temperature: Cpu.temperature
                            accent: Colours.palette.m3primary

                            ServiceRef {
                                service: Cpu
                            }
                        }
                    }

                    WrappedLoader {
                        id: gpuCard

                        active: Config.dashboard.performance.showGpu && Gpu.type !== GpuType.None

                        sourceComponent: HeroCard {
                            icon: "desktop_windows"
                            label: Tr.tr("GPU")
                            subLabel: Gpu.name || (Gpu.detecting ? Tr.tr("Detecting GPU...") : Tr.trCtx("None", "GPU name"))
                            usage: Gpu.percentage
                            temperature: Gpu.temperature
                            accent: Colours.palette.m3secondary

                            ServiceRef {
                                service: Gpu
                            }
                        }
                    }
                }

                RowLayout {
                    spacing: Tokens.spacing.medium
                    visible: storageCard.active || networkCard.active || memoryCard.active

                    WrappedLoader {
                        id: storageCard

                        active: Config.dashboard.performance.showStorage
                        sourceComponent: StorageCard {}
                    }

                    WrappedLoader {
                        id: networkCard

                        active: Config.dashboard.performance.showNetwork
                        sourceComponent: NetworkCard {}
                    }

                    WrappedLoader {
                        id: memoryCard

                        active: Config.dashboard.performance.showMemory
                        sourceComponent: MemoryCard {}
                    }
                }
            }

            WrappedLoader {
                Layout.fillWidth: false
                active: UPower.displayDevice.isLaptopBattery && Config.dashboard.performance.showBattery
                sourceComponent: BatteryTank {}
            }
        }
    }

    component WrappedLoader: Loader {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: active
    }
}
