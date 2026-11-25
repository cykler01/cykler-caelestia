pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

// NOTE(fork): the lines shown at random along the bottom of the screen. They are meant to be the
// user's own, so edits go to a copy under the data directory and the shell's shipped list is left
// alone (it can be read only, e.g. under /etc/xdg), leaving a reset back to it always possible.
PageBase {
    id: root

    function commitAdd(): void {
        const text = input.text.trim();
        if (text === "")
            return;

        BottomText.addLine(text);
        input.clear();
    }

    title: Tr.tr("Desktop text")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: Tr.tr("Lines")
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.largeIncreased
            Layout.rightMargin: Tokens.padding.largeIncreased
            Layout.bottomMargin: Tokens.spacing.small
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
            wrapMode: Text.WordWrap
        }

        // A new line, typed straight into the list
        ConnectedRect {
            first: BottomText.texts.length === 0
            last: BottomText.texts.length === 0

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
                    placeholderText: Tr.tr("Add a line")
                    leadingIcon: "subtitles"
                    verticalPadding: Tokens.padding.small
                    onAccepted: root.commitAdd()
                }

                IconButton {
                    icon: "add"
                    type: IconButton.Filled
                    disabled: input.text.trim() === ""
                    onClicked: root.commitAdd()
                }
            }
        }

        Repeater {
            model: BottomText.texts

            ConnectedRect {
                id: lineRow

                required property string modelData
                required property int index

                Layout.fillWidth: true
                last: lineRow.index === BottomText.texts.length - 1
                implicitHeight: lineLayout.implicitHeight + Tokens.padding.medium * 2

                RowLayout {
                    id: lineLayout

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.topMargin: Tokens.padding.medium
                    anchors.leftMargin: Tokens.padding.largeIncreased
                    anchors.rightMargin: Tokens.padding.medium
                    spacing: Tokens.spacing.medium

                    StyledTextField {
                        Layout.fillWidth: true
                        text: lineRow.modelData
                        verticalPadding: Tokens.padding.small
                        onEditingFinished: {
                            if (text !== lineRow.modelData)
                                BottomText.setLine(lineRow.index, text);
                        }
                    }

                    IconButton {
                        icon: "delete"
                        type: IconButton.Text
                        isRound: true
                        inactiveOnColour: Colours.palette.m3error
                        font: Tokens.font.icon.medium
                        onClicked: BottomText.removeLine(lineRow.index)
                    }
                }
            }
        }

        TextButton {
            Layout.topMargin: Tokens.spacing.small
            visible: BottomText.customized
            text: Tr.tr("Restore the shipped lines")
            onClicked: BottomText.restoreDefaults()
        }

        Item {
            Layout.fillHeight: true
            Layout.fillWidth: true
        }
    }
}
