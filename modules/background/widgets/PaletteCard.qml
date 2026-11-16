pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.modules.background

// --- Colour scheme: the colours the shell is drawn in right now ---
//
// Read straight from Colours.palette, so the card follows a scheme or wallpaper change the moment the
// rest of the shell does. Hovering a colour names it in the header with its hex, and clicking copies the
// hex, which is the quickest way to carry the shell's colours into a theme for something else.
WidgetCard {
    id: scheme

    readonly property bool tones: scheme.variant === "tones"

    // The swatch under the pointer, and the one just copied, for the header
    property Item hoveredSwatch: null
    property string copiedHex

    // A tone of one of the scheme's key colours, by lightness. HSL rather than the HCT the scheme itself
    // is built in, which the card has no way to compute: close enough for a ramp that is there to show
    // the spread of a colour, and every patch still copies exactly what it shows
    function tone(key: color, t: real): color {
        return Qt.hsla(Math.max(0, key.hslHue), key.hslSaturation, t / 100, 1);
    }

    function copy(swatch: Item): void {
        Quickshell.execDetached(["wl-copy", swatch.hex]);
        scheme.copiedHex = swatch.hex;
        copiedTimer.restart();
    }

    title: {
        if (scheme.copiedHex !== "")
            return Tr.tr("Copied %1").arg(scheme.copiedHex);
        if (scheme.hoveredSwatch)
            return `${scheme.hoveredSwatch.name} · ${scheme.hoveredSwatch.hex}`;
        return Colours.scheme !== "" ? `${Tr.tr("Colour scheme")} · ${Colours.scheme}` : Tr.tr("Colour scheme");
    }
    icon: scheme.copiedHex !== "" ? "content_copy" : "palette"

    Timer {
        id: copiedTimer

        interval: 1500
        onTriggered: scheme.copiedHex = ""
    }

    // Swatches: each accent with its container under it, then the surfaces from darkest to lightest
    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: !scheme.tones
        spacing: Tokens.spacing.small

        RowLayout {
            id: accents

            // One size for all four names, shrunk together until the longest fits its patch: shrinking each
            // on its own left them in four different sizes side by side
            readonly property real patch: (width - spacing * 3) / 4 - Tokens.padding.small - Tokens.padding.extraSmall
            readonly property font labelFont: Tokens.font.label.builders.small.scale(Math.max(0.6, Math.min(1, patch / Math.max(1, longest.advanceWidth)))).build()

            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Tokens.spacing.small

            TextMetrics {
                id: longest

                font: Tokens.font.label.small
                text: [Tr.tr("Primary"), Tr.tr("Secondary"), Tr.tr("Tertiary"), Tr.tr("Error")].reduce((a, b) => b.length > a.length ? b : a)
            }

            Repeater {
                model: [
                    {
                        name: Tr.tr("Primary"),
                        key: "primary"
                    },
                    {
                        name: Tr.tr("Secondary"),
                        key: "secondary"
                    },
                    {
                        name: Tr.tr("Tertiary"),
                        key: "tertiary"
                    },
                    {
                        name: Tr.tr("Error"),
                        key: "error"
                    }
                ]

                ColumnLayout {
                    id: accent

                    required property var modelData

                    readonly property string cap: modelData.key.charAt(0).toUpperCase() + modelData.key.slice(1)

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1
                    spacing: 2

                    PaletteSwatch {
                        id: keySwatch

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        colour: Colours.palette[`m3${accent.modelData.key}`]
                        onColour: Colours.palette[`m3on${accent.cap}`]
                        name: accent.modelData.name
                        label: accent.modelData.name
                        labelFont: accents.labelFont
                        topLeftRadius: Tokens.rounding.medium
                        topRightRadius: Tokens.rounding.medium
                        bottomLeftRadius: Tokens.rounding.extraSmall
                        bottomRightRadius: Tokens.rounding.extraSmall
                        onHoveredChanged: scheme.hoveredSwatch = hovered ? keySwatch : (scheme.hoveredSwatch === keySwatch ? null : scheme.hoveredSwatch)
                        onActivated: scheme.copy(keySwatch)
                    }

                    PaletteSwatch {
                        id: containerSwatch

                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                        colour: Colours.palette[`m3${accent.modelData.key}Container`]
                        onColour: Colours.palette[`m3on${accent.cap}Container`]
                        name: Tr.tr("%1 container").arg(accent.modelData.name)
                        topLeftRadius: Tokens.rounding.extraSmall
                        topRightRadius: Tokens.rounding.extraSmall
                        bottomLeftRadius: Tokens.rounding.medium
                        bottomRightRadius: Tokens.rounding.medium
                        onHoveredChanged: scheme.hoveredSwatch = hovered ? containerSwatch : (scheme.hoveredSwatch === containerSwatch ? null : scheme.hoveredSwatch)
                        onActivated: scheme.copy(containerSwatch)
                    }
                }
            }
        }

        // The surfaces and the text on them, as one bar
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 26
            Layout.maximumHeight: 26
            spacing: 2

            Repeater {
                id: surfaces

                model: [
                    {
                        name: Tr.tr("Surface (lowest)"),
                        key: "surfaceContainerLowest"
                    },
                    {
                        name: Tr.tr("Surface"),
                        key: "surface"
                    },
                    {
                        name: Tr.tr("Surface container"),
                        key: "surfaceContainer"
                    },
                    {
                        name: Tr.tr("Surface (high)"),
                        key: "surfaceContainerHigh"
                    },
                    {
                        name: Tr.tr("Surface (highest)"),
                        key: "surfaceContainerHighest"
                    },
                    {
                        name: Tr.tr("Outline variant"),
                        key: "outlineVariant"
                    },
                    {
                        name: Tr.tr("Outline"),
                        key: "outline"
                    },
                    {
                        name: Tr.tr("On surface (variant)"),
                        key: "onSurfaceVariant"
                    },
                    {
                        name: Tr.tr("On surface"),
                        key: "onSurface"
                    }
                ]

                PaletteSwatch {
                    id: surfaceSwatch

                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    colour: Colours.palette[`m3${modelData.key}`]
                    name: modelData.name
                    topLeftRadius: index === 0 ? Tokens.rounding.medium : Tokens.rounding.extraSmall
                    bottomLeftRadius: topLeftRadius
                    topRightRadius: index === surfaces.count - 1 ? Tokens.rounding.medium : Tokens.rounding.extraSmall
                    bottomRightRadius: topRightRadius
                    onHoveredChanged: scheme.hoveredSwatch = hovered ? surfaceSwatch : (scheme.hoveredSwatch === surfaceSwatch ? null : scheme.hoveredSwatch)
                    onActivated: scheme.copy(surfaceSwatch)
                }
            }
        }
    }

    // Tonal ramps: each key colour from dark to light, with a mark on the tone the scheme uses for it
    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: scheme.tones
        spacing: Tokens.spacing.small

        Repeater {
            model: [
                {
                    name: Tr.tr("Primary"),
                    key: "primary"
                },
                {
                    name: Tr.tr("Secondary"),
                    key: "secondary"
                },
                {
                    name: Tr.tr("Tertiary"),
                    key: "tertiary"
                }
            ]

            RowLayout {
                id: ramp

                required property var modelData

                readonly property color key: Colours.palette[`m3${ramp.modelData.key}_paletteKeyColor`]
                // The tone of the scheme's own colour, to mark the nearest step to it
                readonly property real used: Colours.palette[`m3${ramp.modelData.key}`].hslLightness * 100

                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Tokens.spacing.small

                StyledText {
                    Layout.preferredWidth: 76
                    elide: Text.ElideRight
                    text: ramp.modelData.name
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.small
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 2

                    Repeater {
                        id: steps

                        model: [10, 20, 30, 40, 50, 60, 70, 80, 90, 95]

                        PaletteSwatch {
                            id: stepSwatch

                            required property int modelData
                            required property int index

                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            colour: scheme.tone(ramp.key, modelData)
                            name: Tr.tr("%1 tone %2").arg(ramp.modelData.name).arg(modelData)
                            marked: {
                                const tones = [10, 20, 30, 40, 50, 60, 70, 80, 90, 95];
                                const nearest = tones.reduce((a, b) => Math.abs(b - ramp.used) < Math.abs(a - ramp.used) ? b : a);
                                return nearest === modelData;
                            }
                            topLeftRadius: index === 0 ? height / 2 : Tokens.rounding.extraSmall
                            bottomLeftRadius: topLeftRadius
                            topRightRadius: index === steps.count - 1 ? height / 2 : Tokens.rounding.extraSmall
                            bottomRightRadius: topRightRadius
                            onHoveredChanged: scheme.hoveredSwatch = hovered ? stepSwatch : (scheme.hoveredSwatch === stepSwatch ? null : scheme.hoveredSwatch)
                            onActivated: scheme.copy(stepSwatch)
                        }
                    }
                }
            }
        }
    }
}
