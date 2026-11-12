pragma ComponentBehavior: Bound

import QtQuick
import qs.components
import qs.components.effects

StyledListView {
    id: root

    property real fadeAmount: 0.2
    // NOTE(fork): how much content has to be hidden past an edge, in pixels, before that edge's
    // fade is at full strength. Under it the fade follows the scroll, so it eases in and out as
    // an end is approached. It used to be all or nothing, which read as the fade hanging on
    // through the whole scroll and then blinking away once the content had already stopped.
    property real fadeRamp: 64

    property real topFadeOpacity: root.fadeOpacity(true)
    property real bottomFadeOpacity: root.fadeOpacity(false)

    // 1 leaves that edge fully opaque (no fade), 0 is the fade at full strength
    function fadeOpacity(isStart: bool): real {
        // When content is smaller than flickable size, hide fade when rebound starts
        if (contentHeight + topMargin + bottomMargin < height && rebound.running && ((isStart ? verticalOvershoot > 0 : verticalOvershoot < 0)))
            return 1;

        const span = contentHeight + topMargin + bottomMargin;
        const hidden = isStart ? visibleArea.yPosition * span : (1 - visibleArea.yPosition - visibleArea.heightRatio) * span;
        if (hidden <= 0)
            return 1;
        return Math.max(0, 1 - hidden / root.fadeRamp);
    }

    flickableDirection: Flickable.VerticalFlick
    orientation: ListView.Vertical

    layer.enabled: true
    layer.effect: Mask {
        maskSource: mask

        Rectangle {
            id: mask

            anchors.fill: parent
            visible: false
            layer.enabled: true

            gradient: Gradient {
                orientation: Gradient.Vertical

                GradientStop {
                    position: 0
                    color: Qt.rgba(0, 0, 0, root.topFadeOpacity)
                }
                GradientStop {
                    position: root.fadeAmount
                    color: Qt.rgba(0, 0, 0, 1)
                }
                GradientStop {
                    position: 1 - root.fadeAmount
                    color: Qt.rgba(0, 0, 0, 1)
                }
                GradientStop {
                    position: 1
                    color: Qt.rgba(0, 0, 0, root.bottomFadeOpacity)
                }
            }
        }
    }
}
