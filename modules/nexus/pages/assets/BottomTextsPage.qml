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

    readonly property list<MenuItem> animationItems: [
        MenuItem {
            readonly property string value: "fade"

            icon: "blur_on"
            text: Tr.tr("Fade")
            activeIcon: "check"
        },
        MenuItem {
            readonly property string value: "slide"

            icon: "swap_vert"
            text: Tr.tr("Slide")
            activeIcon: "check"
        },
        MenuItem {
            readonly property string value: "typewriter"

            icon: "keyboard"
            text: Tr.tr("Typewriter")
            activeIcon: "check"
        },
        MenuItem {
            readonly property string value: "scramble"

            icon: "shuffle"
            text: Tr.tr("Scramble")
            activeIcon: "check"
        },
        MenuItem {
            readonly property string value: "pop"

            icon: "zoom_in"
            text: Tr.tr("Pop")
            activeIcon: "check"
        },
        MenuItem {
            readonly property string value: "none"

            icon: "block"
            text: Tr.tr("None")
            activeIcon: "check"
        }
    ]

    property bool confirmingRemove: false

    function animationItem(value: string): MenuItem {
        return animationItems.find(i => i.value === value) ?? animationItems[0];
    }

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
            text: Tr.tr("Display")
        }

        ToggleRow {
            // SEARCH: quote random bottom screen line text
            first: true
            text: Tr.tr("Show the text")
            subtext: Tr.tr("A random line along the bottom of the screen")
            checked: GlobalConfig.utilities.bottomText.enabled
            onToggled: GlobalConfig.utilities.bottomText.enabled = checked
        }

        StepperRow {
            enabled: GlobalConfig.utilities.bottomText.enabled
            label: Tr.tr("Cycle interval")
            // TRANSLATORS: s is the second unit, leave it untranslated
            subtext: Tr.tr("How often the line changes (s)")
            value: Math.round(GlobalConfig.utilities.bottomText.cycleInterval / 1000)
            from: 5
            to: 600
            stepSize: 5
            onMoved: v => GlobalConfig.utilities.bottomText.cycleInterval = Math.round(v * 1000)
        }

        SelectRow {
            last: true
            enabled: GlobalConfig.utilities.bottomText.enabled
            label: Tr.tr("Animation between messages")
            subtext: Tr.tr("Transition used when rotating to the next message")
            active: root.animationItem(GlobalConfig.utilities.bottomText.animation)
            menuItems: root.animationItems
            onSelected: item => GlobalConfig.utilities.bottomText.animation = item.value
        }

        SectionHeader {
            text: Tr.tr("Lines")
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.largeIncreased
            Layout.rightMargin: Tokens.padding.largeIncreased
            Layout.bottomMargin: Tokens.spacing.small
            text: Tr.tr("One of these is shown at a time along the bottom of the screen. They are only a starting point, so replace them with your own.")
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
            wrapMode: Text.WordWrap
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.largeIncreased
            Layout.rightMargin: Tokens.padding.largeIncreased
            Layout.topMargin: Tokens.spacing.small
            visible: BottomText.texts.length === 0
            text: Tr.tr("No lines left, so nothing is shown. Add one below, or restore the defaults.")
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

        RowLayout {
            Layout.topMargin: Tokens.spacing.small
            spacing: Tokens.spacing.medium

            TextButton {
                visible: BottomText.texts.length > 0
                type: TextButton.Tonal
                isRound: true
                text: root.confirmingRemove ? Tr.tr("Remove every line?") : Tr.tr("Remove all")
                onClicked: {
                    if (root.confirmingRemove) {
                        BottomText.removeAll();
                        root.confirmingRemove = false;
                    } else {
                        root.confirmingRemove = true;
                    }
                }
            }

            TextButton {
                visible: BottomText.customized
                type: TextButton.Tonal
                isRound: true
                text: Tr.tr("Restore defaults")
                onClicked: {
                    root.confirmingRemove = false;
                    BottomText.restoreDefaults();
                }
            }

            StyledText {
                Layout.fillWidth: true
                visible: root.confirmingRemove
                text: Tr.tr("Click again to remove every line. Restore defaults brings the shell's own back.")
                color: Colours.palette.m3outline
                font: Tokens.font.label.small
                wrapMode: Text.WordWrap
            }
        }

        Item {
            Layout.fillHeight: true
            Layout.fillWidth: true
        }
    }
}
