pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.utils
import qs.modules.nexus.common

// Two steps on one page: the widget, then which variant of it to show. Picking a variant adds the card to the
// desktop and goes back to the widget list.
PageBase {
    id: root

    property string selectedKind: ""

    readonly property var kind: selectedKind !== "" ? WidgetCatalog.kindFor(root.selectedKind) : null
    readonly property var types: root.kind?.types ?? []

    function add(id: string, type: string): void {
        GlobalConfig.background.desktopWidgets.entries.insert({
            id: id,
            type: type,
            enabled: true
        });
        root.nState.closeSubPage();
    }

    title: root.kind ? root.kind.name : Tr.tr("Add widget")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // ---------- Step one: which widget ----------
        SectionHeader {
            first: true
            visible: !root.kind
            text: Tr.tr("Widget")
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.largeIncreased
            Layout.rightMargin: Tokens.padding.largeIncreased
            Layout.bottomMargin: Tokens.spacing.small
            visible: !root.kind
            wrapMode: Text.Wrap
            text: Tr.tr("Pick what to put on the desktop, then choose how it looks.")
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
        }

        Repeater {
            model: root.kind ? [] : WidgetCatalog.kinds

            NavRow {
                required property var modelData
                required property int index

                first: index === 0
                last: index === WidgetCatalog.kinds.length - 1
                icon: modelData.icon
                text: modelData.name
                subtext: WidgetCatalog.typesFor(modelData.id).length > 1 ? Tr.tr("%1 variants").arg(WidgetCatalog.typesFor(modelData.id).length) : Tr.tr("One style")
                onClicked: root.selectedKind = modelData.id
            }
        }

        // ---------- Step two: which variant ----------
        SectionHeader {
            first: true
            visible: !!root.kind
            text: Tr.tr("Style")
        }

        Repeater {
            model: root.types

            NavRow {
                required property var modelData
                required property int index

                first: index === 0
                last: index === root.types.length - 1
                icon: root.kind?.icon ?? "widgets"
                text: modelData.name
                subtext: Tr.tr("%1 rows tall").arg(modelData.height)
                onClicked: root.add(root.selectedKind, modelData.id)
            }
        }

        TextButton {
            Layout.alignment: Qt.AlignRight
            Layout.topMargin: Tokens.spacing.small
            visible: !!root.kind
            text: Tr.tr("Back to widgets")
            type: TextButton.Text
            onClicked: root.selectedKind = ""
        }
    }
}
