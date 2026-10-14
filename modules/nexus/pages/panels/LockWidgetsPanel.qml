pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    readonly property var widgetNames: ({
            weather: Tr.tr("Weather"),
            fetch: Tr.tr("System info"),
            media: Tr.tr("Now playing"),
            resources: Tr.tr("System resources"),
            battery: Tr.tr("Battery"),
            notifs: Tr.tr("Notifications"),
            network: Tr.tr("Network"),
            audio: Tr.tr("Volume")
        })

    readonly property var widgetIcons: ({
            weather: "partly_cloudy_day",
            fetch: "terminal",
            media: "music_note",
            resources: "monitoring",
            battery: "bolt",
            notifs: "notifications",
            network: "wifi",
            audio: "volume_up"
        })

    // Mirrors the C++ defaults in lockconfig.hpp, for the reset button below
    readonly property var defaults: ({
            weather: { column: "left", weight: 1.0 },
            fetch: { column: "left", weight: 0.8 },
            media: { column: "left", weight: 1.3 },
            resources: { column: "right", weight: 1.0 },
            battery: { column: "right", weight: 0.6 },
            notifs: { column: "right", weight: 1.6 }
        })

    title: Tr.tr("Widgets")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: Tr.tr("Preview")
        }

        LockScreenPreview {
            Layout.fillWidth: true
            Layout.bottomMargin: Tokens.spacing.medium
            screenHeight: root.nState.screen?.height ?? 1080
        }

        SectionHeader {
            text: Tr.tr("Side columns")
        }

        StyledText {
            Layout.fillWidth: true
            Layout.bottomMargin: Tokens.spacing.small
            text: Tr.tr("Drag a widget's handle to reorder it, or drag it across to the other column to move it there. Drag the thin strip under a widget to resize it against the one below. The delete button removes it entirely - the add button below brings it back.")
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
            wrapMode: Text.WordWrap
        }

        LockWidgetStack {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.small
            Layout.bottomMargin: Tokens.spacing.medium
            list: GlobalConfig.lock.widgets
            names: root.widgetNames
            icons: root.widgetIcons
        }

        TextButton {
            Layout.alignment: Qt.AlignRight
            text: Tr.tr("Reset layout")
            type: TextButton.Tonal
            onClicked: {
                const list = GlobalConfig.lock.widgets;
                for (const id in root.defaults) {
                    const index = list.values.findIndex(e => e.id === id);
                    if (index < 0)
                        // Deleted from the list entirely - re-add it in its default column
                        list.insert({
                            id: id,
                            enabled: true,
                            column: root.defaults[id].column,
                            weight: root.defaults[id].weight
                        });
                    else {
                        list.at(index).column = root.defaults[id].column;
                        list.at(index).weight = root.defaults[id].weight;
                    }
                }
            }
        }

        DialogSelectButton {
            rootParent: root.flickable
            icon: "add"
            label: Tr.tr("Add widget")
            header: Tr.tr("Add a widget")
            acceptLabel: Tr.trCtx("Add", "button")

            // Only widgets that aren't in the list already
            model: Object.keys(root.widgetNames).filter(id => !GlobalConfig.lock.widgets.values.some(e => e.id === id)).map(id => ({
                        id: id,
                        label: root.widgetNames[id]
                    }))

            onAccepted: {
                if (!selectedItem)
                    return;
                GlobalConfig.lock.widgets.insert({
                    id: selectedItem,
                    enabled: true
                });
            }
        }
    }
}
