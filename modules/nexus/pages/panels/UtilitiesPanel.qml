pragma ComponentBehavior: Bound

import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.utils
import qs.modules.nexus.common

PageBase {
    id: root

    readonly property var cardNames: ({
            keepAwake: Tr.tr("Keep awake"),
            recorder: Tr.tr("Screen recorder"),
            phoneShare: Tr.tr("Phone share"),
            quickToggles: Tr.tr("Quick toggles"),
            appVolumes: Tr.tr("App volumes")
        })
    readonly property var toggleNames: ({
            wifi: Tr.tr("Wi-Fi"),
            bluetooth: Tr.tr("Bluetooth"),
            mic: Tr.tr("Microphone"),
            timer: Tr.tr("Timer"),
            settings: Tr.tr("Settings"),
            lock: Tr.tr("Lock"),
            gameMode: Tr.tr("Game mode"),
            wallpaperPlaying: Tr.tr("Live wallpaper"),
            dnd: Tr.tr("Do not disturb"),
            vpn: Tr.tr("VPN")
        })
    // Only these have a smaller form: Keep awake drops the line under its title and the "active since" chip, the
    // recorder drops its list of recordings, and app volumes folds its sliders away behind a caret or stands them
    // upright
    readonly property var cardSizeOptions: {
        const sizes = [
            {
                value: "normal",
                label: Tr.trCtx("Normal", "card size")
            },
            {
                value: "compact",
                label: Tr.trCtx("Compact", "card size")
            }
        ];
        return {
            keepAwake: sizes,
            recorder: sizes,
            appVolumes: [...sizes, {
                    value: "vertical",
                    label: Tr.trCtx("Vertical", "card size")
                }]
        };
    }

    function isCardOn(id: string): bool {
        return Config.utilities.cards[id] ?? false;
    }

    function setCardOn(id: string, on: bool): void {
        GlobalConfig.utilities.cards[id] = on;
    }

    title: Tr.tr("Utilities")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // General
        SectionHeader {
            first: true
            text: Tr.tr("General")
        }

        ToggleRow {
            first: true
            last: true
            text: Tr.trCtx("Enabled", "toggle label")
            subtext: Tr.tr("Show the utilities panel")
            checked: Config.utilities.enabled
            onToggled: GlobalConfig.utilities.enabled = checked
        }

        // Layout
        SectionHeader {
            text: Tr.tr("Layout")
        }

        UtilitiesPreview {
            Layout.fillWidth: true
            Layout.bottomMargin: Tokens.spacing.small
            cardNames: root.cardNames
            toggleNames: root.toggleNames
        }

        // Cards
        SectionHeader {
            text: Tr.tr("Cards")
        }

        StyledText {
            Layout.fillWidth: true
            Layout.bottomMargin: Tokens.spacing.small
            text: Tr.tr("The cards in the panel, top to bottom. Drag to reorder, switch one off to hide it, and press the size to change how much of the card shows.")
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
            wrapMode: Text.WordWrap
        }

        ListEditor {
            function labelFor(item: var): string {
                return root.cardNames[item.id] ?? item.id;
            }

            function toggledFor(item: var): bool {
                return root.isCardOn(item.id);
            }

            function sizeFor(item: var): var {
                return item.size;
            }

            function sizeOptionsFor(item: var): var {
                return root.cardSizeOptions[item.id] ?? [];
            }

            z: 1
            first: true
            removable: false
            values: Config.utilities.cards.order.values
            onItemMoved: (from, to) => GlobalConfig.utilities.cards.order.move(from, to)
            onItemToggled: (index, checked) => root.setCardOn(Config.utilities.cards.order.values[index].id, checked)
            onItemResized: (index, size) => GlobalConfig.utilities.cards.order.at(index).size = size
        }

        // Puts back a card that is missing from the order list, which is what a config written before the card
        // existed ends up with; without this there is no row to switch on and no way to add one
        DialogSelectButton {
            rootParent: root.flickable
            icon: "add"
            label: Tr.tr("Add card")
            header: Tr.tr("Add a card")
            acceptLabel: Tr.trCtx("Add", "button")
            visible: model.length > 0

            model: Object.keys(root.cardNames).filter(id => !Config.utilities.cards.order.values.some(c => c.id === id)).map(id => ({
                        id,
                        label: root.cardNames[id]
                    }))

            onAccepted: {
                if (!selectedItem)
                    return;

                GlobalConfig.utilities.cards.order.insert({
                    id: selectedItem,
                    size: "normal"
                });
                root.setCardOn(selectedItem, true);
            }
        }

        // Quick toggles
        SectionHeader {
            text: Tr.tr("Quick toggles")
        }

        StyledText {
            Layout.fillWidth: true
            Layout.bottomMargin: Tokens.spacing.small
            text: Tr.tr("The buttons in the quick toggles card, in the order they sit in it. Press the size to make a button wider; a row holds as many columns as set below.")
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
            wrapMode: Text.WordWrap
        }

        ListEditor {
            function labelFor(item: var): string {
                return root.toggleNames[item.id] ?? item.id;
            }

            function toggledFor(item: var): bool {
                return item.enabled;
            }

            function sizeFor(item: var): var {
                return Math.max(1, Math.min(Config.utilities.cards.toggleColumns, item.span));
            }

            z: 1
            first: true
            sizeOptions: Array.from({
                length: Config.utilities.cards.toggleColumns
            }, (_, i) => ({
                        value: i + 1,
                        label: "×" + (i + 1)
                    }))
            values: Config.utilities.quickToggles.values
            onItemMoved: (from, to) => GlobalConfig.utilities.quickToggles.move(from, to)
            onItemRemoved: index => GlobalConfig.utilities.quickToggles.remove(index)
            onItemToggled: (index, checked) => GlobalConfig.utilities.quickToggles.at(index).enabled = checked
            onItemResized: (index, size) => GlobalConfig.utilities.quickToggles.at(index).span = size
        }

        DialogSelectButton {
            rootParent: root.flickable
            icon: "add"
            label: Tr.tr("Add toggle")
            header: Tr.tr("Add a quick toggle")
            acceptLabel: Tr.trCtx("Add", "button")

            model: Object.keys(root.toggleNames).filter(id => !Config.utilities.quickToggles.values.some(t => t.id === id)).map(id => ({
                        id,
                        label: root.toggleNames[id]
                    }))

            onAccepted: {
                if (!selectedItem)
                    return;

                GlobalConfig.utilities.quickToggles.insert({
                    id: selectedItem,
                    enabled: true
                });
            }
        }

        StepperRow {
            first: true
            last: true
            label: Tr.tr("Columns")
            subtext: Tr.tr("How many toggles fit side by side in a row")
            value: Config.utilities.cards.toggleColumns
            from: 1
            to: 6
            onMoved: v => GlobalConfig.utilities.cards.toggleColumns = Math.round(v)
        }
    }
}
