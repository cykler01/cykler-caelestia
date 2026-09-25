pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.images
import qs.services
import qs.modules.launcher.services

// Column(s) of app shortcuts on the desktop, populated from background.desktopIcons.apps
Flow {
    id: root

    readonly property int iconSize: Config.background.desktopIcons.iconSize
    readonly property bool showLabels: Config.background.desktopIcons.showLabels
    readonly property var entries: Config.background.desktopIcons.apps
        .map(id => DesktopEntries.byId(id) ?? DesktopEntries.heuristicLookup(id))
        .filter(e => !!e)

    flow: Flow.TopToBottom
    spacing: Tokens.spacing.large

    Repeater {
        model: root.entries

        StyledRect {
            id: tile

            required property DesktopEntry modelData

            implicitWidth: Math.max(root.iconSize, root.showLabels ? 80 : 0) + Tokens.padding.medium * 2
            implicitHeight: col.implicitHeight + Tokens.padding.medium * 2
            radius: Tokens.rounding.medium
            color: hover.containsMouse ? Qt.alpha(Colours.palette.m3surface, 0.5) : "transparent"

            Column {
                id: col

                anchors.centerIn: parent
                spacing: Tokens.spacing.small

                CachingIconImage {
                    anchors.horizontalCenter: parent.horizontalCenter
                    implicitSize: root.iconSize
                    source: Quickshell.iconPath(tile.modelData.icon, "image-missing")
                }

                StyledText {
                    visible: root.showLabels
                    width: Math.max(root.iconSize, 80)
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.Wrap
                    text: tile.modelData.name
                    color: Colours.palette.m3onSurface
                    font: Tokens.font.label.medium
                    style: Text.Outline
                    styleColor: Qt.alpha(Colours.palette.m3shadow, 0.6)
                }
            }

            MouseArea {
                id: hover

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Apps.launch(tile.modelData)
            }
        }
    }
}
