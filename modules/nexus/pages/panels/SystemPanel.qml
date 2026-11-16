pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

// Which readings the system resources card shows, set separately for each of its styles. Every style has three
// slots; the two-reading variants show the first two
PageBase {
    id: root

    readonly property list<MenuItem> metricItems: [
        MenuItem {
            text: WidgetData.metricInfo("cpu").name
            icon: WidgetData.metricInfo("cpu").icon
            value: "cpu"
        },
        MenuItem {
            text: WidgetData.metricInfo("ram").name
            icon: WidgetData.metricInfo("ram").icon
            value: "ram"
        },
        MenuItem {
            text: WidgetData.metricInfo("disk").name
            icon: WidgetData.metricInfo("disk").icon
            value: "disk"
        },
        MenuItem {
            text: WidgetData.metricInfo("temp").name
            icon: WidgetData.metricInfo("temp").icon
            value: "temp"
        },
        MenuItem {
            text: WidgetData.metricInfo("gpu").name
            icon: WidgetData.metricInfo("gpu").icon
            value: "gpu"
        },
        MenuItem {
            text: WidgetData.metricInfo("gputemp").name
            icon: WidgetData.metricInfo("gputemp").icon
            value: "gputemp"
        }
    ]

    function itemFor(id: string): MenuItem {
        for (const item of root.metricItems)
            if (item.value === id)
                return item;
        return root.metricItems[0];
    }

    // Writes one slot of a style's list. The list is rebuilt from the resolved three rather than the stored
    // one, so a config that is short or holds an unknown id comes out whole
    function setSlot(key: string, current: var, slot: int, id: string): void {
        const next = current.slice();
        next[slot] = id;
        GlobalConfig.background.desktopWidgets[key] = next;
    }

    title: Tr.tr("System")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.largeIncreased
            Layout.rightMargin: Tokens.padding.largeIncreased
            Layout.topMargin: Tokens.spacing.small
            wrapMode: Text.Wrap
            text: Tr.tr("Pick the three readings each style of the system card shows. The two-reading variants show the first two.")
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
        }

        SectionHeader {
            first: true
            text: Tr.tr("Rings")
        }

        Repeater {
            model: 3

            SelectRow {
                required property int index

                first: index === 0
                last: index === 2
                label: Tr.tr("Ring %1").arg(index + 1)
                menuItems: root.metricItems
                active: root.itemFor(WidgetData.ringMetrics[index])
                onSelected: item => root.setSlot("systemRingMetrics", WidgetData.ringMetrics, index, item.value)
            }
        }

        SectionHeader {
            text: Tr.tr("Bars")
        }

        Repeater {
            model: 3

            SelectRow {
                required property int index

                first: index === 0
                last: index === 2
                label: Tr.tr("Bar %1").arg(index + 1)
                menuItems: root.metricItems
                active: root.itemFor(WidgetData.barMetrics[index])
                onSelected: item => root.setSlot("systemBarMetrics", WidgetData.barMetrics, index, item.value)
            }
        }

        SectionHeader {
            text: Tr.tr("Line graph")
        }

        Repeater {
            model: 3

            SelectRow {
                required property int index

                first: index === 0
                last: index === 2
                label: Tr.tr("Line %1").arg(index + 1)
                menuItems: root.metricItems
                active: root.itemFor(WidgetData.lineMetrics[index])
                // The last slots sit near the bottom of the page, so their menus open upwards
                menuOnTop: index === 2
                onSelected: item => root.setSlot("systemLineMetrics", WidgetData.lineMetrics, index, item.value)
            }
        }
    }
}
