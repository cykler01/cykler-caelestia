pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

// Settings > Panels > Dashboard > Widgets: arranges the cards on the dashboard's home page
PageBase {
    id: root

    readonly property var widgetNames: ({
            weather: Tr.tr("Weather"),
            clock: Tr.tr("Clock"),
            profile: Tr.tr("Profile"),
            calendar: Tr.tr("Calendar"),
            resources: Tr.tr("Resources"),
            media: Tr.tr("Media")
        })

    readonly property var widgetIcons: ({
            weather: "partly_cloudy_day",
            clock: "schedule",
            profile: "account_circle",
            calendar: "calendar_month",
            resources: "monitoring",
            media: "music_note"
        })

    // Mirrors the C++ defaults in dashboardconfig.hpp, for the reset button below
    readonly property var defaults: ({
            weather: "top",
            profile: "top",
            clock: "bottom",
            calendar: "bottom",
            resources: "bottom",
            media: "right"
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
            text: Tr.tr("Layout")
        }

        StyledText {
            Layout.fillWidth: true
            Layout.bottomMargin: Tokens.spacing.small
            text: Tr.tr("This is the real page, just smaller. Drag a card into the row or column it should be in, or along a row to reorder it. Hover a card for the button that takes it off the page.")
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
            wrapMode: Text.WordWrap
        }

        DashPreview {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.small
            Layout.bottomMargin: Tokens.spacing.medium
            list: GlobalConfig.dashboard.widgets
            names: root.widgetNames
            icons: root.widgetIcons
            nState: root.nState
        }

        TextButton {
            Layout.alignment: Qt.AlignRight
            text: Tr.tr("Reset layout")
            type: TextButton.Tonal
            onClicked: {
                const list = GlobalConfig.dashboard.widgets;
                for (const id in root.defaults) {
                    const index = list.values.findIndex(e => e.id === id);
                    if (index < 0)
                        // Taken off the page entirely - put it back where it started
                        list.insert({
                            id: id,
                            enabled: true,
                            zone: root.defaults[id]
                        });
                    else
                        list.at(index).zone = root.defaults[id];
                }
            }
        }

        DialogSelectButton {
            rootParent: root.flickable
            // Nothing connects to this button's top edge — the reset button
            // above it is a right-aligned pill, not a row in the group — so it
            // is the start of its own group and takes the full outer radius.
            // Left unset it defaults to false and renders a 4px top with a 28px
            // bottom, which reads as a row torn off the list above it.
            first: true
            icon: "add"
            label: Tr.tr("Add widget")
            header: Tr.tr("Add a widget")
            acceptLabel: Tr.trCtx("Add", "button")

            // Only widgets that aren't on the page already
            model: Object.keys(root.widgetNames).filter(id => !GlobalConfig.dashboard.widgets.values.some(e => e.id === id)).map(id => ({
                        id: id,
                        label: root.widgetNames[id]
                    }))

            onAccepted: {
                if (!selectedItem)
                    return;
                GlobalConfig.dashboard.widgets.insert({
                    id: selectedItem,
                    enabled: true,
                    zone: root.defaults[selectedItem] ?? "top"
                });
            }
        }
    }
}
