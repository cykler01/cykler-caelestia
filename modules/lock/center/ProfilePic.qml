pragma ComponentBehavior: Bound

import QtQuick
import M3Shapes
import Caelestia
import Caelestia.Config
import Caelestia.Multimedia
import qs.components
import qs.components.effects
import qs.services
import qs.utils
import qs.modules.lock

Item {
    id: root

    required property int centerWidth
    // The lock's Pam instance, used to show face auth state around the picture. Null in previews
    property var pam: null
    readonly property bool scanning: pam?.face.active ?? false
    readonly property bool faceFailed: !scanning && (pam?.face.state === Pam.Failed || pam?.face.state === Pam.Error)
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
        CUtils.dependency(shape.height); // Force update when shape height changes
        return shape.pathBounds().height;
    }

    // Pulsing ring while face auth is scanning, held red for a few seconds after a failed attempt
    MaterialShape {
        id: ring

        // 0 -> 1 over each pulse while scanning
        property real pulse: 0

        anchors.centerIn: parent
        implicitSize: root.implicitWidth

        shape: root.shapeEnum
        color: root.faceFailed ? Colours.palette.m3error : Colours.palette.m3primary
        // Ring thickness in px: proportional on big avatars, but never thinner than a few px on small ones
        readonly property real failedGrow: 2 * Math.max(root.implicitWidth * 0.06, 5) / root.implicitWidth
        readonly property real pulseGrow: 2 * Math.max(root.implicitWidth * 0.12, 12) / root.implicitWidth

        opacity: root.faceFailed ? 0.7 : root.scanning ? 0.8 * (1 - pulse) : 0
        scale: root.faceFailed ? 1 + failedGrow : 1 + pulseGrow * (root.scanning ? pulse : 0)
        visible: opacity > 0

        NumberAnimation on pulse {
            running: root.scanning
            loops: Animation.Infinite
            from: 0
            to: 1
            duration: 900
            easing.type: Easing.OutCubic
        }
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
        visible: !pfp.ready
    }

    Visual {
        id: pfp

        anchors.fill: shape
        source: `${Paths.home}/.face`

        layer.enabled: true
        layer.effect: Mask {
            maskSource: shape
        }
    }
}
