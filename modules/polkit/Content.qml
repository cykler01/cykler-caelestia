pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Caelestia.Blobs
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.components.effects
import qs.services

// The prompt for a polkit authentication request (see Polkit.qml): a dimmed screen with a panel
// asking for the password, built from the same containers and colours as the rest of the shell.
//
// NOTE(fork): with the notch's showPolkit on (the default) that panel is the notch opening up -
// it comes out of the top edge as a pill the size of the notch, on the notch's own alignment, and
// grows into the panel, with its surface drawn by the same blob renderer every other panel of the
// shell uses (Caelestia.Blobs), so it deforms on the way down and settles like they do. Its
// content follows the blob's own deform matrix, exactly as the drawers' panels follow theirs.
// Turning it off puts the card back in the middle of the screen, where it simply fades up.
Item {
    id: root

    // The flow of the request being answered, null once it is over
    property var flow: null

    readonly property bool island: Config.notch.enabled && Config.notch.showPolkit

    readonly property bool awaitingInput: root.flow?.isResponseRequired ?? false
    // The password has been handed over and polkit is checking it
    readonly property bool verifying: root.flow !== null && !root.flow.isResponseRequired && !root.flow.isCompleted
    readonly property var identities: root.flow?.identities ?? []
    // Only worth a picker when the request allows more than one identity
    readonly property bool pickIdentity: root.identities.length > 1

    // NOTE(fork): what the request said, kept after the flow has gone so the panel has something to
    // draw while it collapses back into the notch rather than emptying out first
    property string heldMessage
    property string heldIcon

    // Where polkit says why the last attempt failed, or what it is doing now
    readonly property string notice: {
        if (!root.flow)
            return "";

        if (root.flow.supplementaryMessage !== "")
            return root.flow.supplementaryMessage;

        return root.flow.failed ? Tr.tr("Authentication failed") : "";
    }
    readonly property bool noticeIsError: root.flow?.failed || root.flow?.supplementaryIsError || false

    // The action's own icon when the theme has one; the shield stands in otherwise, which is almost
    // always - most actions name an icon no icon theme actually carries
    readonly property string actionIcon: root.heldIcon !== "" && Quickshell.hasThemeIcon(root.heldIcon) ? Quickshell.iconPath(root.heldIcon) : ""

    // NOTE(fork): 0 while there is nothing to ask, 1 once the panel is down and open. One eased
    // value drives the whole morph - the drop from the edge, the growth out of the pill and (just
    // behind it) the content fading in - so it reads as one move rather than three.
    property real openProg: root.flow !== null ? 1 : 0
    // The content comes in behind the shape, and goes out in front of it
    readonly property real contentProg: Math.max(0, Math.min(1, (root.openProg - 0.45) / 0.55))
    // And the pill's own icon is gone before the content arrives, so the two never overlap
    readonly property real pillProg: 1 - Math.max(0, Math.min(1, root.openProg / 0.35))

    // The pill it grows out of: the size of the notch it is standing in for
    readonly property int pillWidth: 160
    readonly property int pillHeight: 52

    readonly property int fullWidth: Math.min(380, root.width - Tokens.padding.extraLargeIncreased)
    readonly property int fullHeight: layout.implicitHeight + Tokens.padding.large * 3

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
        if (root.flow) {
            root.heldMessage = root.flow.message ?? "";
            root.heldIcon = root.flow.iconName ?? "";
            focusTimer.restart();
        }
    }

    focus: true

    Keys.onEscapePressed: root.cancel()

    Behavior on openProg {
        Anim {
            type: Anim.DefaultSpatial
        }
    }

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

        color: Qt.alpha(Colours.palette.m3scrim, 0.45 * root.openProg)

        // Swallows clicks meant for whatever is underneath
        MouseArea {
            anchors.fill: parent
        }
    }

    // The panel's surface, drawn by the blob renderer so it carries the shell's own deform springs
    // and drop shadow. Everything the panel shows sits in `card` above it, moved by the same
    // deform matrix the shape is drawn with.
    Item {
        anchors.fill: parent

        // Off the island the panel has no morph to grow out of, so the shape fades up with its
        // content rather than being drawn at full strength behind it
        opacity: card.opacity
        layer.enabled: PowerSaving.shadows
        layer.effect: MultiEffect {
            shadowEnabled: PowerSaving.shadows
            blurMax: 15
            shadowColor: Qt.alpha(Colours.palette.m3shadow, 0.7)
        }

        BlobGroup {
            id: blobGroup

            color: Colours.tPalette.m3surface
            smoothing: root.Config.border.smoothing
        }

        BlobRect {
            id: cardBg

            group: blobGroup
            x: card.x
            y: card.y
            implicitWidth: card.width
            implicitHeight: card.height
            radius: card.radius
            deformScale: (0.15 * Config.appearance.deformScale) / 10000
        }
    }

    Item {
        id: card

        // NOTE(fork): the island comes out of the top edge on the notch's own alignment; the plain
        // card sits in the middle of the screen. Both are plain x/y bindings rather than anchors,
        // so the setting can be changed while the shell runs.
        readonly property real islandX: Config.notch.align === PanelAlign.Start ? Tokens.padding.large : Config.notch.align === PanelAlign.End ? root.width - width - Tokens.padding.large : (root.width - width) / 2
        readonly property real islandY: Tokens.padding.medium - (root.pillHeight + Tokens.padding.medium) * (1 - root.openProg)

        readonly property real radius: Math.min(Tokens.rounding.extraLarge, height / 2)

        x: root.island ? islandX : (root.width - width) / 2
        y: root.island ? islandY : (root.height - height) / 2
        // Grows out of a notch-sized pill into the panel. Off the island it is simply the panel,
        // faded up where it stands.
        width: root.island ? root.pillWidth + (root.fullWidth - root.pillWidth) * root.openProg : root.fullWidth
        height: root.island ? root.pillHeight + (root.fullHeight - root.pillHeight) * root.openProg : root.fullHeight
        opacity: root.island ? 1 : root.openProg

        // The content is laid out at full size the whole way, so it never reflows while the shape
        // is still growing - the shape simply uncovers it
        clip: true

        transform: Matrix4x4 {
            matrix: cardBg.deformMatrix
        }

        // What the pill shows before it has opened: the same shield the panel leads with, which is
        // the one thing that does not move as it grows
        MaterialIcon {
            anchors.centerIn: parent

            opacity: root.pillProg
            visible: opacity > 0.01
            text: "shield_lock"
            color: Colours.palette.m3primary
            fontStyle: Tokens.font.icon.large
        }

        ColumnLayout {
            id: layout

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: Tokens.padding.large * 1.5

            width: root.fullWidth - Tokens.padding.large * 3
            opacity: root.contentProg
            visible: opacity > 0.01
            spacing: Tokens.spacing.medium

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.medium

                StyledRect {
                    Layout.alignment: Qt.AlignTop

                    implicitWidth: implicitHeight
                    implicitHeight: shield.implicitHeight + Tokens.padding.medium * 2
                    radius: Tokens.rounding.full
                    color: Colours.palette.m3secondaryContainer

                    MaterialIcon {
                        id: shield

                        anchors.centerIn: parent
                        visible: root.actionIcon === ""
                        text: "shield_lock"
                        color: Colours.palette.m3onSecondaryContainer
                        fontStyle: Tokens.font.icon.medium
                    }

                    Loader {
                        anchors.centerIn: parent

                        active: root.actionIcon !== ""
                        asynchronous: true
                        width: Math.round(parent.width * 0.55)
                        height: width

                        sourceComponent: ColouredIcon {
                            anchors.fill: parent
                            source: root.actionIcon
                            colour: Colours.palette.m3onSecondaryContainer
                            layer.enabled: root.heldIcon.endsWith("symbolic")
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.extraSmall

                    StyledText {
                        Layout.fillWidth: true

                        text: Tr.tr("Authentication required")
                        color: Colours.palette.m3onSurface
                        font: Tokens.font.title.small
                        elide: Text.ElideRight
                    }

                    // What the action is, as polkit words it, e.g. "Authentication is required to
                    // run /usr/bin/pacman". It can be a paragraph with a whole command line in it,
                    // so it is given three lines and elided rather than allowed to push the panel
                    // down the screen
                    StyledText {
                        Layout.fillWidth: true

                        text: root.heldMessage
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.body.small
                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                        maximumLineCount: 3
                        elide: Text.ElideRight
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
                        // The press is not what makes it the selected identity - the flow is (see
                        // optimistic in ButtonBase)
                        optimistic: false
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

            // Why the last attempt failed, or what polkit is doing now: under the field it is about
            // rather than up beside the message. Its own row rather than the field's supporting
            // text, which the field clears the error state of as soon as anything is typed
            StyledText {
                Layout.fillWidth: true
                Layout.topMargin: -Tokens.spacing.extraSmall

                visible: text !== ""
                text: root.notice
                color: root.noticeIsError ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.small
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                Loader {
                    Layout.alignment: Qt.AlignVCenter

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
                    type: TextButton.Filled
                    text: Tr.tr("Authenticate")
                    disabled: root.verifying || !root.awaitingInput
                    onClicked: root.submit()
                }
            }
        }
    }
}
