pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.modules.nexus.common

// An editable card for the actions applied while a power profile is active (fork feature)
ConnectedRect {
    id: root

    required property string profileName
    required property var behavior

    Layout.fillWidth: true
    implicitHeight: layout.implicitHeight + Tokens.padding.medium * 2

    topLeftRadius: root.first ? Tokens.rounding.extraLarge : Tokens.rounding.extraSmall
    topRightRadius: root.first ? Tokens.rounding.extraLarge : Tokens.rounding.extraSmall
    bottomLeftRadius: root.last ? Tokens.rounding.extraLarge : Tokens.rounding.extraSmall
    bottomRightRadius: root.last ? Tokens.rounding.extraLarge : Tokens.rounding.extraSmall

    ColumnLayout {
        id: layout

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Tokens.padding.largeIncreased
        spacing: Tokens.spacing.extraSmall / 2

        StyledText {
            text: root.profileName
            font: Tokens.font.title.small
        }

        RefreshRateSelector {
            Layout.fillWidth: true
            label: Tr.tr("Refresh rate")
            showRestore: true
            showUnchanged: true
            value: root.behavior.setRefreshRate
            onRateChanged: newValue => root.behavior.setRefreshRate = newValue
        }

        TriStateRow {
            Layout.fillWidth: true
            label: Tr.tr("Animations")
            value: root.behavior.disableAnimations
            onTriStateValueChanged: newValue => root.behavior.disableAnimations = newValue
        }

        TriStateRow {
            Layout.fillWidth: true
            label: Tr.tr("Blur")
            value: root.behavior.disableBlur
            onTriStateValueChanged: newValue => root.behavior.disableBlur = newValue
        }

        TriStateRow {
            Layout.fillWidth: true
            label: Tr.tr("Rounding")
            value: root.behavior.disableRounding
            onTriStateValueChanged: newValue => root.behavior.disableRounding = newValue
        }

        TriStateRow {
            Layout.fillWidth: true
            label: Tr.tr("Shadows")
            value: root.behavior.disableShadows
            onTriStateValueChanged: newValue => root.behavior.disableShadows = newValue
        }
    }
}
