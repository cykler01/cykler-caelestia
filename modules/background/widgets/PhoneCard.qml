pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.background

// --- Phone: the phone paired over KDE Connect, its charge and whether it is in reach, with buttons to ring it
// and to send it the clipboard. The compact style is just the name and the charge ---
WidgetCard {
    id: phone

    readonly property bool compact: phone.variant === "compact"

    // KdeConnect lists paired devices only while they are in reach. With more than one, the one reporting a
    // charge is the more useful to show
    readonly property var device: KdeConnect.devices.find(d => (d.batteryCharge ?? -1) >= 0) ?? KdeConnect.devices[0] ?? null
    readonly property int charge: phone.device?.batteryCharge ?? -1
    readonly property bool charging: phone.device?.batteryCharging ?? false
    readonly property bool low: phone.charge >= 0 && phone.charge < 20 && !phone.charging
    readonly property color accent: phone.low ? Colours.palette.m3error : phone.charging ? Colours.palette.m3tertiary : Colours.palette.m3primary

    // A phone that is paired but out of reach is not in KdeConnect's list at all, so its name is asked of
    // kdeconnect-cli instead - the card can then say where the phone is rather than claim there is none
    property string awayName

    // What the last button press came to, shown on the button for a moment: "", "done" or "failed"
    property string ringResult
    property string clipResult

    function send(action: string): void {
        if (!phone.device || sender.running)
            return;
        sender.action = action;
        sender.command = ["kdeconnect-cli", "-d", phone.device.id, action === "ring" ? "--ring" : "--send-clipboard"];
        sender.running = true;
    }

    function refreshAway(): void {
        if (KdeConnect.available && KdeConnect.devices.length === 0 && !away.running)
            away.running = true;
        else if (KdeConnect.devices.length > 0)
            phone.awayName = "";
    }

    // No header: the phone's own name heads the card, and four cells have no height to spare for both
    title: ""
    icon: "smartphone"
    padding: phone.compact ? Tokens.padding.large : Tokens.padding.largeIncreased

    Component.onCompleted: refreshAway()

    Connections {
        function onDevicesChanged(): void {
            phone.refreshAway();
        }

        function onAvailableChanged(): void {
            phone.refreshAway();
        }

        target: KdeConnect
    }

    Process {
        id: away

        command: ["kdeconnect-cli", "--list-devices"]

        // "- Name: id (paired)" for each known device; the first paired one is the phone
        stdout: StdioCollector {
            onStreamFinished: {
                const match = text.split("\n").map(l => l.match(/^- (.+): \S+ \(paired/)).find(m => m);
                phone.awayName = match ? match[1] : "";
            }
        }
    }

    Process {
        id: sender

        property string action

        onExited: code => { // qmllint disable signal-handler-parameters
            if (sender.action === "ring")
                phone.ringResult = code === 0 ? "done" : "failed";
            else
                phone.clipResult = code === 0 ? "done" : "failed";
            resultReset.restart();
        }
    }

    // A confirmation is read once and then gets out of the way
    Timer {
        id: resultReset

        interval: 2500
        onTriggered: {
            phone.ringResult = "";
            phone.clipResult = "";
        }
    }

    // Card: the phone with its charge around it, then the two actions
    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: !phone.compact && phone.device !== null
        spacing: Tokens.spacing.medium

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.medium

            // The charge as a ring around the phone, which says "this phone's battery" without a label
            CircularProgress {
                implicitSize: 52
                strokeWidth: 5
                value: phone.charge >= 0 ? phone.charge / 100 : 0
                fgColour: phone.accent
                bgColour: Colours.palette.m3surfaceContainerHighest

                Behavior on clampedVal {
                    Anim {
                        type: Anim.FastEffects
                    }
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    text: phone.charging ? "mobile_charge" : "smartphone"
                    color: phone.accent
                    fontStyle: Tokens.font.icon.medium
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: phone.device?.name ?? ""
                    color: Colours.palette.m3onSurface
                    font: Tokens.font.title.builders.small.weight(Font.DemiBold).build()
                }

                StyledText {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: phone.charging ? Tr.tr("Connected · charging") : Tr.tr("Connected")
                    color: Colours.palette.m3outline
                    font: Tokens.font.label.small
                }
            }

            StyledText {
                visible: phone.charge >= 0
                text: `${phone.charge}%`
                color: phone.low ? Colours.palette.m3error : Colours.palette.m3onSurface
                font: Tokens.font.title.builders.medium.weight(Font.DemiBold).build()
            }
        }

        // The actions keep to the bottom edge, whatever height the card ends up
        Item {
            Layout.fillHeight: true
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small
            uniformCellSizes: true

            IconTextButton {
                Layout.fillWidth: true
                type: IconTextButton.Tonal
                isRound: true
                verticalPadding: Tokens.padding.extraSmall
                icon: phone.ringResult === "failed" ? "error" : "ring_volume"
                text: phone.ringResult === "done" ? Tr.tr("Ringing") : phone.ringResult === "failed" ? Tr.tr("Failed") : Tr.tr("Ring")
                onClicked: phone.send("ring")
            }

            IconTextButton {
                Layout.fillWidth: true
                type: IconTextButton.Tonal
                isRound: true
                verticalPadding: Tokens.padding.extraSmall
                icon: phone.clipResult === "done" ? "check" : phone.clipResult === "failed" ? "error" : "content_paste_go"
                text: phone.clipResult === "done" ? Tr.tr("Sent") : phone.clipResult === "failed" ? Tr.tr("Failed") : Tr.tr("Clipboard")
                onClicked: phone.send("clipboard")
            }
        }
    }

    // Nothing to show: the daemon is off, the phone is away, or there is no phone at all
    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: !phone.compact && phone.device === null
        spacing: Tokens.spacing.medium

        StyledRect {
            implicitWidth: implicitHeight
            implicitHeight: emptyIcon.implicitHeight + Tokens.padding.medium * 2
            radius: Tokens.rounding.full
            color: Colours.palette.m3surfaceContainerHighest

            MaterialIcon {
                id: emptyIcon

                anchors.centerIn: parent
                text: phone.awayName !== "" ? "mobile_off" : "add_to_home_screen"
                color: Colours.palette.m3outline
                fontStyle: Tokens.font.icon.medium
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: {
                    if (!KdeConnect.available)
                        return Tr.tr("KDE Connect is off");
                    return phone.awayName !== "" ? phone.awayName : Tr.tr("No phone paired");
                }
                color: Colours.palette.m3onSurface
                font: Tokens.font.label.large
            }

            StyledText {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                text: {
                    if (!KdeConnect.available)
                        return Tr.tr("Turn on Send to phone in the utilities panel");
                    return phone.awayName !== "" ? Tr.tr("Out of reach") : Tr.tr("Pair one with the KDE Connect app");
                }
                color: Colours.palette.m3outline
                font: Tokens.font.label.small
            }
        }
    }

    // Compact: the phone, its name and its charge on one line
    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: phone.compact
        spacing: Tokens.spacing.medium

        StyledRect {
            implicitWidth: implicitHeight
            implicitHeight: compactIcon.implicitHeight + Tokens.padding.small * 2
            radius: Tokens.rounding.full
            color: phone.device ? Qt.alpha(phone.accent, 0.16) : Colours.palette.m3surfaceContainerHighest

            MaterialIcon {
                id: compactIcon

                anchors.centerIn: parent
                text: !phone.device ? "mobile_off" : phone.charging ? "mobile_charge" : "smartphone"
                color: phone.device ? phone.accent : Colours.palette.m3outline
                fontStyle: Tokens.font.icon.medium
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: phone.device?.name ?? (phone.awayName || Tr.tr("No phone"))
                color: phone.device ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.builders.medium.weight(Font.DemiBold).build()
            }

            StyledText {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: phone.device ? (phone.charging ? Tr.tr("Charging") : Tr.tr("Connected")) : !KdeConnect.available ? Tr.tr("KDE Connect is off") : phone.awayName !== "" ? Tr.tr("Out of reach") : Tr.tr("Not paired")
                color: Colours.palette.m3outline
                font: Tokens.font.label.small
            }
        }

        StyledText {
            visible: phone.charge >= 0
            text: `${phone.charge}%`
            color: phone.low ? Colours.palette.m3error : Colours.palette.m3onSurface
            font: Tokens.font.title.builders.small.weight(Font.DemiBold).build()
        }
    }
}
