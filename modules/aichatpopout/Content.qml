pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.utils

// The AI chat: the sidebar's fifth tab, shown when Config.sidebar.aiChat is on (see
// modules/notifpopout/Content.qml). Conversations and their history are kept by the
// AiChat service; this is the list of messages, the composer and the history list that
// loads an older chat back into the tab.
Item {
    id: root

    required property bool open
    required property ScreenState screenState

    // The history list is out of the way until asked for, so the messages get the tab
    property bool showingHistory: false

    readonly property var chat: AiChat.activeChat
    readonly property var messages: root.chat?.messages ?? []
    readonly property bool busy: AiChat.pendingId !== "" && AiChat.pendingId === (root.chat?.id ?? "")

    // Keeps the draft when the chat could not take it, so nothing typed is lost
    function send(): void {
        if (AiChat.send(draft.text))
            draft.text = "";
    }

    function formatWhen(ms: int): string {
        const d = new Date(ms);
        if (Number.isNaN(d.getTime()))
            return "";

        const now = new Date();
        if (d.toDateString() === now.toDateString())
            return d.toLocaleTimeString(Qt.locale(), "HH:mm");

        return d.toLocaleDateString(Qt.locale(), d.getFullYear() === now.getFullYear() ? "d MMM" : "d MMM yyyy");
    }

    Component.onCompleted: {
        if (root.open)
            Qt.callLater(() => draft.forceActiveFocus());
    }

    onOpenChanged: {
        if (!root.open)
            return;

        root.showingHistory = false;
        Qt.callLater(() => draft.forceActiveFocus());
    }

    onShowingHistoryChanged: {
        if (!root.showingHistory)
            Qt.callLater(() => draft.forceActiveFocus());
    }

    focus: true
    Keys.onEscapePressed: {
        if (root.showingHistory)
            root.showingHistory = false;
        else
            root.screenState.sidebar = false;
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.medium

        // New chat, saved chats, and the title of the one on show
        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            IconButton {
                icon: "add_comment"
                type: IconButton.Text
                isRound: true
                font: Tokens.font.icon.small
                onClicked: AiChat.newChat()
            }

            IconButton {
                icon: "history"
                type: IconButton.Text
                isRound: true
                isToggle: true
                checked: root.showingHistory
                font: Tokens.font.icon.small
                onClicked: root.showingHistory = !root.showingHistory
            }

            StyledRect {
                Layout.fillWidth: true
                implicitHeight: titleText.implicitHeight + Tokens.padding.small * 2

                radius: Tokens.rounding.full
                color: Colours.tPalette.m3surfaceContainerHigh

                StyledText {
                    id: titleText

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: Tokens.padding.medium

                    text: root.chat?.title ?? Tr.tr("New chat")
                    elide: Text.ElideRight
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.medium
                }
            }
        }

        // Saved chats. Its height animates so the messages grow back into the space when
        // it closes; clip keeps the list from spilling out of the shrinking card.
        StyledRect {
            id: historyCard

            Layout.fillWidth: true
            implicitHeight: root.showingHistory ? 200 : 0
            visible: root.showingHistory || implicitHeight > 0.5

            radius: Tokens.rounding.large
            color: Colours.tPalette.m3surfaceContainerHigh
            clip: true

            Behavior on implicitHeight {
                Anim {
                    type: Anim.DefaultSpatial
                }
            }

            StyledText {
                anchors.centerIn: parent
                visible: historyList.count === 0
                horizontalAlignment: Text.AlignHCenter
                text: Tr.tr("Saved chats show up here")
                color: Colours.palette.m3outline
            }

            ListView {
                id: historyList

                anchors.fill: parent
                anchors.margins: Tokens.padding.small

                clip: true
                spacing: Tokens.spacing.extraSmall / 2

                model: ScriptModel {
                    values: AiChat.recentChats
                    objectProp: "id"
                }

                delegate: StyledRect {
                    id: historyRow

                    required property var modelData

                    readonly property bool current: historyRow.modelData.id === AiChat.activeId

                    width: ListView.view.width
                    implicitHeight: historyText.implicitHeight + Tokens.padding.small * 2
                    radius: Tokens.rounding.medium
                    color: historyRow.current ? Colours.tPalette.m3secondaryContainer : "transparent"

                    StateLayer {
                        radius: historyRow.radius
                        color: historyRow.current ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                        onClicked: {
                            AiChat.selectChat(historyRow.modelData.id);
                            root.showingHistory = false;
                        }
                    }

                    RowLayout {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Tokens.padding.medium
                        anchors.rightMargin: Tokens.padding.extraSmall
                        spacing: Tokens.spacing.small

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            StyledText {
                                id: historyText

                                Layout.fillWidth: true
                                text: historyRow.modelData.title
                                elide: Text.ElideRight
                                color: historyRow.current ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                                font: Tokens.font.body.small
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: root.formatWhen(historyRow.modelData.updatedAt)
                                color: historyRow.current ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3outline
                                font: Tokens.font.label.small
                            }
                        }

                        IconButton {
                            icon: "delete"
                            type: IconButton.Text
                            isRound: true
                            font: Tokens.font.icon.small
                            inactiveOnColour: Colours.palette.m3error
                            onClicked: AiChat.removeChat(historyRow.modelData.id)
                        }
                    }
                }

                StyledScrollBar.vertical: StyledScrollBar {
                    flickable: historyList
                }
            }
        }

        // The conversation. Empty while a fresh chat has nothing in it yet, and while no
        // provider is set up, which is what the line inside says.
        StyledRect {
            Layout.fillWidth: true
            Layout.fillHeight: true

            radius: Tokens.rounding.large
            color: Colours.tPalette.m3surfaceContainerHigh

            StyledText {
                anchors.centerIn: parent
                width: parent.width - Tokens.padding.large * 2
                visible: messageList.count === 0
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: !Ai.configured ? Tr.tr("Set up an AI provider in the Launcher settings to chat here") : Tr.tr("Ask anything; the conversation is saved when you send it")
                color: Colours.palette.m3outline
                font: Tokens.font.body.small
            }

            ListView {
                id: messageList

                anchors.fill: parent
                anchors.margins: Tokens.padding.medium

                clip: true
                spacing: Tokens.spacing.small
                // The last slot is the thinking line while a reply is on its way
                model: root.messages.length + (root.busy ? 1 : 0)

                onCountChanged: Qt.callLater(() => messageList.positionViewAtEnd())
                Component.onCompleted: Qt.callLater(() => messageList.positionViewAtEnd())

                delegate: Item {
                    id: messageRow

                    required property int index

                    readonly property var message: root.messages[messageRow.index] ?? null
                    readonly property bool user: (messageRow.message?.role ?? "user") === "user"

                    width: messageList.width
                    implicitHeight: messageRow.message === null ? thinking.implicitHeight : bubble.implicitHeight

                    StyledText {
                        id: thinking

                        anchors.left: parent.left
                        visible: messageRow.message === null
                        text: Tr.tr("Thinking...")
                        color: Colours.palette.m3outline
                        font: Tokens.font.body.small
                    }

                    StyledRect {
                        id: bubble

                        anchors.right: messageRow.user ? parent.right : undefined
                        anchors.left: messageRow.user ? undefined : parent.left
                        implicitWidth: Math.min(body.implicitWidth + Tokens.padding.medium * 2, messageList.width)
                        implicitHeight: body.implicitHeight + Tokens.padding.medium * 2
                        visible: messageRow.message !== null
                        radius: Tokens.rounding.large
                        color: messageRow.user ? Colours.tPalette.m3secondaryContainer : Colours.tPalette.m3surfaceContainerLow

                        StyledText {
                            id: body

                            anchors.centerIn: parent
                            width: Math.min(body.implicitWidth, messageList.width - Tokens.padding.medium * 2)
                            text: messageRow.message?.content ?? ""
                            wrapMode: Text.Wrap
                            textFormat: Text.PlainText
                            color: messageRow.user ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                            font: Tokens.font.body.small
                        }
                    }
                }

                StyledScrollBar.vertical: StyledScrollBar {
                    flickable: messageList
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            visible: AiChat.errorText !== ""
            text: AiChat.errorText
            wrapMode: Text.Wrap
            color: Colours.palette.m3error
            font: Tokens.font.body.small
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            StyledTextField {
                id: draft

                Layout.fillWidth: true
                placeholderText: !Ai.configured ? Tr.tr("Set up AI in the Launcher settings") : root.busy ? Tr.tr("Waiting for a reply...") : Tr.tr("Ask anything")
                enabled: Ai.configured && !root.busy
                onAccepted: root.send()
            }

            IconButton {
                icon: "send"
                type: IconButton.Filled
                disabled: !Ai.configured || root.busy || draft.text.trim() === ""
                onClicked: root.send()
            }
        }
    }
}
