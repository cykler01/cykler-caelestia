import QtQuick
import Quickshell
import Quickshell.Bluetooth
import qs.services

QtObject {
    id: state

    property ShellScreen screen
    property bool isWindow
    property bool animatingContainer
    property int currentPageIdx
    property list<int> subPageIdxStack
    property bool searchOpen
    // The text in the search field, so NavLocations can filter by it
    property string searchQuery

    // The setting a search result asked for: the page whose title owns it, the row's
    // own label and the section header above it. PageBase picks these up as it loads,
    // scrolls the row into view and flashes it, then clears them.
    property string highlightTitle
    property string highlightLabel
    property string highlightSection

    // The settings search result currently open, by its key, so it stays marked as the
    // one you are on in the result list the way the page list marks the current page.
    // Cleared by picking a page, which is the other way out of a result.
    property string activeSetting

    property string selectedWallpaperCategory
    property BluetoothDevice selectedBtDevice
    property DesktopEntry selectedApp
    property int editingVpnIndex: -1
    property string selectedNetworkSsid
    property string selectedEthernetInterface
    property var selectedMonitor
    property bool networkDetailsFromSaved

    property Connections monitorsConnection: Connections {
        function onMonitorsChanged(): void {
            if (state.selectedMonitor) {
                for (let i = 0; i < Hyprctl.monitors.length; i++) {
                    if (Hyprctl.monitors[i].name === state.selectedMonitor.name) {
                        state.selectedMonitor = Hyprctl.monitors[i];
                        return;
                    }
                }
                state.selectedMonitor = null;
            }
        }

        target: Hyprctl
    }

    signal close
    signal subPageOpened(idx: int)
    signal subPageClosed
    // Rebuild the current page in place, for when a search result lands on a different
    // sub-page of the page already open and currentPageIdx therefore never changes
    signal reloadPage
    // The page is already the right one, so nothing reloads and it has to be told to
    // look for the highlight itself
    signal highlightRequested

    function clearHighlight(): void {
        highlightTitle = "";
        highlightLabel = "";
        highlightSection = "";
    }

    // Opens the page and sub-page a settings search result points at, and asks for the
    // row itself to be highlighted once it is there
    function openSetting(entry: var): void {
        const path = entry.path ?? [];

        highlightTitle = entry.title ?? "";
        highlightLabel = entry.label ?? "";
        highlightSection = entry.section ?? "";

        if (currentPageIdx !== entry.pageIdx) {
            // Changing the page empties the stack and drops the open result, so both
            // go on after it rather than before
            currentPageIdx = entry.pageIdx;
            subPageIdxStack = path;
            activeSetting = entry.key ?? "";
            return;
        }

        activeSetting = entry.key ?? "";

        if (subPageIdxStack.length === path.length && path.every((idx, i) => subPageIdxStack[i] === idx)) {
            highlightRequested();
            return;
        }

        subPageIdxStack = path;
        reloadPage();
    }

    function openSubPage(idx: int): void {
        subPageIdxStack.push(idx);
        subPageOpened(idx);
    }

    function closeSubPage(): void {
        subPageClosed();
        subPageIdxStack.pop();
    }

    onCurrentPageIdxChanged: {
        subPageIdxStack.length = 0;
        activeSetting = "";
    }
}
