pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

// Which apps get to notify, and how. A rule names a source by free text and holds what to do with
// it, so an app that is not installed - a script, a notify-send caller - can be named as well as
// one from the desktop entries. Sources are matched against the name a notification carries.
PageBase {
    id: root

    readonly property var rules: GlobalConfig.notifs.sourceRules

    function addRule(): void {
        const match = input.text.trim();
        if (!match)
            return;

        // A second rule for the same source could never be reached, since the first match wins
        if (root.rules.values.some(r => r.match.toLowerCase() === match.toLowerCase()))
            return;

        root.rules.insert({
            match,
            action: NotifSourceAction.Silence
        });
        input.clear();
    }

    function setAction(index: int, action: int): void {
        root.rules.at(index).action = action;
    }

    function removeRule(index: int): void {
        root.rules.remove(index);
    }

    title: Tr.tr("Notification sources")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: Tr.tr("Sources")
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.largeIncreased
            Layout.rightMargin: Tokens.padding.largeIncreased
            Layout.bottomMargin: Tokens.spacing.small
            text: Tr.tr("Rules are matched against the name an app puts on its notifications, ignoring case. The first matching rule wins, and anything with no rule is allowed.")
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
            wrapMode: Text.WordWrap
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.largeIncreased
            Layout.rightMargin: Tokens.padding.largeIncreased
            Layout.bottomMargin: Tokens.spacing.small
            text: Tr.tr("Allow shows the notification and keeps it. Discard shows the popup but keeps nothing. Silence does not show it at all.")
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
            wrapMode: Text.WordWrap
        }

        // Custom input: any string, not just apps from a list
        ConnectedRect {
            first: root.rules.values.length === 0
            last: root.rules.values.length === 0

            Layout.fillWidth: true
            implicitHeight: addRow.implicitHeight + Tokens.padding.medium * 2

            RowLayout {
                id: addRow

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: Tokens.padding.medium
                anchors.leftMargin: Tokens.padding.largeIncreased
                anchors.rightMargin: Tokens.padding.medium
                spacing: Tokens.spacing.medium

                StyledTextField {
                    id: input

                    Layout.fillWidth: true
                    placeholderText: Tr.tr("App name or part of it")
                    leadingIcon: "apps"
                    verticalPadding: Tokens.padding.small

                    onAccepted: root.addRule()
                }

                IconButton {
                    icon: "add"
                    type: IconButton.Filled
                    disabled: !input.text.trim()
                    onClicked: root.addRule()
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.largeIncreased
            Layout.rightMargin: Tokens.padding.largeIncreased
            Layout.bottomMargin: Tokens.spacing.small
            visible: root.rules.values.length === 0
            text: Tr.tr("No sources yet. Add one above to decide what it may do.")
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
            wrapMode: Text.WordWrap
        }

        Repeater {
            model: root.rules.values

            ConnectedRect {
                id: ruleRow

                required property var modelData
                required property int index

                Layout.fillWidth: true
                first: false
                last: ruleRow.index === root.rules.values.length - 1
                implicitHeight: ruleLayout.implicitHeight + Tokens.padding.medium * 2

                ColumnLayout {
                    id: ruleLayout

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.topMargin: Tokens.padding.medium
                    anchors.leftMargin: Tokens.padding.largeIncreased
                    anchors.rightMargin: Tokens.padding.medium
                    spacing: Tokens.spacing.small

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.medium

                        MaterialIcon {
                            text: ruleRow.modelData.action === NotifSourceAction.Silence ? "notifications_off" : ruleRow.modelData.action === NotifSourceAction.Discard ? "mark_email_unread" : "notifications"
                            color: Colours.palette.m3onSurfaceVariant
                            fontStyle: Tokens.font.icon.medium
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: ruleRow.modelData.match
                            font: Tokens.font.body.small
                            elide: Text.ElideRight
                        }

                        IconButton {
                            icon: "delete"
                            type: IconButton.Text
                            isRound: true
                            inactiveOnColour: Colours.palette.m3error
                            font: Tokens.font.icon.medium
                            onClicked: root.removeRule(ruleRow.index)
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.small

                        TextButton {
                            text: Tr.trCtx("Allow", "notification source action")
                            type: ruleRow.modelData.action === NotifSourceAction.Allow ? TextButton.Tonal : TextButton.Text
                            onClicked: root.setAction(ruleRow.index, NotifSourceAction.Allow)
                        }

                        TextButton {
                            text: Tr.trCtx("Discard", "notification source action")
                            type: ruleRow.modelData.action === NotifSourceAction.Discard ? TextButton.Tonal : TextButton.Text
                            onClicked: root.setAction(ruleRow.index, NotifSourceAction.Discard)
                        }

                        TextButton {
                            text: Tr.trCtx("Silence", "notification source action")
                            type: ruleRow.modelData.action === NotifSourceAction.Silence ? TextButton.Tonal : TextButton.Text
                            onClicked: root.setAction(ruleRow.index, NotifSourceAction.Silence)
                        }

                        Item {
                            Layout.fillWidth: true
                        }
                    }
                }
            }
        }
    }
}
