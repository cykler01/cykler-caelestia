pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common
import qs.modules.nexus.pages.battery

// An editable card describing the actions for one battery threshold (fork feature)
ConnectedRect {
    id: root

    required property var modelData
    required property int index

    readonly property var thresholdData: root.modelData
    readonly property bool expanded: menuLoader.active
    readonly property list<MenuItem> profileItems: [
        MenuItem {
            text: Tr.tr("Unchanged")
            value: ""
        },
        MenuItem {
            text: Tr.tr("Power Saver")
            value: "power-saver"
        },
        MenuItem {
            text: Tr.tr("Balanced")
            value: "balanced"
        },
        MenuItem {
            text: Tr.tr("Performance")
            value: "performance"
        }
    ]

    signal thresholdChanged(var newData)
    signal removeRequested

    Layout.fillWidth: true
    implicitHeight: expanded ? (menuLoader.item?.implicitHeight ?? 0) + Tokens.padding.medium * 2 : row.implicitHeight + Tokens.padding.medium * 2

    topLeftRadius: root.first ? Tokens.rounding.extraLarge : Tokens.rounding.extraSmall
    topRightRadius: root.first ? Tokens.rounding.extraLarge : Tokens.rounding.extraSmall
    bottomLeftRadius: root.last ? Tokens.rounding.extraLarge : Tokens.rounding.extraSmall
    bottomRightRadius: root.last ? Tokens.rounding.extraLarge : Tokens.rounding.extraSmall

    StateLayer {
        onClicked: menuLoader.active = !menuLoader.active
    }

    RowLayout {
        id: row

        visible: !root.expanded
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Tokens.padding.largeIncreased
        anchors.rightMargin: Tokens.padding.largeIncreased
        spacing: Tokens.spacing.medium

        MaterialIcon {
            color: Colours.palette.m3onSurfaceVariant
            fontStyle: Tokens.font.icon.medium
            text: "battery_5_bar"
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                text: Tr.tr("%1% battery").arg(root.thresholdData.level)
                font: Tokens.font.body.small
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                text: {
                    const actions = [];
                    if (root.thresholdData.setPowerProfile)
                        actions.push(root.thresholdData.setPowerProfile);
                    if (root.thresholdData.setRefreshRate)
                        actions.push(root.thresholdData.setRefreshRate === "auto" ? Tr.tr("lowest Hz") : `${root.thresholdData.setRefreshRate} Hz`);
                    if (root.thresholdData.disableAnimations)
                        actions.push(root.thresholdData.disableAnimations === "disable" ? Tr.tr("no animations") : Tr.tr("animations on"));
                    if (root.thresholdData.disableBlur)
                        actions.push(root.thresholdData.disableBlur === "disable" ? Tr.tr("no blur") : Tr.tr("blur on"));
                    if (root.thresholdData.disableRounding)
                        actions.push(root.thresholdData.disableRounding === "disable" ? Tr.tr("no rounding") : Tr.tr("rounding on"));
                    if (root.thresholdData.disableShadows)
                        actions.push(root.thresholdData.disableShadows === "disable" ? Tr.tr("no shadows") : Tr.tr("shadows on"));
                    return actions.length > 0 ? actions.join(", ") : Tr.tr("No actions");
                }
                visible: text !== Tr.tr("No actions")
                color: Colours.palette.m3outline
                font: Tokens.font.label.small
                elide: Text.ElideRight
            }
        }

        IconButton {
            icon: "delete"

            onClicked: root.removeRequested()
        }
    }

    Loader {
        id: menuLoader

        active: false
        asynchronous: true
        anchors.left: parent.left
        anchors.right: parent.right

        sourceComponent: ColumnLayout {
            spacing: Tokens.spacing.extraSmall / 2

            RowLayout {
                Layout.fillWidth: true
                Layout.margins: Tokens.padding.medium
                spacing: Tokens.spacing.medium

                IconButton {
                    icon: "arrow_back"

                    onClicked: menuLoader.active = false
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Tr.tr("%1% battery").arg(root.thresholdData.level)
                    font: Tokens.font.title.medium
                    elide: Text.ElideRight
                }

                IconButton {
                    icon: "delete"

                    onClicked: {
                        menuLoader.active = false;
                        root.removeRequested();
                    }
                }
            }

            StepperRow {
                first: true
                label: Tr.tr("Battery level")
                subtext: Tr.tr("Applies when charge falls to this level")
                value: root.thresholdData.level
                from: 5
                to: 95
                stepSize: 5
                onMoved: v => root.thresholdChanged(Object.assign({}, root.thresholdData, {
                        "level": Math.round(v)
                    }))
            }

            SelectRow {
                label: Tr.tr("Power profile")
                menuItems: root.profileItems
                active: root.profileItems.find(item => item.value === root.thresholdData.setPowerProfile) ?? root.profileItems[0]
                onSelected: item => root.thresholdChanged(Object.assign({}, root.thresholdData, {
                        "setPowerProfile": item.value
                    }))
            }

            RefreshRateSelector {
                label: Tr.tr("Refresh rate")
                showUnchanged: true
                value: root.thresholdData.setRefreshRate
                onRateChanged: newValue => root.thresholdChanged(Object.assign({}, root.thresholdData, {
                        "setRefreshRate": newValue
                    }))
            }

            TriStateRow {
                first: true
                label: Tr.tr("Animations")
                value: root.thresholdData.disableAnimations
                onTriStateValueChanged: newValue => root.thresholdChanged(Object.assign({}, root.thresholdData, {
                        "disableAnimations": newValue
                    }))
            }

            TriStateRow {
                label: Tr.tr("Blur")
                value: root.thresholdData.disableBlur
                onTriStateValueChanged: newValue => root.thresholdChanged(Object.assign({}, root.thresholdData, {
                        "disableBlur": newValue
                    }))
            }

            TriStateRow {
                label: Tr.tr("Rounding")
                value: root.thresholdData.disableRounding
                onTriStateValueChanged: newValue => root.thresholdChanged(Object.assign({}, root.thresholdData, {
                        "disableRounding": newValue
                    }))
            }

            TriStateRow {
                last: true
                label: Tr.tr("Shadows")
                value: root.thresholdData.disableShadows
                onTriStateValueChanged: newValue => root.thresholdChanged(Object.assign({}, root.thresholdData, {
                        "disableShadows": newValue
                    }))
            }
        }
    }
}
