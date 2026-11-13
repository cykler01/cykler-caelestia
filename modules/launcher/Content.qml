pragma ComponentBehavior: Bound

import QtQuick
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.launcher.services

Item {
    id: root

    required property ScreenState screenState
    required property var panels
    required property real maxHeight
    // Hanging from the top edge: the search bar goes first and the results list below it
    property bool flipped

    readonly property int padding: Tokens.padding.large
    readonly property int rounding: Tokens.rounding.extraLarge
    // Gap between the search bar and the screen edge it sits next to
    readonly property real edgeMargin: CUtils.clamp(padding - Config.border.thickness, 0, padding)

    implicitWidth: listWrapper.width + padding * 2
    implicitHeight: search.height + listWrapper.height + padding + edgeMargin

    Item {
        id: listWrapper

        implicitWidth: list.width
        implicitHeight: list.height + root.padding

        // Explicit positions rather than anchors so the launcher can change edge live
        x: (parent.width - width) / 2
        y: root.flipped ? search.y + search.height + root.padding : search.y - root.padding - height

        ContentList {
            id: list

            content: root
            screenState: root.screenState
            panels: root.panels
            maxHeight: root.maxHeight - search.implicitHeight - root.padding * 3
            search: search
            padding: root.padding
            rounding: root.rounding
        }
    }

    SearchBar {
        id: search

        // Opens straight into whichever mode asked for the launcher, rather than on the app list.
        // Taken here as well as on the signal because the launcher is only built once it opens, so
        // a request made to open it lands before there is anything to receive it
        function takeSearchRequest(): void {
            const request = root.screenState.launcherSearchRequest;
            if (!request)
                return;

            root.screenState.launcherSearchRequest = "";
            search.text = request;
            search.cursorPosition = search.text.length;
            search.forceActiveFocus();
        }

        objectName: "launcherSearch"

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: root.padding
        anchors.rightMargin: root.padding
        y: root.flipped ? root.edgeMargin : root.height - height - root.edgeMargin

        topPadding: Math.round((Tokens.padding.medium + Tokens.padding.large) / 2)
        bottomPadding: Math.round((Tokens.padding.medium + Tokens.padding.large) / 2)

        placeholderText: Tr.tr("Type \"%1\" for commands").arg(GlobalConfig.launcher.actionPrefix)

        onAccepted: {
            const currentItem = list.currentList?.currentItem;
            if (currentItem) {
                if (["spotlight", "settings", "files"].includes(list.currentList?.state)) {
                    // Every kind of unified result knows how to open itself
                    Spotlight.activate(currentItem.modelData, list.currentList);
                } else if (list.showWallpapers) {
                    if (Colours.scheme === "dynamic" && currentItem.modelData.path !== Wallpapers.actualCurrent)
                        Wallpapers.previewColourLock = true;
                    Wallpapers.setWallpaper(currentItem.modelData.path);
                    root.screenState.launcher = false;
                } else if (text.startsWith(GlobalConfig.launcher.actionPrefix)) {
                    if (text.startsWith(`${GlobalConfig.launcher.actionPrefix}calc `) || ["ai", "browser"].includes(list.currentList?.state))
                        currentItem.onClicked();
                    else
                        currentItem.modelData.onClicked(list.currentList);
                } else {
                    Apps.launch(currentItem.modelData);
                    root.screenState.launcher = false;
                }
            }
        }

        Keys.onUpPressed: list.currentList?.decrementCurrentIndex()
        Keys.onDownPressed: list.currentList?.incrementCurrentIndex()

        Keys.onEscapePressed: root.screenState.launcher = false

        Keys.onPressed: event => {
            // NOTE(fork): the wallpaper list is laid out horizontally, so plain left/right
            // browse it alongside up/down and the scroll wheel. This is handled through
            // onPressed rather than onLeftPressed/onRightPressed because the per-key
            // handlers always accept the event, which would swallow the caret movement the
            // search field needs whenever the app list is showing instead. Modified arrows
            // are left alone so shift selection and word-wise movement keep working.
            const arrowModifiers = Qt.ShiftModifier | Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier;
            const plainArrow = (event.key === Qt.Key_Left || event.key === Qt.Key_Right) && !(event.modifiers & arrowModifiers);

            if (list.showWallpapers && plainArrow) {
                if (event.key === Qt.Key_Left)
                    list.currentList?.decrementCurrentIndex();
                else
                    list.currentList?.incrementCurrentIndex();
                event.accepted = true;
                return;
            }

            if (!GlobalConfig.launcher.vimKeybinds)
                return;

            if (event.modifiers & Qt.ControlModifier) {
                if (event.key === Qt.Key_J || event.key === Qt.Key_N) {
                    list.currentList?.incrementCurrentIndex();
                    event.accepted = true;
                } else if (event.key === Qt.Key_K || event.key === Qt.Key_P) {
                    list.currentList?.decrementCurrentIndex();
                    event.accepted = true;
                }
            } else if (event.key === Qt.Key_Tab) {
                list.currentList?.incrementCurrentIndex();
                event.accepted = true;
            } else if (event.key === Qt.Key_Backtab || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
                list.currentList?.decrementCurrentIndex();
                event.accepted = true;
            }
        }

        Component.onCompleted: {
            forceActiveFocus();
            search.takeSearchRequest();
        }

        Connections {
            function onLauncherSearchRequestChanged(): void {
                search.takeSearchRequest();
            }

            function onLauncherChanged(): void {
                if (!root.screenState.launcher)
                    search.text = "";
            }

            function onSessionChanged(): void {
                if (!root.screenState.session)
                    search.forceActiveFocus();
            }

            target: root.screenState
        }
    }
}
