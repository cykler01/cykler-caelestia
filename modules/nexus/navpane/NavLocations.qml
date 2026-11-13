pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.containers
import qs.services
import qs.modules.nexus

VerticalFadeFlickable {
    id: root

    required property NexusState nState

    readonly property string query: root.nState.searchOpen ? root.nState.searchQuery : ""

    // The pages themselves. With nothing typed this is the whole sidebar, in its usual
    // order; with a query it is the pages whose own name or description matches, ranked.
    readonly property var pages: {
        if (root.query === "")
            return PageRegistry.pages.map((page, idx) => Object.assign({}, page, {
                        pageIdx: idx
                    }));
        return SettingsSearch.queryPages(root.query);
    }

    // The individual toggles, sliders and pickers inside those pages. Searching only
    // page names meant knowing which page a setting was filed under before it could be
    // found, which for something like "drag threshold" - on four different panels - is
    // most of the work.
    readonly property var settings: root.query === "" ? [] : SettingsSearch.querySettings(root.query)

    readonly property bool empty: root.pages.length === 0 && root.settings.length === 0

    topMargin: Tokens.padding.large
    bottomMargin: Tokens.padding.large
    contentHeight: root.empty ? emptyText.implicitHeight : content.implicitHeight

    TapHandler {
        onTapped: root.focus = true
    }

    StyledText {
        id: emptyText

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Tokens.padding.extraLarge
        visible: root.empty
        text: Tr.tr("No settings match your search")
        color: Colours.palette.m3onSurfaceVariant
    }

    ColumnLayout {
        id: content

        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Tokens.spacing.extraSmall

        GroupHeader {
            visible: root.settings.length > 0 && root.pages.length > 0
            text: Tr.tr("Pages")
        }

        Repeater {
            id: list

            model: root.pages

            StyledRect {
                id: item

                required property var modelData
                required property int index

                readonly property bool isCurrentPage: modelData.pageIdx === root.nState.currentPageIdx
                readonly property bool isCategoryStart: index === 0 || root.pages[index - 1]?.category !== modelData.category
                readonly property bool isCategoryEnd: index === list.model.length - 1 || root.pages[index + 1]?.category !== modelData.category
                // The neighbour directly above/below the selected item (within the same
                // group) curves inward on the side touching it, so the selection looks
                // like it's nestled into the list rather than just overlaid on top
                readonly property bool touchesSelectedAbove: !isCategoryStart && root.pages[index - 1]?.pageIdx === root.nState.currentPageIdx
                readonly property bool touchesSelectedBelow: !isCategoryEnd && root.pages[index + 1]?.pageIdx === root.nState.currentPageIdx

                Layout.fillWidth: true
                // The selected item pushes its neighbours away a little, so it reads as
                // popping out of the list rather than just being tinted a different colour
                Layout.topMargin: (index !== 0 && isCategoryStart ? Tokens.spacing.medium : 0) + (isCurrentPage ? Tokens.spacing.small : 0)
                Layout.bottomMargin: isCurrentPage ? Tokens.spacing.small : 0
                implicitHeight: {
                    const h = layout.implicitHeight + layout.anchors.margins * 2;
                    return h % 2 === 0 ? h : h + 1;
                }

                Behavior on Layout.topMargin {
                    Anim {
                        type: Anim.DefaultEffects
                    }
                }

                Behavior on Layout.bottomMargin {
                    Anim {
                        type: Anim.DefaultEffects
                    }
                }

                color: isCurrentPage ? Colours.palette.m3secondaryContainer : Colours.layer(Colours.palette.m3surfaceContainerHigh, 2)

                topLeftRadius: stateLayer.pressed ? Tokens.rounding.medium : isCurrentPage ? Tokens.rounding.extraLargeIncreased : isCategoryStart || touchesSelectedAbove ? Tokens.rounding.extraLarge : Tokens.rounding.extraSmall

                topRightRadius: stateLayer.pressed ? Tokens.rounding.medium : isCurrentPage ? Tokens.rounding.extraLargeIncreased : isCategoryStart || touchesSelectedAbove ? Tokens.rounding.extraLarge : Tokens.rounding.extraSmall

                bottomLeftRadius: stateLayer.pressed ? Tokens.rounding.medium : isCurrentPage ? Tokens.rounding.extraLargeIncreased : isCategoryEnd || touchesSelectedBelow ? Tokens.rounding.extraLarge : Tokens.rounding.extraSmall

                bottomRightRadius: stateLayer.pressed ? Tokens.rounding.medium : isCurrentPage ? Tokens.rounding.extraLargeIncreased : isCategoryEnd || touchesSelectedBelow ? Tokens.rounding.extraLarge : Tokens.rounding.extraSmall

                RadiusBehavior on topLeftRadius {}
                RadiusBehavior on topRightRadius {}
                RadiusBehavior on bottomLeftRadius {}
                RadiusBehavior on bottomRightRadius {}

                StateLayer {
                    id: stateLayer

                    anchors.fill: parent
                    topLeftRadius: parent.topLeftRadius
                    topRightRadius: parent.topRightRadius
                    bottomLeftRadius: parent.bottomLeftRadius
                    bottomRightRadius: parent.bottomRightRadius

                    onClicked: root.nState.currentPageIdx = item.modelData.pageIdx
                }

                RowLayout {
                    id: layout

                    anchors.fill: parent
                    anchors.margins: Tokens.padding.large
                    spacing: Tokens.spacing.medium

                    StyledRect {
                        Layout.fillHeight: true
                        Layout.topMargin: -1
                        Layout.bottomMargin: -1
                        implicitWidth: height

                        radius: Tokens.rounding.full
                        color: item.isCurrentPage ? Colours.palette.m3primary : Colours.palette.m3secondaryContainer

                        MaterialIcon {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: 1

                            text: item.modelData.icon
                            color: item.isCurrentPage ? Colours.palette.m3onPrimary : Colours.palette.m3onSecondaryContainer
                            fontStyle: Tokens.font.icon.builders.medium.weight(Font.Medium).build()
                            grade: 25
                            fill: item.modelData.noFill ? 0 : 1
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            text: item.modelData.label
                            font: Tokens.font.body.medium
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: item.modelData.description
                            color: Colours.palette.m3onSurfaceVariant
                            font: Tokens.font.label.small
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }

        GroupHeader {
            visible: root.settings.length > 0
            text: Tr.tr("Settings")
        }

        Repeater {
            id: settingsList

            model: root.settings

            SettingResult {
                required property int index

                first: index === 0
                last: index === settingsList.model.length - 1
                nState: root.nState
            }
        }
    }

    component RadiusBehavior: Behavior {
        Anim {
            type: Anim.DefaultEffects
        }
    }

    // Splits the two kinds of result apart once both are on screen, so a page and a
    // setting with the same name are not mistaken for each other
    component GroupHeader: StyledText {
        Layout.fillWidth: true
        Layout.topMargin: visible ? Tokens.spacing.medium : 0
        Layout.bottomMargin: visible ? Tokens.spacing.extraSmall : 0
        Layout.leftMargin: Tokens.padding.large

        color: Colours.palette.m3onSurfaceVariant
        font: Tokens.font.label.medium
        elide: Text.ElideRight
    }
}
