import QtQuick

MouseArea {
    property int scrollAccumulated: 0

    function onWheel(event: WheelEvent): void {
    }

    onWheel: event => {
        // A notch arrives on one axis or the other: vertical for a mouse wheel, sideways for a two
        // finger trackpad swipe, and some touchpads only fill in pixelDelta (which is counted in
        // eighths of a degree here, 120 to a notch, the same scale as the angle). Accumulating
        // whichever axis carried the event keeps the gate below working for both, so a handler
        // that reads the other axis still gets called. Handlers that only look at angleDelta.y
        // are unaffected, since a vertical wheel still accumulates exactly as before.
        let delta = event.angleDelta.y;
        if (delta === 0)
            delta = event.angleDelta.x;
        if (delta === 0)
            delta = (event.pixelDelta.y + event.pixelDelta.x) * 8;

        // Update accumulated scroll
        if (Math.sign(delta) !== Math.sign(scrollAccumulated))
            scrollAccumulated = 0;
        scrollAccumulated += delta;

        // Trigger handler and reset if above threshold
        if (Math.abs(scrollAccumulated) >= 120) {
            onWheel(event);
            scrollAccumulated = 0;
        }
    }
}
