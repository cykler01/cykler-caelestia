pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services
import qs.modules.nexus

ColumnLayout {
    id: root

    required property string title
    required property NexusState nState
    property bool isSubPage

    // Set by a page that has steps of its own inside it, so the back arrow walks back through those
    // before it leaves the page. Without it the arrow always closes the whole sub-page, which from
    // step two of a picker drops you out of the page entirely rather than back to step one.
    property bool handlesBack
    readonly property int cappedWidth: Math.min(Tokens.sizes.nexus.maxContentWidth, width)
    readonly property alias flickable: flickable

    // The row a settings search result asked for. The flash is reparented onto it
    // rather than drawn at a remembered position, so it keeps covering the row when
    // the page relayouts underneath it.
    property Item highlightItem

    default property Item contentChild

    // Emitted instead of closing the page when the page said it handles its own back
    signal backPressed

    // Scrolls to the row a search result pointed at and flashes it, if this is the page
    // that result named. A page further out may well hold a row of the same name - the
    // "Widgets" link on Panels against the Widgets page itself - so the title has to
    // match too, or the flash would land on whichever page loaded first.
    function highlightSetting(): void {
        if (!root.nState.highlightLabel)
            return;
        if (root.nState.highlightTitle && root.nState.highlightTitle !== root.title)
            return;

        pendingHighlight.label = root.nState.highlightLabel;
        pendingHighlight.section = root.nState.highlightSection;
        root.nState.clearHighlight();
        pendingHighlight.restart();
    }

    // Depth first through the page, in the order the rows are declared, so the section
    // headers passed on the way say which section each row is in. That is what tells
    // the two "Show in fullscreen" rows on the notifications page apart.
    function findRow(item: Item, label: string, section: string): Item {
        let current = "";
        let fallback = null;
        let found = null;

        const visit = node => {
            if (found || !node)
                return;

            if (node.isSectionHeader === true) {
                current = node.text ?? "";
            } else if (node.searchLabel && node.searchLabel === label) {
                if (!fallback)
                    fallback = node;
                if (!section || current === section) {
                    found = node;
                    return;
                }
            }

            const children = node.children ?? [];
            for (let i = 0; i < children.length; i++)
                visit(children[i]);
        };

        visit(item);
        return found ?? fallback;
    }

    spacing: Tokens.spacing.extraLargeIncreased

    Component.onCompleted: root.highlightSetting()

    MouseArea { // Prevent clicks from reaching flickable
        z: 1
        implicitWidth: header.implicitWidth
        implicitHeight: header.implicitHeight - Layout.bottomMargin
        Layout.bottomMargin: -flickable.topMargin // Extra height to block clicks on flickable top margin
        onClicked: focus = true

        RowLayout {
            id: header

            spacing: Tokens.spacing.largeIncreased

            Loader {
                visible: active
                active: root.isSubPage
                asynchronous: true
                sourceComponent: IconButton {
                    icon: "arrow_back"
                    font: Tokens.font.icon.medium
                    type: IconButton.Tonal
                    isRound: true
                    inactiveColour: Colours.tPalette.m3surfaceContainerHigh
                    inactiveOnColour: Colours.palette.m3onSurfaceVariant
                    onClicked: {
                        if (root.handlesBack)
                            root.backPressed();
                        else
                            root.nState.closeSubPage();
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: root.title
                font: Tokens.font.title.large
                elide: Text.ElideRight
            }
        }
    }

    VerticalFadeFlickable {
        id: flickable

        Layout.fillWidth: true
        Layout.fillHeight: true

        Layout.topMargin: -topMargin
        topMargin: Tokens.padding.large
        bottomMargin: Tokens.padding.extraLarge

        contentHeight: root.contentChild?.implicitHeight ?? 0
        contentItem.children: [root.contentChild]

        TapHandler {
            onTapped: flickable.focus = true
        }

        Anim {
            id: scrollAnim

            target: flickable
            property: "contentY"
            type: Anim.SlowSpatial
        }
    }

    Connections {
        // Already on the right page, so nothing reloaded and no page ran its
        // Component.onCompleted - ask directly instead
        function onHighlightRequested(): void {
            root.highlightSetting();
        }

        target: root.nState
    }

    Timer {
        id: pendingHighlight

        property string label
        property string section

        // Waits out the push transition, so the rows have settled where they will stay
        // and the scroll lands on the right one
        interval: Tokens.anim.durations.expressiveDefaultEffects
        onTriggered: {
            const target = root.findRow(root.contentChild, pendingHighlight.label, pendingHighlight.section);
            if (!target)
                return;

            root.highlightItem = target;

            // Centre the row where there is room to, and otherwise go as far as the
            // content allows rather than scrolling past its end
            const pos = target.mapToItem(flickable.contentItem, 0, 0);
            const centred = pos.y - (flickable.height - target.height) / 2;
            const top = -flickable.topMargin;
            const bottom = Math.max(top, flickable.contentHeight + flickable.bottomMargin - flickable.height);
            scrollAnim.to = Math.max(top, Math.min(centred, bottom));
            scrollAnim.restart();
            flashAnim.restart();
        }
    }

    // Sits on top of the row it is parented to, so it tracks the row's size and corners
    // without having to be told where the row went
    StyledRect {
        id: flash

        parent: root.highlightItem
        anchors.fill: flash.parent
        visible: flash.opacity > 0
        opacity: 0
        color: Colours.palette.m3primary
        topLeftRadius: flash.parent?.topLeftRadius ?? 0
        topRightRadius: flash.parent?.topRightRadius ?? 0
        bottomLeftRadius: flash.parent?.bottomLeftRadius ?? 0
        bottomRightRadius: flash.parent?.bottomRightRadius ?? 0

        SequentialAnimation {
            id: flashAnim

            Anim {
                target: flash
                property: "opacity"
                to: 0.26
                type: Anim.DefaultEffects
            }
            Anim {
                target: flash
                property: "opacity"
                to: 0
                type: Anim.SlowEffects
            }
            PauseAnimation {
                duration: Tokens.anim.durations.expressiveFastEffects
            }
            Anim {
                target: flash
                property: "opacity"
                to: 0.26
                type: Anim.DefaultEffects
            }
            Anim {
                target: flash
                property: "opacity"
                to: 0
                type: Anim.SlowEffects
            }
        }
    }
}
