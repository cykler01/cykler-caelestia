pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.nexus

// One setting matched by the search, rather than a whole page. The row under the
// name is the trail to it - the page, the sub-page it is on and the section header
// above it - because a lot of the names only mean something in context: there are
// ten settings called "Enabled" and five called "Show on hover".
StyledRect {
    id: root

    required property var modelData
    required property bool first
    required property bool last
    required property NexusState nState

    readonly property string trail: {
        const entry = root.modelData;
        const parts = [entry.pageLabel];
        if (entry.path.length > 0 && entry.title && entry.title !== entry.pageLabel)
            parts.push(entry.title);
        const path = parts.join(" › ");
        return entry.section ? `${path} · ${entry.section}` : path;
    }

    Layout.fillWidth: true
    // Rounded up to an even number, so the round icon chip lands on a whole pixel
    implicitHeight: {
        const h = layout.implicitHeight + layout.anchors.margins * 2;
        return h % 2 === 0 ? h : h + 1;
    }

    color: Colours.layer(Colours.palette.m3surfaceContainerHigh, 2)
    topLeftRadius: stateLayer.pressed ? Tokens.rounding.medium : root.first ? Tokens.rounding.extraLarge : Tokens.rounding.extraSmall
    topRightRadius: root.topLeftRadius
    bottomLeftRadius: stateLayer.pressed ? Tokens.rounding.medium : root.last ? Tokens.rounding.extraLarge : Tokens.rounding.extraSmall
    bottomRightRadius: root.bottomLeftRadius

    RadiusBehavior on topLeftRadius {}
    RadiusBehavior on topRightRadius {}
    RadiusBehavior on bottomLeftRadius {}
    RadiusBehavior on bottomRightRadius {}

    StateLayer {
        id: stateLayer

        anchors.fill: parent
        topLeftRadius: parent.topLeftRadius
        topRightRadius: parent.topRightRadius
        bottomLeftRadius: parent.bottomLeftRadius
        bottomRightRadius: parent.bottomRightRadius

        onClicked: root.nState.openSetting(root.modelData)
    }

    RowLayout {
        id: layout

        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.medium

        // The same round chip the page rows use, so a result does not read as a
        // different kind of thing to the list it replaces
        StyledRect {
            Layout.fillHeight: true
            Layout.topMargin: -1
            Layout.bottomMargin: -1
            implicitWidth: height

            radius: Tokens.rounding.full
            color: Colours.palette.m3secondaryContainer

            MaterialIcon {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: 1

                text: root.modelData.icon
                color: Colours.palette.m3onSecondaryContainer
                fontStyle: Tokens.font.icon.builders.medium.weight(Font.Medium).build()
                grade: 25
                fill: root.modelData.noFill ? 0 : 1
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                text: root.modelData.label
                font: Tokens.font.body.medium
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                text: root.trail
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.small
                elide: Text.ElideRight
            }
        }
    }

    component RadiusBehavior: Behavior {
        Anim {
            type: Anim.DefaultEffects
        }
    }
}
