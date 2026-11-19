pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.modules.utilities.cards
import qs.modules.bar.popouts as BarPopouts

Item {
    id: root

    required property var props
    required property ScreenState screenState
    required property BarPopouts.Wrapper popouts
    required property matrix4x4 deformMatrix

    // Bumped as cards come and go, so the height below is worked out again for them: itemAt() on its own
    // doesn't tell a binding that an item has been created
    property int cardsRevision

    readonly property real nonAnimHeight: {
        root.cardsRevision;

        let height = 0;
        let shown = 0;
        for (let i = 0; i < cards.count; i++) {
            const card = cards.itemAt(i);
            if (!card?.active)
                continue;

            height += card.cardHeight;
            shown++;
        }
        return height + layout.spacing * Math.max(0, shown - 1);
    }

    function cardEnabled(id: string): bool {
        switch (id) {
        case "keepAwake":
            return Config.utilities.cards.keepAwake;
        case "recorder":
            return Config.utilities.cards.recorder;
        case "phoneShare":
            return Config.utilities.cards.phoneShare;
        case "quickToggles":
            return Config.utilities.cards.quickToggles;
        case "appVolumes":
            return Config.utilities.cards.appVolumes;
        }
        return false;
    }

    implicitWidth: layout.implicitWidth
    implicitHeight: layout.implicitHeight

    ColumnLayout {
        id: layout

        anchors.fill: parent
        spacing: Tokens.spacing.medium

        // The cards, in the order Config.utilities.cards.order gives. A card that is not in the list is not shown
        Repeater {
            id: cards

            model: ScriptModel {
                values: Config.utilities.cards.order.values
            }

            onItemAdded: root.cardsRevision++
            onItemRemoved: root.cardsRevision++

            Loader {
                id: card

                required property var modelData

                readonly property string cardId: modelData.id
                readonly property bool compact: modelData.size === "compact"
                readonly property bool vertical: modelData.size === "vertical"
                // What the card settles at rather than what it is passing through, where it has one
                readonly property real cardHeight: item ? (item.nonAnimHeight ?? item.implicitHeight) : 0

                Layout.fillWidth: true
                active: root.cardEnabled(cardId)
                visible: active
                // The recorder's menu opens over the cards under it
                z: cardId === "recorder" ? 1 : 0

                sourceComponent: {
                    switch (cardId) {
                    case "keepAwake":
                        return keepAwakeCard;
                    case "recorder":
                        return recorderCard;
                    case "phoneShare":
                        return phoneShareCard;
                    case "quickToggles":
                        return togglesCard;
                    case "appVolumes":
                        return appVolumesCard;
                    }
                    return null;
                }

                // Only these have a compact form
                Binding {
                    target: card.item
                    property: "compact"
                    value: card.compact
                    when: card.item && (card.cardId === "keepAwake" || card.cardId === "recorder" || card.cardId === "appVolumes")
                }

                // The app volumes card also has a sideways layout of its own
                Binding {
                    target: card.item
                    property: "vertical"
                    value: card.vertical
                    when: card.item && card.cardId === "appVolumes"
                }
            }
        }
    }

    Component {
        id: keepAwakeCard

        IdleInhibit {
            objectName: "utilitiesKeepAwake"
        }
    }

    Component {
        id: recorderCard

        Record {
            objectName: "utilitiesScreenRecorder"

            props: root.props
            screenState: root.screenState
        }
    }

    Component {
        id: phoneShareCard

        PhoneShare {
            objectName: "utilitiesPhoneShare"

            screenState: root.screenState
        }
    }

    Component {
        id: appVolumesCard

        AppVolumesCard {
            objectName: "utilitiesAppVolumes"
        }
    }

    Component {
        id: togglesCard

        Toggles {
            objectName: "utilitiesQuickToggles"

            screenState: root.screenState
            popouts: root.popouts
        }
    }

    RecordingDeleteModal {
        props: root.props
        deformMatrix: root.deformMatrix
    }
}
