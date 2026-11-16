pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.utils
import qs.modules.background
import qs.modules.launcher.services as LauncherServices

// --- Quick launch: the launcher's favourite apps as a grid of icons, or a single row of them ---
WidgetCard {
    id: shortcuts

    readonly property bool row: shortcuts.variant === "row"

    // Everything the launcher would show: hidden apps stay hidden here too. In name order, since the
    // desktop entries themselves come back in no particular one and the card should not reshuffle
    readonly property var installed: DesktopEntries.applications.values.filter(a => !Strings.testRegexList(GlobalConfig.launcher.hiddenApps, a.id)).sort((a, b) => a.name.localeCompare(b.name))

    // The favourites, matched the way the launcher matches them (plain ids or ^...$ patterns)
    readonly property var favourites: shortcuts.installed.filter(a => Strings.testRegexList(GlobalConfig.launcher.favouriteApps, a.id))

    // With no favourites set the card still has something to offer: the apps launched most from the
    // launcher, which keeps that count, and failing a history, the first app for each of the kinds of thing
    // most people reach for, by the categories the apps declare for themselves
    readonly property var fallback: {
        const out = LauncherServices.Apps.list.filter(a => a.frequency > 0).slice(0, 9).map(a => a.entry).filter(e => shortcuts.installed.includes(e));
        if (out.length >= 3)
            return out;

        const wanted = ["WebBrowser", "TerminalEmulator", "FileManager", "TextEditor", "Music", "Email", "Office", "Graphics", "Settings"];
        for (const category of wanted) {
            const app = shortcuts.installed.find(a => (a.categories ?? []).includes(category) && !out.includes(a));
            if (app)
                out.push(app);
        }
        return out;
    }

    readonly property var apps: shortcuts.favourites.length > 0 ? shortcuts.favourites : shortcuts.fallback

    // The row fits as many squares as the width allows; the grid is three by three
    readonly property real tile: 48
    readonly property int rowCount: Math.max(1, Math.floor((shortcuts.width - shortcuts.padding * 2 + Tokens.spacing.small) / (shortcuts.tile + Tokens.spacing.small)))
    readonly property var shown: shortcuts.apps.slice(0, shortcuts.row ? shortcuts.rowCount : 9)

    // The app under the pointer in the grid, named in the card's title while it is there: the tiles are
    // too narrow to put names under the icons without cutting every one of them short
    property string hoveredName

    function launch(entry: var): void {
        // A preview is for looking at: a click in the Add-widget grid should not start anything
        if (shortcuts.preview || !entry)
            return;

        LauncherServices.Apps.launch(entry);
    }

    title: shortcuts.row ? "" : shortcuts.hoveredName || Tr.tr("Quick launch")
    icon: shortcuts.row ? "" : "apps"
    padding: shortcuts.row ? Tokens.padding.medium : Tokens.padding.largeIncreased

    StyledText {
        Layout.fillWidth: true
        visible: shortcuts.apps.length === 0
        wrapMode: Text.Wrap
        text: Tr.tr("Pin apps in the launcher to see them here")
        color: Colours.palette.m3outline
        font: Tokens.font.label.medium
    }

    // Grid: three to a row on soft tiles, the rows sharing the card's height
    GridLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: !shortcuts.row && shortcuts.apps.length > 0
        columns: 3
        rowSpacing: Tokens.spacing.small
        columnSpacing: Tokens.spacing.small

        Repeater {
            model: shortcuts.row ? [] : shortcuts.shown

            StyledRect {
                id: gridTile

                required property var modelData

                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                Layout.preferredHeight: 1
                radius: Tokens.rounding.large
                color: Qt.alpha(Colours.palette.m3surfaceContainerHighest, 0.6)

                StateLayer {
                    id: gridLayer

                    radius: Tokens.rounding.large
                    color: Colours.palette.m3onSurface
                    disabled: shortcuts.preview
                    onClicked: shortcuts.launch(gridTile.modelData)
                    onContainsMouseChanged: {
                        if (containsMouse)
                            shortcuts.hoveredName = gridTile.modelData.name;
                        else if (shortcuts.hoveredName === gridTile.modelData.name)
                            shortcuts.hoveredName = "";
                    }
                }

                IconImage {
                    anchors.centerIn: parent
                    asynchronous: true
                    implicitSize: Math.min(44, Math.min(parent.width, parent.height) - Tokens.padding.small * 2)
                    source: Quickshell.iconPath(gridTile.modelData.icon, "image-missing")
                    scale: gridLayer.containsMouse && PowerSaving.animations ? 1.08 : 1

                    Behavior on scale {
                        Anim {
                            type: Anim.FastEffects
                        }
                    }
                }
            }
        }
    }

    // Row: icons alone, spread evenly across the strip, as many as fit
    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: shortcuts.row && shortcuts.apps.length > 0
        spacing: Tokens.spacing.small

        Repeater {
            model: shortcuts.row ? shortcuts.shown : []

            Item {
                id: rowTile

                required property var modelData

                Layout.fillWidth: true
                Layout.fillHeight: true

                StateLayer {
                    id: rowLayer

                    anchors.fill: undefined
                    anchors.centerIn: parent
                    width: Math.min(parent.width, parent.height)
                    height: width
                    radius: Tokens.rounding.large
                    color: Colours.palette.m3onSurface
                    disabled: shortcuts.preview
                    onClicked: shortcuts.launch(rowTile.modelData)
                }

                IconImage {
                    anchors.centerIn: parent
                    asynchronous: true
                    implicitSize: 36
                    source: Quickshell.iconPath(rowTile.modelData.icon, "image-missing")
                    scale: rowLayer.containsMouse && PowerSaving.animations ? 1.08 : 1

                    Behavior on scale {
                        Anim {
                            type: Anim.FastEffects
                        }
                    }
                }
            }
        }
    }
}
