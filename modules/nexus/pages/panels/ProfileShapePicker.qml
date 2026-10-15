pragma ComponentBehavior: Bound

import QtQuick
import M3Shapes
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.effects
import qs.components.images
import qs.services
import qs.utils
import qs.modules.nexus.common

// Picker for the shape of the lock screen profile picture (modules/lock/center/ProfilePic.qml):
// a dialog over a full-width row, with a grid previewing every available shape - each rendered
// like the profile picture itself (the user's avatar clipped to the shape), instead of a bare
// text dropdown with no way to tell what any option looks like.
DialogRowButton {
    id: root

    readonly property list<string> shapes: [
        "Arch",
        "Arrow",
        "ClamShell",
        "Circle",
        "Clover4Leaf",
        "Cookie",
        "Cookie4Sided",
        "Cookie6Sided",
        "Cookie7Sided",
        "Cookie9Sided",
        "Cookie12Sided",
        "Diamond",
        "Fan",
        "Gem",
        "Ghostish",
        "Oval",
        "Pentagon",
        "Pill",
        "SemiCircle",
        "Slanted",
        "SoftBurst",
        "Square",
        "Sunny",
        "Triangle",
        "VerySunny"
    ]

    // Name -> M3Shapes enum, kept here for the previews - keep in sync with the same mapping in
    // modules/lock/center/ProfilePic.qml
    readonly property var shapeEnums: ({
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
        })

    // The shape actually configured on the lock screen, shown in the row
    readonly property string settingsShape: GlobalConfig.lock.profileShape
    // The shape picked in the grid, only applied by "Apply" so the dialog can be dismissed
    property string selection

    readonly property real previewSize: 52
    readonly property real cellHeight: 88

    function enumFor(shape: string): int {
        return root.shapeEnums[shape] ?? MaterialShape.ClamShell;
    }

    icon: "person"
    label: `${Tr.tr("Shape")} · ${root.settingsShape}`
    header: Tr.tr("Profile picture shape")
    acceptLabel: Tr.tr("Apply")
    // Nothing is configured yet only if the saved shape is not one this picker knows
    acceptAllowed: root.shapeEnums[root.selection] !== undefined
    separateContent: true
    horizontalContentMargin: -Tokens.padding.small

    onAccepted: GlobalConfig.lock.profileShape = root.selection
    // Pick up where the setting is whenever the dialog opens, so cancelling drops any changes
    onOpenChanged: {
        if (open)
            root.selection = root.settingsShape;
    }

    content: Component {
        GridView {
            id: grid

            // Columns wrap at a reasonable cell width, so narrower dialogs fit fewer per row
            property int columns: Math.max(2, Math.ceil(width / 90))

            clip: true
            boundsBehavior: Flickable.StopAtBounds
            cellWidth: width / columns
            cellHeight: root.cellHeight
            keyNavigationWraps: true

            model: root.shapes

            delegate: Item {
                id: cell

                required property var modelData
                readonly property bool selected: root.selection === cell.modelData

                width: grid.cellWidth
                height: grid.cellHeight

                StyledRect {
                    anchors.fill: parent
                    anchors.margins: Tokens.spacing.extraSmall
                    radius: cell.selected ? Tokens.rounding.largeIncreased : Tokens.rounding.medium
                    color: Qt.alpha(Colours.palette.m3tertiaryContainer, cell.selected ? 1 : 0)

                    Behavior on radius {
                        Anim {
                            type: Anim.SlowEffects
                        }
                    }

                    StateLayer {
                        topLeftRadius: parent.radius
                        topRightRadius: parent.radius
                        bottomLeftRadius: parent.radius
                        bottomRightRadius: parent.radius
                        onClicked: root.selection = cell.modelData
                    }

                    MaterialIcon {
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Tokens.spacing.small
                        text: "check"
                        color: Colours.palette.m3onTertiaryContainer
                        opacity: cell.selected ? 1 : 0

                        Behavior on opacity {
                            Anim {
                                type: Anim.DefaultEffects
                            }
                        }
                    }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: Tokens.spacing.extraSmall

                    // The avatar clipped to the shape the same way ProfilePic.qml draws it, with
                    // the placeholder icon when there is no avatar image
                    Item {
                        implicitWidth: root.previewSize
                        implicitHeight: root.previewSize

                        MaterialShape {
                            id: previewShape

                            anchors.centerIn: parent
                            implicitSize: root.previewSize
                            shape: root.enumFor(cell.modelData)
                            color: Colours.palette.m3secondaryContainer
                        }

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: "person"
                            color: Colours.palette.m3onSecondaryContainer
                            fontStyle: Tokens.font.icon.size(root.previewSize / 3).build()
                            visible: pfpImage.status !== Image.Ready
                        }

                        CachingImage {
                            id: pfpImage

                            anchors.fill: previewShape
                            path: `${Paths.home}/.face`

                            layer.enabled: true
                            layer.effect: Mask {
                                maskSource: previewShape
                            }
                        }
                    }

                    StyledText {
                        width: root.previewSize
                        horizontalAlignment: Text.AlignHCenter
                        text: cell.modelData
                        color: cell.selected ? Colours.palette.m3onTertiaryContainer : Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.label.small
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}
