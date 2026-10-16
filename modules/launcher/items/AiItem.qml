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
    readonly property string query: list.search.text.slice(`${GlobalConfig.launcher.actionPrefix}ai `.length).trim()

    function onClicked(): void {
        if (!Ai.answer || Ai.errorText)
            return;

        Quickshell.execDetached(["wl-copy", Ai.answer]);
        root.list.screenState.launcher = false;
    }

    onQueryChanged: Ai.setQuery(root.query)

    // Grows past the normal row height so a multi-line answer fits whole; the
    // launcher clamps it to the available space and the list scrolls from there
    implicitHeight: Math.max(Tokens.sizes.launcher.itemHeight, rowLayout.implicitHeight + Tokens.padding.medium * 2)

    anchors.left: parent?.left
    anchors.right: parent?.right

    StateLayer {
        radius: Tokens.rounding.large
        onClicked: root.onClicked()
    }

    RowLayout {
        id: rowLayout

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: Tokens.padding.medium

        spacing: Tokens.spacing.medium

        MaterialIcon {
            text: "auto_awesome"
            fontStyle: Tokens.font.icon.extraLarge
            opacity: root.list.search.activeFocus || !Ai.busy ? 1 : 0.6

            Layout.alignment: Qt.AlignVCenter
        }

        StyledText {
            color: {
                if (Ai.errorText)
                    return Colours.palette.m3error;
                if (!root.query)
                    return Colours.palette.m3onSurfaceVariant;
                return Colours.palette.m3onSurface;
            }

            text: Ai.errorText ? Ai.errorText : !root.query ? Tr.trCtx("Type a question to ask the AI", "launcher AI search hint") : Ai.busy ? Tr.tr("Thinking...") : Ai.answer ? Ai.answer : ""
            wrapMode: Text.Wrap
            font: Tokens.font.body.medium

            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
        }

        StyledRect {
            visible: !Ai.errorText && !!Ai.answer
            color: Colours.palette.m3tertiary
            radius: Tokens.rounding.large

            implicitWidth: label.implicitWidth + Tokens.padding.medium * 2
            implicitHeight: label.implicitHeight + Tokens.padding.small * 2

            Layout.alignment: Qt.AlignVCenter

            StateLayer {
                onClicked: root.onClicked()

                color: Colours.palette.m3onTertiary
            }

            StyledText {
                id: label

                anchors.centerIn: parent

                text: Tr.tr("Copy answer")
                color: Colours.palette.m3onTertiary
                font: Tokens.font.label.medium
            }
        }
    }
}
