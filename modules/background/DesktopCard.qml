pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

// Translucent, optionally wallpaper-blurred card with an icon + title header
Item {
    id: root

    // What the card blurs to see through itself. Null in the Add-widget previews, which are not drawn
    // over the wallpaper and so turn `blur` off as well (see WidgetCard.qml)
    property Item wallpaper: null
    property string title
    property string icon
    property real plateOpacity: GlobalConfig.background.desktopWidgets.opacity
    // Blur, shadow and rounding follow the Power & battery settings as well as the widget's own
    property bool blur: wallpaper && GlobalConfig.background.desktopWidgets.blur && !GameMode.enabled && PowerSaving.blur
    property real radius: Tokens.rounding.extraLarge
    property real padding: Tokens.padding.largeIncreased
    default property alias content: col.data

    property point origin: Qt.point(0, 0)
    // Press and hold anywhere on the card that isn't something interactive. Sits under the card's
    // own content, so a hold on a button or a note still belongs to that, and off in the previews
    property bool holdEnabled

    // Emitted once the card has been held down; the desktop drops into rearrange mode on it.
    // Not `held`, which the desktop cards already use for "this is the card being dragged"
    signal longPressed

    function updateOrigin(): void {
        if (wallpaper)
            origin = mapToItem(wallpaper, 0, 0);
    }

    implicitWidth: 300
    implicitHeight: col.implicitHeight + padding * 2

    onXChanged: updateOrigin()
    onYChanged: updateOrigin()
    onWidthChanged: updateOrigin()
    onHeightChanged: updateOrigin()
    onParentChanged: updateOrigin()
    Component.onCompleted: updateOrigin()

    layer.enabled: PowerSaving.shadows
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: Colours.palette.m3shadow
        shadowOpacity: 0.35
        shadowBlur: 0.6
        shadowVerticalOffset: 4
    }

    Loader {
        anchors.fill: parent
        active: root.blur

        sourceComponent: MultiEffect {
            source: ShaderEffectSource {
                sourceItem: root.wallpaper
                sourceRect: Qt.rect(root.origin.x, root.origin.y, root.width, root.height)
            }
            maskSource: plate
            maskEnabled: true
            blurEnabled: true
            blur: 1
            blurMax: 64
            autoPaddingEnabled: false
        }
    }

    StyledRect {
        id: plate

        anchors.fill: parent
        radius: root.radius
        color: Colours.palette.m3surface
        opacity: root.plateOpacity
        layer.enabled: root.blur
    }

    // Soft tint + hairline so cards read against any wallpaper
    StyledRect {
        anchors.fill: parent
        radius: root.radius
        color: Qt.alpha(Colours.palette.m3primary, 0.04)
        border.width: 1
        border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.5)
    }

    // Declared before the content, so anything the card puts on top of it - a button, a note, a
    // checkbox - takes the press first and only the card's bare areas reach this
    MouseArea {
        anchors.fill: parent
        enabled: root.holdEnabled
        onPressAndHold: root.longPressed()
    }

    ColumnLayout {
        id: col

        anchors.fill: parent
        anchors.margins: root.padding
        spacing: Tokens.spacing.medium

        RowLayout {
            visible: root.title !== ""
            spacing: Tokens.spacing.small

            MaterialIcon {
                visible: root.icon !== ""
                text: root.icon
                color: Colours.palette.m3primary
                fontStyle: Tokens.font.icon.small
            }

            StyledText {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                elide: Text.ElideRight
                text: root.title.toUpperCase()
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.builders.small.letterSpacing(1.5).weight(Font.DemiBold).build()
            }
        }
    }
}
