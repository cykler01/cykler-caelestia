pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

// Picks one line's colour for the Custom performance graph scheme: a swatch from the current
// colour scheme (saved by role, so it follows wallpaper changes) or a fixed hex colour.
ConnectedRect {
    id: root

    readonly property list<string> roles: ["primary", "secondary", "tertiary", "success", "error", "onSurfaceVariant", "term1", "term2", "term3", "term4", "term5", "term6"]

    property alias label: label.text
    required property string value

    signal picked(value: string)

    Layout.fillWidth: true
    implicitHeight: layout.implicitHeight + Tokens.padding.medium * 2

    ColumnLayout {
        id: layout

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Tokens.padding.largeIncreased
        anchors.rightMargin: Tokens.padding.largeIncreased
        spacing: Tokens.spacing.small

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.medium

            StyledRect {
                implicitWidth: Tokens.padding.largeIncreased
                implicitHeight: implicitWidth
                radius: Tokens.rounding.full
                color: ResourceHistory.resolveColour(root.value)
            }

            StyledText {
                id: label

                Layout.fillWidth: true
                font: Tokens.font.body.small
                elide: Text.ElideRight
            }

            StyledTextField {
                Layout.preferredWidth: Tokens.sizes.nexus.smallTextFieldWidth
                verticalPadding: Tokens.padding.small
                placeholderText: "#rrggbb"
                maximumLength: 7
                validate: /^#[0-9a-fA-F]{6}$/
                text: root.value.startsWith("#") ? root.value : ""

                onEditingFinished: {
                    if (text && valid && text !== root.value)
                        root.picked(text.toLowerCase());
                }
            }
        }

        Flow {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            Repeater {
                model: root.roles

                StyledRect {
                    id: swatch

                    required property string modelData
                    readonly property bool selected: root.value === modelData

                    implicitWidth: Tokens.padding.extraLarge
                    implicitHeight: implicitWidth
                    radius: Tokens.rounding.full
                    color: ResourceHistory.resolveColour(modelData)
                    border.width: selected ? Tokens.padding.extraSmall / 2 : 0
                    border.color: Colours.palette.m3onSurface

                    MaterialIcon {
                        anchors.centerIn: parent
                        visible: swatch.selected
                        text: "check"
                        color: Colours.palette.m3surface
                        fontStyle: Tokens.font.icon.small
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.picked(swatch.modelData)
                    }
                }
            }
        }
    }
}
