pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services

StyledRect {
    id: root

    property real maxListHeight: 240
    property var processes: []
    property int selectedPid: -1
    property string sortKey: "cpu"
    property bool sortDescending: true

    readonly property var sortedProcesses: {
        const rows = [...processes];
        const key = sortKey;
        const direction = sortDescending ? -1 : 1;
        rows.sort((a, b) => {
            const av = a[key] ?? "";
            const bv = b[key] ?? "";
            const comparison = typeof av === "number" && typeof bv === "number" ? av - bv : String(av).localeCompare(String(bv));
            return comparison * direction || a.pid - b.pid;
        });
        return rows;
    }

    function setSort(key: string): void {
        if (sortKey === key)
            sortDescending = !sortDescending;
        else {
            sortKey = key;
            sortDescending = key !== "name" && key !== "command";
        }
    }

    function refresh(): void {
        monitorProc.running = true;
    }

    function killSelected(): void {
        if (selectedPid <= 1)
            return;
        killProc.command = ["/usr/bin/kill", "-TERM", String(selectedPid)];
        killProc.running = true;
        selectedPid = -1;
        Qt.callLater(refresh);
    }

    function formatRate(bytesPerSecond: real): string {
        if (bytesPerSecond >= 1024 * 1024)
            return `${(bytesPerSecond / (1024 * 1024)).toFixed(1)} MiB/s`;
        return `${(bytesPerSecond / 1024).toFixed(1)} KiB/s`;
    }

    color: Colours.tPalette.m3surfaceContainer
    radius: Tokens.rounding.large
    implicitWidth: 860
    implicitHeight: header.implicitHeight + list.height + Tokens.padding.small * 2

    onVisibleChanged: {
        if (visible)
            refresh();
        else {
            monitorProc.running = false;
            retry.stop();
        }
    }

    Process {
        id: monitorProc

        command: ["python3", Quickshell.shellPath("scripts/caelestia-process-monitor.py")]

        stdout: SplitParser {
            onRead: line => {
                try {
                    root.processes = JSON.parse(line);
                    if (!root.processes.some(p => p.pid === root.selectedPid))
                        root.selectedPid = -1;
                } catch (e) {
                    console.warn("Process monitor returned invalid data", e);
                }
            }
        }

        onExited: exitCode => {
            if (root.visible && exitCode !== 0)
                retry.restart();
        }
    }

    Process {
        id: killProc
    }

    Timer {
        id: retry

        interval: 2000
        repeat: false
        onTriggered: root.refresh()
    }

    RowLayout {
        id: header

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Tokens.padding.small
        spacing: Tokens.spacing.extraSmall

        SortHeader { title: "% CPU"; sortKey: "cpu"; columnWidth: 64 }
        SortHeader { title: "% GPU"; sortKey: "gpu"; columnWidth: 64 }
        SortHeader { title: "% Disk"; sortKey: "disk"; columnWidth: 76 }
        SortHeader { title: "% MEM"; sortKey: "memory"; columnWidth: 68 }
        SortHeader { title: Tr.tr("Network"); sortKey: "network"; columnWidth: 94 }
        SortHeader { title: "PID"; sortKey: "pid"; columnWidth: 60 }
        SortHeader { title: Tr.tr("Name"); sortKey: "name"; columnWidth: 120 }
        SortHeader { title: Tr.tr("Command"); sortKey: "command"; fillWidth: true }
        Item { Layout.preferredWidth: 40 }
    }

    StyledListView {
        id: list

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: header.bottom
        anchors.leftMargin: Tokens.padding.small
        anchors.rightMargin: Tokens.padding.small
        anchors.topMargin: Tokens.padding.extraSmall
        clip: true
        model: root.sortedProcesses
        spacing: 2
        height: Math.min(contentHeight, root.maxListHeight)
        interactive: contentHeight > height

        delegate: Item {
            id: processRow

            required property var modelData
            readonly property bool selected: root.selectedPid === modelData.pid

            width: list.width
            height: 34

            StyledRect {
                anchors.fill: parent
                radius: Tokens.rounding.small
                color: processRow.selected ? Colours.palette.m3secondaryContainer : rowHover.hovered ? Colours.tPalette.m3surfaceContainerHigh : "transparent"
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Tokens.padding.small
                anchors.rightMargin: Tokens.padding.extraSmall
                spacing: Tokens.spacing.extraSmall

                Cell { text: `${Number(processRow.modelData.cpu).toFixed(1)}%`; columnWidth: 64 }
                Cell { text: processRow.modelData.gpu == null ? "—" : `${Number(processRow.modelData.gpu).toFixed(1)}%`; columnWidth: 64 }
                Cell { text: `${Number(processRow.modelData.disk).toFixed(1)}%`; columnWidth: 76 }
                Cell { text: `${Number(processRow.modelData.memory).toFixed(1)}%`; columnWidth: 68 }
                Cell { text: root.formatRate(Number(processRow.modelData.network)); columnWidth: 94 }
                Cell { text: String(processRow.modelData.pid); columnWidth: 60 }
                Cell { text: processRow.modelData.name; columnWidth: 120 }
                Cell { text: processRow.modelData.command; fillWidth: true }

                IconButton {
                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 30
                    icon: "close"
                    type: IconButton.Text
                    disabled: root.selectedPid !== processRow.modelData.pid || processRow.modelData.pid <= 1
                    onClicked: root.killSelected()
                }
            }

            TapHandler {
                onTapped: root.selectedPid = processRow.modelData.pid
            }

            HoverHandler {
                id: rowHover
            }
        }
    }

    component Cell: Item {
        property string text
        property bool fillWidth
        property real columnWidth

        Layout.preferredWidth: fillWidth ? 0 : columnWidth
        Layout.fillWidth: fillWidth
        implicitWidth: fillWidth ? 0 : columnWidth
        implicitHeight: 30

        StyledText {
            anchors.fill: parent
            anchors.leftMargin: Tokens.padding.extraSmall
            verticalAlignment: Text.AlignVCenter
            text: parent.text
            font: Tokens.font.body.small
            color: Colours.palette.m3onSurface
            elide: Text.ElideRight
        }
    }

    component SortHeader: ButtonBase {
        property string title
        property string sortKey
        property bool fillWidth
        property real columnWidth

        Layout.preferredWidth: fillWidth ? 0 : columnWidth
        Layout.fillWidth: fillWidth
        implicitWidth: fillWidth ? 0 : columnWidth
        implicitHeight: 30
        type: ButtonBase.Text
        onClicked: root.setSort(sortKey)

        StyledText {
            anchors.fill: parent
            anchors.leftMargin: Tokens.padding.extraSmall
            verticalAlignment: Text.AlignVCenter
            text: `${parent.title}${root.sortKey === parent.sortKey ? (root.sortDescending ? " ↓" : " ↑") : ""}`
            font: Tokens.font.body.builders.small.weight(Font.Medium).build()
            color: root.sortKey === parent.sortKey ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
            elide: Text.ElideRight
        }
    }
}
