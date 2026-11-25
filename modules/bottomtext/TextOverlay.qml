pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.services

// NOTE(fork): bottom-of-screen random text overlay with configurable transition animations
// (fade, slide, typewriter, scramble, pop, none).
Variants {
    model: Screens.screens

    StyledWindow {
        id: win

        required property ShellScreen modelData

        readonly property var bar: ShellState.componentsFor(win.screen)?.bar
        readonly property int bottomInset: (win.bar?.onBottom ? win.bar.contentThickness : GlobalConfig.border.thickness) + GlobalConfig.appearance.padding.medium
        readonly property string animStyle: GlobalConfig.utilities.bottomText.animation

        readonly property string incomingText: BottomText.current

        property string shownText: BottomText.current
        property string targetText: BottomText.current
        property int effectIndex: 0
        property string typePhase: "idle"
        property bool cursorOn: false
        property int stepCooldownMs: 0
        property int cursorElapsedMs: 0

        function resetVisuals(): void {
            label.opacity = 1;
            label.yOffset = 0;
            label.scale = 1;
            win.typePhase = "idle";
            win.cursorOn = false;
            win.stepCooldownMs = 0;
            win.cursorElapsedMs = 0;
        }

        function nextTypeDelay(phase: string, ch: string): int {
            const jitter = Math.floor(Math.random() * 26) - 10;
            if (phase === "erasing")
                return Math.max(12, 20 + jitter);
            if (ch === " ")
                return Math.max(20, 32 + jitter);
            if (ch === "." || ch === "," || ch === "!" || ch === "?" || ch === ";")
                return Math.max(70, 105 + jitter);
            return Math.max(22, 42 + jitter);
        }

        function startTransition(nextText: string): void {
            switchAnim.stop();
            scrambleTimer.stop();
            win.targetText = nextText;

            if (win.animStyle === "none") {
                win.resetVisuals();
                win.shownText = nextText;
            } else if (win.animStyle === "typewriter") {
                win.resetVisuals();
                win.cursorOn = true;
                if (win.shownText.length > 0) {
                    win.typePhase = "erasing";
                    win.effectIndex = win.shownText.length;
                    win.stepCooldownMs = 20;
                } else {
                    win.typePhase = "typing";
                    win.effectIndex = 0;
                    win.stepCooldownMs = 35;
                }
            } else if (win.animStyle === "scramble") {
                win.resetVisuals();
                win.effectIndex = 0;
                scrambleTimer.restart();
            } else {
                win.resetVisuals();
                switchAnim.restart();
            }
        }

        onIncomingTextChanged: {
            if (win.targetText === win.incomingText && win.shownText === win.incomingText)
                return;

            win.startTransition(win.incomingText);
        }

        screen: modelData
        name: "bottom-text"
        visible: GlobalConfig.utilities.bottomText.enabled
        implicitHeight: label.implicitHeight + GlobalConfig.appearance.padding.large * 2
        mask: empty

        margins.bottom: win.bottomInset
        anchors.bottom: true
        anchors.left: true
        anchors.right: true

        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        surfaceFormat.opaque: false

        Timer {
            id: typeTickTimer

            interval: 16
            running: win.typePhase !== "idle"
            repeat: true
            onTriggered: {
                win.cursorElapsedMs += 16;
                if (win.cursorElapsedMs >= 260) {
                    win.cursorElapsedMs = 0;
                    win.cursorOn = !win.cursorOn;
                }

                win.stepCooldownMs -= 16;
                if (win.stepCooldownMs > 0)
                    return;

                if (win.typePhase === "erasing") {
                    if (win.effectIndex > 0) {
                        win.effectIndex -= 1;
                        win.shownText = win.shownText.slice(0, win.effectIndex);
                        win.cursorOn = true;
                        win.cursorElapsedMs = 0;
                        win.stepCooldownMs = win.nextTypeDelay("erasing", "");
                    } else {
                        win.typePhase = "pause";
                        win.cursorOn = true;
                        win.cursorElapsedMs = 0;
                        win.stepCooldownMs = 150;
                    }
                } else if (win.typePhase === "pause") {
                    win.typePhase = "typing";
                    win.effectIndex = 0;
                    win.cursorOn = true;
                    win.cursorElapsedMs = 0;
                    win.stepCooldownMs = 35;
                } else if (win.typePhase === "typing") {
                    if (win.effectIndex < win.targetText.length) {
                        const ch = win.targetText[win.effectIndex];
                        win.effectIndex += 1;
                        win.shownText = win.targetText.slice(0, win.effectIndex);
                        win.cursorOn = true;
                        win.cursorElapsedMs = 0;
                        win.stepCooldownMs = win.nextTypeDelay("typing", ch);
                    } else {
                        win.shownText = win.targetText;
                        win.typePhase = "idle";
                        win.cursorOn = false;
                    }
                }
            }
        }

        Timer {
            id: scrambleTimer

            readonly property string glyphs: "!<>-_\/[]{}—=+*^?#________"

            interval: 24
            repeat: true
            onTriggered: {
                const target = win.targetText;
                const totalSteps = Math.max(12, target.length + 6);
                win.effectIndex += 1;

                if (win.effectIndex >= totalSteps) {
                    win.shownText = target;
                    scrambleTimer.stop();
                    return;
                }

                const resolvedCount = Math.floor((win.effectIndex / totalSteps) * target.length);
                let out = target.slice(0, resolvedCount);
                for (let i = resolvedCount; i < target.length; i++) {
                    const ch = target[i];
                    if (ch === " ") {
                        out += " ";
                    } else {
                        out += glyphs[Math.floor(Math.random() * glyphs.length)];
                    }
                }
                win.shownText = out;
            }
        }

        SequentialAnimation {
            id: switchAnim

            ParallelAnimation {
                Anim {
                    target: label
                    property: "opacity"
                    to: 0
                    type: Anim.DefaultEffects
                }
                Anim {
                    target: label
                    property: "yOffset"
                    to: win.animStyle === "slide" ? -8 : 0
                }
                Anim {
                    target: label
                    property: "scale"
                    to: win.animStyle === "pop" ? 0.92 : 1
                }
            }

            ScriptAction {
                script: {
                    win.shownText = win.targetText;
                    label.yOffset = win.animStyle === "slide" ? 8 : 0;
                    label.scale = win.animStyle === "pop" ? 0.92 : 1;
                }
            }

            ParallelAnimation {
                Anim {
                    target: label
                    property: "opacity"
                    to: 1
                    type: Anim.DefaultEffects
                }
                Anim {
                    target: label
                    property: "yOffset"
                    to: 0
                }
                Anim {
                    target: label
                    property: "scale"
                    to: 1
                }
            }
        }

        Region {
            id: empty
        }

        StyledText {
            id: label

            property real yOffset: 0

            readonly property bool showCursor: win.typePhase !== "idle"
            readonly property string cursorChar: showCursor ? (win.cursorOn ? "|" : " ") : ""

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: yOffset
            width: parent.width - GlobalConfig.appearance.padding.extraLargeIncreased * 2
            text: win.shownText + cursorChar
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            color: Qt.alpha(Colours.palette.m3onSurfaceVariant, 0.8)
            font: Tokens.font.body.small
        }
    }
}
