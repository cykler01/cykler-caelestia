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

    required property Item wallpaper
    property string title
    property string icon
    property real plateOpacity: Config.background.desktopWidgets.opacity
    // Blur, shadow and rounding follow the Power & battery settings as well as the widget's own
    property bool blur: Config.background.desktopWidgets.blur && !GameMode.enabled && PowerSaving.blur
    property real radius: Tokens.rounding.extraLarge
    property real padding: Tokens.padding.largeIncreased
    default property alias content: col.data

    property point origin: Qt.point(0, 0)

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
