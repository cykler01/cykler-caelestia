import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.modules.launcher.services

Item {
    id: root

    required property var list
    readonly property string query: list.search.text.slice(`${GlobalConfig.launcher.actionPrefix}b `.length).trim()
    readonly property string url: Browser.urlFor(root.query)
    readonly property bool address: Browser.isAddress(root.query)

    function onClicked(): void {
        if (!root.url)
            return;

        Browser.open(root.url);
        root.list.screenState.launcher = false;
    }

    implicitHeight: Tokens.sizes.launcher.itemHeight

    anchors.left: parent?.left
    anchors.right: parent?.right

    StateLayer {
        radius: Tokens.rounding.large
        onClicked: root.onClicked()
    }

    RowLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: Tokens.padding.medium

        spacing: Tokens.spacing.medium

        MaterialIcon {
            text: "public"
            fontStyle: Tokens.font.icon.extraLarge
            Layout.alignment: Qt.AlignVCenter
        }

        // The address it will actually open, so a bare host or a search is visible before Enter
        StyledText {
            color: root.url ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant
            text: root.url || Tr.trCtx("Type a link or search term", "launcher browser hint")
            elide: Text.ElideMiddle
            font: Tokens.font.body.medium

            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
        }

        StyledRect {
            visible: !!root.url

            color: Colours.palette.m3tertiary
            radius: Tokens.rounding.large
            clip: true

            implicitWidth: (stateLayer.containsMouse ? label.implicitWidth + label.anchors.rightMargin : 0) + icon.implicitWidth + Tokens.padding.medium * 2
            implicitHeight: Math.max(label.implicitHeight, icon.implicitHeight) + Tokens.padding.small

            Layout.alignment: Qt.AlignVCenter

            StateLayer {
                id: stateLayer

                onClicked: root.onClicked()

                color: Colours.palette.m3onTertiary
            }

            StyledText {
                id: label

                anchors.verticalCenter: parent.verticalCenter
                anchors.right: icon.left
                anchors.rightMargin: Tokens.spacing.small

                text: root.address ? Tr.tr("Open in new tab") : Tr.tr("Search the web")
                color: Colours.palette.m3onTertiary
                font: Tokens.font.label.medium

                opacity: stateLayer.containsMouse ? 1 : 0

                Behavior on opacity {
                    Anim {
                        type: Anim.DefaultEffects
                    }
                }
            }

            MaterialIcon {
                id: icon

                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: Tokens.padding.medium

                text: "open_in_new"
                color: Colours.palette.m3onTertiary
                fontStyle: Tokens.font.icon.large
            }

            Behavior on implicitWidth {
                Anim {
                    type: Anim.Emphasized
                }
            }
        }
    }
}
