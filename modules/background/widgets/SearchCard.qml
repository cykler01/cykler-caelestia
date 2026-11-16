pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.modules.background
import qs.modules.launcher.services as LauncherServices

// --- Web search: a search field on the desktop, alone or with a row of sites to search instead ---
//
// What is typed goes to the browser the same way the launcher's ">b" does (modules/launcher/services/
// Browser.qml): an address opens as one, anything else becomes a web search. The sites variant can scope
// the search to one site first, or open the site itself when there is nothing typed.
WidgetCard {
    id: search

    readonly property bool withSites: search.variant === "shortcuts"

    // A site's own search, for the chips. `query` is put straight after the prefix, encoded
    readonly property var sites: [
        {
            name: Tr.tr("YouTube"),
            icon: "smart_display",
            home: "https://www.youtube.com",
            query: "https://www.youtube.com/results?search_query="
        },
        {
            name: Tr.tr("GitHub"),
            icon: "code",
            home: "https://github.com",
            query: "https://github.com/search?q="
        },
        {
            name: Tr.tr("Wikipedia"),
            icon: "menu_book",
            home: "https://en.wikipedia.org",
            query: "https://en.wikipedia.org/w/index.php?search="
        },
        {
            name: Tr.tr("Maps"),
            icon: "map",
            home: "https://www.google.com/maps",
            query: "https://www.google.com/maps/search/"
        }
    ]

    // The site the next search goes to, or -1 for the web as a whole
    property int scope: -1
    readonly property var scoped: search.scope >= 0 ? search.sites[search.scope] : null

    property bool hovered
    // Set once a search has gone out or Escape was pressed, so the card hands the keyboard back even with
    // the pointer still over it. Cleared as the pointer leaves or the field is clicked again
    property bool released
    // The desktop only takes the keyboard while the card says so. Asked for on hover as well as focus, as
    // the sticky note does, so the click that focuses the field already lands with the keyboard there
    readonly property bool wantsKeys: !search.preview && (input.activeFocus || (search.hovered && !search.released))

    function focusField(): void {
        if (search.preview)
            return;

        search.released = false;
        input.forceActiveFocus();
    }

    // Clears the field and lets go of the keyboard; the search itself, if any, has already been sent
    function finish(): void {
        input.text = "";
        search.scope = -1;
        search.released = true;
        input.focus = false;
    }

    function submit(): void {
        const text = input.text.trim();
        let url = "";
        if (search.scoped)
            url = text === "" ? search.scoped.home : search.scoped.query + encodeURIComponent(text);
        else
            url = LauncherServices.Browser.urlFor(text);

        if (url === "")
            return;

        LauncherServices.Browser.open(url);
        search.finish();
    }

    // With something typed a chip searches that site straight away; with nothing it becomes the scope for
    // what is typed next, and picking the scoped one again opens the site itself
    function pickSite(index: int): void {
        if (search.preview)
            return;

        const text = input.text.trim();
        const site = search.sites[index];
        if (text !== "") {
            LauncherServices.Browser.open(site.query + encodeURIComponent(text));
            search.finish();
        } else if (search.scope === index) {
            LauncherServices.Browser.open(site.home);
            search.finish();
        } else {
            search.scope = index;
            search.focusField();
        }
    }

    title: search.withSites ? Tr.tr("Web search") : ""
    icon: search.withSites ? "search" : ""
    padding: search.withSites ? Tokens.padding.largeIncreased : Tokens.padding.medium

    onWantsKeysChanged: search.keyboardWanted(search.wantsKeys)

    HoverHandler {
        onHoveredChanged: {
            search.hovered = hovered;
            if (!hovered)
                search.released = false;
        }
    }

    // The field: a pill with the scope (if any) in front of what is typed and a go button once there is
    // something to go to
    StyledRect {
        Layout.fillWidth: true
        Layout.fillHeight: !search.withSites
        Layout.preferredHeight: 40
        Layout.minimumHeight: 36
        radius: Tokens.rounding.full
        color: Colours.tPalette.m3surfaceContainerHigh
        border.width: input.activeFocus ? 1 : 0
        border.color: Qt.alpha(Colours.palette.m3primary, 0.6)

        // Behind the row, so a click anywhere on the pill that isn't the go button lands in the field
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.IBeamCursor
            enabled: !search.preview
            onClicked: search.focusField()
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Tokens.padding.large
            anchors.rightMargin: Tokens.padding.small
            spacing: Tokens.spacing.small

            MaterialIcon {
                // A globe once what is typed reads as an address, since that is where Enter goes then
                text: !search.scoped && LauncherServices.Browser.isAddress(input.text) ? "language" : "search"
                color: Colours.palette.m3primary
                fontStyle: Tokens.font.icon.medium
            }

            // The site a scoped search goes to, as a token in the field. Backspace on an empty field drops it
            StyledRect {
                visible: search.scoped !== null
                implicitWidth: scopeRow.implicitWidth + Tokens.padding.medium * 2
                implicitHeight: scopeRow.implicitHeight + Tokens.padding.extraSmall * 2
                radius: Tokens.rounding.full
                color: Colours.palette.m3secondaryContainer

                RowLayout {
                    id: scopeRow

                    anchors.centerIn: parent
                    spacing: Tokens.spacing.extraSmall

                    MaterialIcon {
                        text: search.scoped?.icon ?? ""
                        color: Colours.palette.m3onSecondaryContainer
                        fontStyle: Tokens.font.icon.small
                    }

                    StyledText {
                        text: search.scoped?.name ?? ""
                        color: Colours.palette.m3onSecondaryContainer
                        font: Tokens.font.label.medium
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                TextInput {
                    id: input

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    enabled: !search.preview
                    clip: true
                    selectByMouse: true
                    color: Colours.palette.m3onSurface
                    selectionColor: Qt.alpha(Colours.palette.m3primary, 0.4)
                    selectedTextColor: Colours.palette.m3onSurface
                    font: Tokens.font.body.medium
                    renderType: Text.NativeRendering

                    onAccepted: search.submit()

                    Keys.onEscapePressed: search.finish()
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Backspace && input.text === "" && search.scope >= 0) {
                            search.scope = -1;
                            event.accepted = true;
                        }
                    }
                }

                StyledText {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: input.text === ""
                    elide: Text.ElideRight
                    text: search.scoped ? Tr.tr("Search %1").arg(search.scoped.name) : Tr.tr("Search the web")
                    color: Colours.palette.m3outline
                    font: Tokens.font.body.medium
                }
            }

            // Go: shown once there is somewhere to go, which a scope alone already is (its home page)
            StyledRect {
                readonly property bool ready: input.text.trim() !== "" || search.scoped !== null

                implicitWidth: 32
                implicitHeight: 32
                radius: Tokens.rounding.full
                color: ready ? Colours.palette.m3primary : "transparent"
                opacity: ready ? 1 : 0

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "arrow_forward"
                    color: Colours.palette.m3onPrimary
                    fontStyle: Tokens.font.icon.small
                }

                StateLayer {
                    radius: Tokens.rounding.full
                    color: Colours.palette.m3onPrimary
                    disabled: search.preview || !parent.ready
                    onClicked: search.submit()
                }

                Behavior on opacity {
                    Anim {
                        type: Anim.StandardSmall
                    }
                }
            }
        }
    }

    // The sites, as chips sharing the width in proportion to their names. Words only: with an icon as well
    // four of them no longer fit across the card without cutting the names short
    RowLayout {
        Layout.fillWidth: true
        visible: search.withSites
        spacing: Tokens.spacing.small

        Repeater {
            model: search.sites

            StyledRect {
                id: chip

                required property var modelData
                required property int index

                readonly property bool active: search.scope === chip.index

                Layout.fillWidth: true
                Layout.preferredWidth: chipLabel.implicitWidth + Tokens.padding.large * 2
                implicitHeight: 32
                radius: Tokens.rounding.full
                color: chip.active ? Colours.palette.m3secondaryContainer : "transparent"
                border.width: chip.active ? 0 : 1
                border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.8)

                StyledText {
                    id: chipLabel

                    anchors.centerIn: parent
                    width: Math.min(implicitWidth, parent.width - Tokens.padding.small * 2)
                    elide: Text.ElideRight
                    text: chip.modelData.name
                    color: chip.active ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.medium
                }

                StateLayer {
                    radius: Tokens.rounding.full
                    color: Colours.palette.m3onSurface
                    disabled: search.preview
                    onClicked: search.pickSite(chip.index)
                }
            }
        }
    }
}
