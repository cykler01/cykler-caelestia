pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Caelestia.Config
import qs.components
import qs.services
import qs.utils
import qs.modules.bar.components.status

// Horizontal status icon strip used by top/bottom bars
StyledRect {
    id: root

    property color colour: Colours.palette.m3secondary
    readonly property alias items: iconRow

    color: Colours.tPalette.m3surfaceContainer
    radius: Tokens.rounding.full

    clip: true
    implicitWidth: iconRow.implicitWidth + Tokens.padding.medium * 2
    implicitHeight: Tokens.sizes.bar.innerWidth

    RowLayout {
        id: iconRow

        anchors.centerIn: parent
        spacing: Tokens.spacing.medium

        Repeater {
            model: ScriptModel {
                values: root.Config.bar.statusIcons.values.filter(e => e.enabled)
            }

            DelegateChooser {
                role: "id"

                DelegateChoice {
                    roleValue: "lockStatus"
                    delegate: EntryWrapper {
                        visible: Hypr.capsLock || Hypr.numLock

                        Row {
                            spacing: Tokens.spacing.extraSmall

                            MaterialIcon {
                                visible: Hypr.capsLock
                                text: "keyboard_capslock_badge"
                                color: root.colour
                                fill: 1
                                grade: 25
                            }

                            MaterialIcon {
                                visible: Hypr.numLock
                                text: "looks_one"
                                color: root.colour
                                fill: 1
                                grade: 25
                            }
                        }
                    }
                }
                DelegateChoice {
                    roleValue: "audio"
                    delegate: EntryWrapper {
                        MaterialIcon {
                            animate: true
                            text: Icons.getVolumeIcon(Audio.volume, Audio.muted)
                            color: root.colour
                            fontStyle: Tokens.font.icon.medium
                            fill: 1
                        }
                    }
                }
                DelegateChoice {
                    roleValue: "microphone"
                    delegate: EntryWrapper {
                        name: "audio" // Mic opens audio popout

                        MaterialIcon {
                            animate: true
                            text: Icons.getMicVolumeIcon(Audio.sourceVolume, Audio.sourceMuted)
                            color: root.colour
                            fontStyle: Tokens.font.icon.medium
                            fill: 1
                        }
                    }
                }
                DelegateChoice {
                    roleValue: "kbLayout"
                    delegate: EntryWrapper {
                        StyledText {
                            animate: true
                            text: Hypr.kbLayout
                            color: root.colour
                            font: Tokens.font.mono.medium
                        }
                    }
                }
                DelegateChoice {
                    roleValue: "network"
                    delegate: EntryWrapper {
                        MaterialIcon {
                            animate: true
                            text: Nmcli.activeEthernet ? "cable" : Nmcli.active ? Icons.getNetworkIcon(Nmcli.active.strength ?? 0) : "wifi_off"
                            color: root.colour
                        }
                    }
                }
                DelegateChoice {
                    roleValue: "bluetooth"
                    delegate: EntryWrapper {
                        Row {
                            spacing: Tokens.spacing.extraSmall

                            MaterialIcon {
                                animate: true
                                text: {
                                    if (!Bluetooth.defaultAdapter?.enabled) // qmllint disable unresolved-type
                                        return "bluetooth_disabled";
                                    if (Bluetooth.devices.values.some(d => d.connected)) // qmllint disable unresolved-type
                                        return "bluetooth_connected";
                                    return "bluetooth";
                                }
                                color: root.colour
                            }

                            Repeater {
                                model: ScriptModel {
                                    values: Bluetooth.devices.values.filter(d => d.state !== BluetoothDeviceState.Disconnected) // qmllint disable unresolved-type
                                }

                                MaterialIcon {
                                    required property BluetoothDevice modelData

                                    animate: true
                                    text: Icons.getBluetoothIcon(modelData?.icon)
                                    color: root.colour
                                    fill: 1
                                }
                            }
                        }
                    }
                }
                DelegateChoice {
                    roleValue: "battery"
                    delegate: EntryWrapper {
                        BatteryStatus {
                            colour: root.colour
                        }
                    }
                }
            }
        }
    }

    component EntryWrapper: Item {
        required property var modelData
        default property Item item
        property string name: modelData.id.toLowerCase()

        Layout.alignment: Qt.AlignVCenter
        implicitWidth: item?.implicitWidth ?? 0
        implicitHeight: item?.implicitHeight ?? 0

        children: item
    }
}
