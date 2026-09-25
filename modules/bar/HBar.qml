pragma ComponentBehavior: Bound

import "popouts" as BarPopouts
import "components"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.services

// Horizontal bar used when attached to the top or bottom screen edge
RowLayout {
    id: root

    required property ShellScreen screen
    required property ScreenState screenState
    required property BarPopouts.Wrapper popouts
    required property bool fullscreen
    readonly property int hPadding: Tokens.padding.large
    // The notch shows the time and date on an empty workspace, so the bar's clock steps aside
    readonly property bool clockHidden: ShellState.componentsFor(screen)?.panels?.notch?.showsClock ?? false

    // Centre of an item along the bar (x), in bar coordinates
    function centerOf(item: Item): real {
        return item ? item.mapToItem(root, item.width / 2, 0).x : 0;
    }

    // Extent of the empty stretch between the first and last spacer, so the drawers can cut it out of the
    // frame on an empty workspace (x coordinates along the bar)
    property real middleStart
    property real middleEnd
    readonly property bool hasMiddle: middleEnd > middleStart

    function updateMiddle(): void {
        let first = null;
        let last = null;
        for (let i = 0; i < repeater.count; i++) {
            const w = repeater.itemAt(i) as EntryWrapper;
            if (w?.entryId === "spacer") {
                if (!first)
                    first = w;
                last = w;
            }
        }
        middleStart = first ? first.x : 0;
        middleEnd = last ? last.x + last.width : 0;
    }

    Timer {
        id: middleTimer

        interval: 0
        onTriggered: root.updateMiddle()
    }

    function closeTray(): void {
        if (!Config.bar.tray.compact)
            return;

        for (let i = 0; i < repeater.count; i++) {
            const tray = (repeater.itemAt(i) as EntryWrapper)?.item as HTray;
            if (tray)
                tray.expanded = false;
        }
    }

    // x is the coordinate along the bar
    function checkPopout(x: real): void {
        const ch = childAt(x, height / 2) as EntryWrapper;

        if (!ch) {
            popouts.hasCurrent = false;
            return;
        }

        if (ch.entryId !== "tray")
            closeTray();

        const id = ch.entryId;

        if (id === "statusIcons" && Config.bar.popouts.statusIcons) {
            const items = (ch.item as Item).items;
            const local = mapToItem(items, x, 0);
            const icon = items.childAt(local.x, items.height / 2);
            if (icon) {
                popouts.currentName = icon.name;
                popouts.currentCenter = Qt.binding(() => root.centerOf(icon));
                popouts.hasCurrent = true;
            } else {
                popouts.hasCurrent = false;
            }
        } else if (id === "tray" && Config.bar.popouts.tray) {
            const tray = ch.item as HTray;
            // Compact tray: hovering the collapsed chevron (or its own chevron while expanded) toggles it open
            if (Config.bar.tray.compact && !(tray.expanded && !tray.expandIcon.contains(mapToItem(tray.expandIcon, x, tray.height / 2)))) {
                popouts.hasCurrent = false;
                tray.expanded = true;
                return;
            }

            let found = null;
            let foundIdx = -1;
            for (let i = 0; i < tray.items.count; i++) {
                const it = tray.items.itemAt(i);
                if (!it)
                    continue;
                const left = it.mapToItem(root, 0, 0).x;
                if (x >= left && x < left + it.width) {
                    found = it;
                    foundIdx = i;
                    break;
                }
            }
            if (found) {
                popouts.currentName = `traymenu${foundIdx}`;
                popouts.currentCenter = Qt.binding(() => root.centerOf(found));
                popouts.hasCurrent = true;
            } else {
                popouts.hasCurrent = false;
            }
        } else {
            popouts.hasCurrent = false;
        }
    }

    function handleWheel(x: real, angleDelta: point): void {
        const ch = childAt(x, height / 2) as EntryWrapper;
        if (ch?.entryId === "workspaces" && Config.bar.scrollActions.workspaces) {
            const mon = Hypr.monitorFor(screen);
            if (angleDelta.y < 0 || mon.activeWorkspace?.id > 1)
                Hypr.dispatch(Hypr.usingLua ? `hl.dsp.focus({ workspace = "r${angleDelta.y > 0 ? "-" : "+"}1" })` : `workspace r${angleDelta.y > 0 ? "-" : "+"}1`);
        } else if (x < screen.width / 2 && Config.bar.scrollActions.volume) {
            // Volume scroll on the left half
            if (angleDelta.y > 0)
                Audio.incrementVolume();
            else if (angleDelta.y < 0)
                Audio.decrementVolume();
        } else if (Config.bar.scrollActions.brightness) {
            // Brightness scroll on the right half
            const monitor = Brightness.getMonitorForScreen(screen);
            if (angleDelta.y > 0)
                monitor.setBrightness(monitor.brightness + GlobalConfig.services.brightnessIncrement);
            else if (angleDelta.y < 0)
                monitor.setBrightness(monitor.brightness - GlobalConfig.services.brightnessIncrement);
        }
    }

    spacing: Tokens.spacing.medium

    Repeater {
        id: repeater

        model: ScriptModel {
            values: root.Config.bar.entries.values.filter(e => e.enabled && e.id !== "activeWindow")
        }

        DelegateChooser {
            role: "id"

            DelegateChoice {
                roleValue: "spacer"
                delegate: EntryWrapper {
                    Layout.fillWidth: true
                }
            }
            DelegateChoice {
                roleValue: "logo"
                delegate: EntryWrapper {
                    OsIcon {
                        objectName: "taskbarLogo"
                    }
                }
            }
            DelegateChoice {
                roleValue: "workspaces"
                delegate: EntryWrapper {
                    HWorkspaces {
                        objectName: "taskbarWorkspaces"
                        screen: root.screen
                        fullscreen: root.fullscreen
                    }
                }
            }
            DelegateChoice {
                roleValue: "tray"
                delegate: EntryWrapper {
                    HTray {
                        objectName: "taskbarTray"
                    }
                }
            }
            DelegateChoice {
                roleValue: "clock"
                delegate: EntryWrapper {
                    visible: !root.clockHidden
                    HClock {
                        objectName: "taskbarClock"
                    }
                }
            }
            DelegateChoice {
                roleValue: "statusIcons"
                delegate: EntryWrapper {
                    HStatusIcons {
                        objectName: "taskbarStatusIcons"
                    }
                }
            }
            DelegateChoice {
                roleValue: "power"
                delegate: EntryWrapper {
                    Power {
                        objectName: "taskbarPowerButton"
                        screenState: root.screenState
                    }
                }
            }
        }
    }

    component EntryWrapper: Item {
        required property var modelData
        required property int index
        default property Item item
        readonly property string entryId: modelData.id

        Layout.leftMargin: index === 0 ? root.hPadding : 0
        Layout.rightMargin: index === repeater.count - 1 ? root.hPadding : 0
        Layout.alignment: Qt.AlignVCenter

        implicitWidth: item?.implicitWidth ?? 0
        implicitHeight: item?.implicitHeight ?? 0

        onXChanged: middleTimer.restart()
        onWidthChanged: middleTimer.restart()
        Component.onCompleted: middleTimer.restart()

        children: item
    }
}
