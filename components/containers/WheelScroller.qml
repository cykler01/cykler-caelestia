import QtQuick

// Takes wheel and trackpad scrolling away from the Flickable it's attached to.
//
// Flickable writes each wheel event's delta straight into contentX/contentY.
// Trackpad events (which carry a pixelDelta) arrive at an irregular rate, so
// the content lurches a different distance every frame instead of gliding, and
// since the end-of-gesture phase libinput sends doesn't reliably make it
// through, the view can be left parked past its bounds with nothing to pull it
// back. Dragging is unaffected by any of this, which is why it feels fine.
//
// So instead of moving the content per event, deltas accumulate into a target
// position that a per-frame driver eases towards. Past either end the target is
// rubber banded and springs back as soon as the wheel goes quiet, which is how
// a drag already behaves.
MouseArea {
    id: root

    required property Flickable flickable

    // Distance one notch of a discrete mouse wheel covers
    property real step: 120
    // How far past either end the content can be pushed
    property real overshoot: 64
    // Time constant of the easing, in seconds; lower follows the input closer
    property real smoothing: 0.07
    // How long after the last event the rubber band is let go
    property int settleDelay: 120

    // True while the driver is running, for anything that wants to show itself
    // during a scroll (scrollbars) the way Flickable.moving would
    property bool active

    property real targetX
    property real targetY

    readonly property real minX: flickable.originX - flickable.leftMargin
    readonly property real maxX: Math.max(minX, flickable.originX + flickable.contentWidth + flickable.rightMargin - flickable.width)
    readonly property real minY: flickable.originY - flickable.topMargin
    readonly property real maxY: Math.max(minY, flickable.originY + flickable.contentHeight + flickable.bottomMargin - flickable.height)

    readonly property bool canScrollX: maxX > minX && flickable.flickableDirection !== Flickable.VerticalFlick
    readonly property bool canScrollY: maxY > minY && flickable.flickableDirection !== Flickable.HorizontalFlick

    // Whether anything further out could still use a wheel event we can't act
    // on. If nothing can, we swallow it rather than letting Flickable take it
    // and bounce content that already fits.
    function hasScrollableAncestor(): bool {
        let item = flickable.parent;
        while (item) {
            const f = item as Flickable;
            if (f && f.interactive && (f.contentHeight > f.height || f.contentWidth > f.width))
                return true;
            item = item.parent;
        }
        return false;
    }

    // Every pixel past the end counts for less than the one before it, so the
    // content eases to a stop rather than running off
    function band(value: real, min: real, max: real): real {
        const bounded = Math.max(min, Math.min(max, value));
        const past = value - bounded;
        if (past === 0)
            return value;
        return bounded + Math.sign(past) * overshoot * (1 - Math.exp(-Math.abs(past) / overshoot));
    }

    parent: flickable
    anchors.fill: parent
    z: 1

    // Wheel events still arrive, but presses and hovers carry on through to the
    // delegates underneath
    acceptedButtons: Qt.NoButton
    enabled: flickable.interactive

    onWheel: event => {
        const pixel = event.pixelDelta.x !== 0 || event.pixelDelta.y !== 0;
        let dx = pixel ? -event.pixelDelta.x : -(event.angleDelta.x / 120) * root.step;
        let dy = pixel ? -event.pixelDelta.y : -(event.angleDelta.y / 120) * root.step;

        // A vertical wheel over something that only scrolls sideways should
        // still move it
        if (dx === 0 && dy !== 0 && root.canScrollX && !root.canScrollY) {
            dx = dy;
            dy = 0;
        }

        // And a sideways swipe over something that only scrolls up and down
        // should move that instead: on a trackpad the horizontal gesture is the
        // same two fingers, and a vertical-only list has nothing else to do with it
        if (dy === 0 && dx !== 0 && root.canScrollY && !root.canScrollX) {
            dy = dx;
            dx = 0;
        }

        const movesX = root.canScrollX && dx !== 0;
        const movesY = root.canScrollY && dy !== 0;

        if (!movesX && !movesY) {
            if (dx === 0 && dy === 0) {
                // End of a trackpad gesture: let the rubber band go now instead
                // of waiting out the timer
                idle.stop();
                event.accepted = root.active;
            } else {
                // A direction we can't move in. Hand it on only if something
                // further out can use it, otherwise swallow it so Flickable
                // doesn't bounce content that already fits.
                event.accepted = !root.hasScrollableAncestor();
            }
            return;
        }

        event.accepted = true;
        root.flickable.cancelFlick();

        if (!root.active) {
            root.active = true;
            root.targetX = root.flickable.contentX;
            root.targetY = root.flickable.contentY;
        }

        if (movesX)
            root.targetX = root.band(root.targetX + dx, root.minX, root.maxX);
        if (movesY)
            root.targetY = root.band(root.targetY + dy, root.minY, root.maxY);

        idle.restart();
    }

    // A drag takes over from here; Flickable's own bounds handling is fine for it
    Connections {
        function onDraggingChanged(): void {
            if (root.flickable.dragging) {
                root.active = false;
                idle.stop();
            }
        }

        target: root.flickable
    }

    Timer {
        id: idle

        interval: root.settleDelay
    }

    FrameAnimation {
        running: root.active

        onTriggered: {
            const flickable = root.flickable;

            // Nothing more coming, so pull the rubber band back in
            if (!idle.running) {
                root.targetX = Math.max(root.minX, Math.min(root.maxX, root.targetX));
                root.targetY = Math.max(root.minY, Math.min(root.maxY, root.targetY));
            }

            const dx = root.canScrollX ? root.targetX - flickable.contentX : 0;
            const dy = root.canScrollY ? root.targetY - flickable.contentY : 0;

            if (Math.abs(dx) < 0.5 && Math.abs(dy) < 0.5) {
                if (root.canScrollX)
                    flickable.contentX = root.targetX;
                if (root.canScrollY)
                    flickable.contentY = root.targetY;
                if (!idle.running)
                    root.active = false;
                return;
            }

            // Exponential easing off the frame time rather than a fixed step, so
            // the same gesture covers the same ground at 60Hz and at 240Hz
            const t = 1 - Math.exp(-frameTime / root.smoothing);
            if (root.canScrollX)
                flickable.contentX += dx * t;
            if (root.canScrollY)
                flickable.contentY += dy * t;
        }
    }
}
