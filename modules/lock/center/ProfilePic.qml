pragma ComponentBehavior: Bound

import QtQuick
import M3Shapes
import Caelestia.Config
import qs.components
import qs.components.effects
import qs.components.images
import qs.services
import qs.utils

Item {
    id: root

    required property int centerWidth
    readonly property color bgColour: Colours.tPalette.m3surfaceContainerHighest

    // The configured shape name (Config.lock.profileShape) mapped to MaterialShape's enum - keep
    // this mapping in sync with the picker's list in modules/nexus/pages/panels/ProfileShapePicker.qml,
    // and with the full enum use in modules/bar/components/workspaces/Workspace.qml. Falls back to the
    // original ClamShell for an empty/unknown name (e.g. a shape M3Shapes later drops)
    readonly property int shapeEnum: ({
            Arch: MaterialShape.Arch,
            Arrow: MaterialShape.Arrow,
            ClamShell: MaterialShape.ClamShell,
            Circle: MaterialShape.Circle,
            Clover4Leaf: MaterialShape.Clover4Leaf,
            Cookie: MaterialShape.Cookie,
            Cookie4Sided: MaterialShape.Cookie4Sided,
            Cookie6Sided: MaterialShape.Cookie6Sided,
            Cookie7Sided: MaterialShape.Cookie7Sided,
            Cookie9Sided: MaterialShape.Cookie9Sided,
            Cookie12Sided: MaterialShape.Cookie12Sided,
            Diamond: MaterialShape.Diamond,
            Fan: MaterialShape.Fan,
            Gem: MaterialShape.Gem,
            Ghostish: MaterialShape.Ghostish,
            Oval: MaterialShape.Oval,
            Pentagon: MaterialShape.Pentagon,
            Pill: MaterialShape.Pill,
            SemiCircle: MaterialShape.SemiCircle,
            Slanted: MaterialShape.Slanted,
            SoftBurst: MaterialShape.SoftBurst,
            Square: MaterialShape.Square,
            Sunny: MaterialShape.Sunny,
            Triangle: MaterialShape.Triangle,
            VerySunny: MaterialShape.VerySunny
        })[Config.lock.profileShape] ?? MaterialShape.ClamShell

    implicitWidth: Math.round(centerWidth * 0.7)
    implicitHeight: {
        shape.height; // Force update when shape height changes
        return shape.pathBounds().height;
    }

    MaterialShape {
        id: shape

        anchors.centerIn: parent
        implicitSize: root.implicitWidth

        shape: root.shapeEnum
        color: Qt.alpha(root.bgColour, 1)
        opacity: root.bgColour.a
        layer.enabled: true
    }

    MaterialIcon {
        anchors.centerIn: parent

        text: "person"
        color: Colours.palette.m3onSurfaceVariant
        fontStyle: Tokens.font.icon.size(root.centerWidth / 4).build()
        visible: pfp.status !== Image.Ready
    }

    CachingImage {
        id: pfp

        anchors.fill: shape
        path: `${Paths.home}/.face`

        layer.enabled: true
        layer.effect: Mask {
            maskSource: shape
        }
    }
}
