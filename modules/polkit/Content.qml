pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.components.effects
import qs.services

// The prompt for a polkit authentication request (see Polkit.qml): a dimmed screen with a card
// asking for the password, built from the same containers and colours as the rest of the shell
Item {
    id: root

    // The flow of the request being answered, null once it is over
    property var flow: null

    readonly property bool awaitingInput: root.flow?.isResponseRequired ?? false
    // The password has been handed over and polkit is checking it
    readonly property bool verifying: root.flow !== null && !root.flow.isResponseRequired && !root.flow.isCompleted
    readonly property var identities: root.flow?.identities ?? []
    // Only worth a picker when the request allows more than one identity
    readonly property bool pickIdentity: root.identities.length > 1
    // Where polkit says why the last attempt failed, or what it is doing now
    readonly property string notice: {
        if (!root.flow)
            return "";

        if (root.flow.supplementaryMessage !== "")
            return root.flow.supplementaryMessage;

        return root.flow.failed ? Tr.tr("Authentication failed") : "";
    }

    function submit(): void {
        if (!root.flow || root.flow.isCompleted)
            return;

        root.flow.submit(password.text);
        password.text = "";
    }

    function cancel(): void {
        root.flow?.cancelAuthenticationRequest();
    }

    onFlowChanged: {
        password.text = "";
        if (root.flow)
            focusTimer.restart();
    }

    focus: true

    Keys.onEscapePressed: root.cancel()

    Connections {
        function onIsResponseRequiredChanged(): void {
            if (root.awaitingInput)
                focusTimer.restart();
        }

        target: root.flow
    }

    // The field can only take focus once the window it sits in has been mapped, which happens
    // after the request arrives, so the grab waits a frame for it
    Timer {
        id: focusTimer

        interval: 100
        onTriggered: password.forceActiveFocus()
    }

    StyledRect {
        anchors.fill: parent

        color: Qt.alpha(Colours.palette.m3scrim, 0.45)

        // Swallows clicks meant for whatever is underneath
        MouseArea {
            anchors.fill: parent
        }
    }

    StyledRect {
        id: card

        anchors.centerIn: parent
        width: Math.min(420, parent.width - Tokens.padding.extraLargeIncreased)
        implicitHeight: layout.implicitHeight + Tokens.padding.extraExtraLarge

        radius: Tokens.rounding.extraLarge
        color: Colours.palette.m3surfaceContainerHigh

        Elevation {
            anchors.fill: parent
            radius: parent.radius
            z: -1
            level: 3
        }

        ColumnLayout {
            id: layout

            anchors.fill: parent
            anchors.margins: Tokens.padding.large * 1.5
            spacing: Tokens.spacing.medium

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.medium

                StyledRect {
                    implicitWidth: implicitHeight
                    implicitHeight: shield.implicitHeight + Tokens.padding.medium * 2
                    radius: Tokens.rounding.full
                    color: Colours.palette.m3secondaryContainer

                    MaterialIcon {
                        id: shield

                        anchors.centerIn: parent
                        text: "shield_lock"
                        color: Colours.palette.m3onSecondaryContainer
                        fontStyle: Tokens.font.icon.medium
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.extraSmall

                    // What the action is, as polkit words it, e.g. "Authentication is required to
                    // run /usr/bin/pacman"
                    StyledText {
                        Layout.fillWidth: true

                        text: root.flow?.message ?? ""
                        font: Tokens.font.body.medium
                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    }

                    StyledText {
                        Layout.fillWidth: true
                        visible: text !== ""

                        text: root.notice
                        color: root.flow?.failed || root.flow?.supplementaryIsError ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.body.small
                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    }
                }
            }

            // Who to authenticate as, whenever polkit offers a choice
            RowLayout {
                Layout.fillWidth: true
                visible: root.pickIdentity
                spacing: Tokens.spacing.small

                Repeater {
                    model: root.identities

                    TextButton {
                        id: identityButton

                        required property var modelData

                        readonly property bool selected: root.flow?.selectedIdentity === identityButton.modelData

                        text: identityButton.modelData.displayName || identityButton.modelData.string
                        type: TextButton.Tonal
                        isToggle: true
                        checked: identityButton.selected
                        onClicked: {
                            if (root.flow) {
                                root.flow.selectedIdentity = identityButton.modelData;
                                password.text = "";
                            }
                        }
                    }
                }
            }

            StyledTextField {
                id: password

                Layout.fillWidth: true

                // The prompt polkit asked for is the password almost every time; the placeholder
                // carries its own wording, e.g. "Password:" or a username for the rare request
                // that wants one of those
                placeholderText: root.flow?.inputPrompt || Tr.tr("Password")
                leadingIcon: "key"
                echoMode: (root.flow?.responseVisible ?? false) ? TextInput.Normal : TextInput.Password
                enabled: root.awaitingInput

                onAccepted: root.submit()
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Tokens.spacing.extraSmall
                spacing: Tokens.spacing.small

                Loader {
                    active: root.verifying
                    visible: active

                    sourceComponent: LoadingIndicator {
                        implicitSize: Math.round(Tokens.font.body.small.pointSize * 1.4)
                    }
                }

                Item {
                    Layout.fillWidth: true
                }

                TextButton {
                    type: TextButton.Text
                    text: Tr.trCtx("Cancel", "button")
                    onClicked: root.cancel()
                }

                TextButton {
                    type: TextButton.Tonal
                    text: Tr.tr("Authenticate")
                    disabled: root.verifying || !root.awaitingInput
                    onClicked: root.submit()
                }
            }
        }
    }
}
