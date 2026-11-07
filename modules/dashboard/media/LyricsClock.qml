pragma ComponentBehavior: Bound

import QtQuick

// A clock for the lyrics, ticking between the player's own readings.
//
// MPRIS positions only move when the shell asks for one, and the views ask about twice a second:
// enough to move a whole line along, far too little to sweep a word, which would then jump in half
// second steps. So a reading is treated as an anchor and the time between readings is counted here,
// against the system clock.
//
// The rule for a new reading is the part that matters. A reading is a lower bound: the track was at
// least there when it was taken, and is further on by the time it arrives. So one ahead of this
// clock is news and is taken at once, while one behind it is simply an older sample and is ignored;
// the clock then converges on the quickest reading rather than on the mean staleness of all of
// them, which would hold it permanently behind by the round trip. Only a reading a long way behind
// is believed, because that is a seek rather than latency.
QtObject {
    id: root

    required property MediaSource source

    property real anchorPos: 0
    property real anchorAt: 0
    property real position: 0
    // The last value read, so the same number arriving twice can be told from a fresh one.
    property real lastReading: -1
    // A line-timed lyric only changes at the readings themselves, so the clock has nothing to
    // count between them and the timer would be waking thirty times a second for no movement.
    property bool wordTimed: true

    readonly property bool running: root.source.available && root.source.isPlaying && root.wordTimed

    // Named rather than a bare child: a QtObject has no default property for one to go in
    readonly property Timer tick: Timer {
        running: root.running
        repeat: true
        interval: 33
        onTriggered: root.position = root.anchorPos + (Date.now() - root.anchorAt) / 1000
    }

    readonly property Connections conn: Connections {
        function onPositionChanged(): void {
            root.resync(false);
        }

        function onIsPlayingChanged(): void {
            root.resync(true);
        }

        // A new track starts again from zero, which reads as a seek backwards
        function onTitleChanged(): void {
            root.resync(true);
        }

        target: root.source
    }

    function anchor(seconds) {
        root.anchorPos = seconds;
        root.anchorAt = Date.now();
        root.position = seconds;
    }

    function resync(hard) {
        const reading = root.source.position;
        if (!(reading >= 0))
            return;

        if (hard || !root.running) {
            root.lastReading = reading;
            root.anchor(reading);
            return;
        }

        if (Math.abs(reading - root.lastReading) < 0.001)
            return;
        root.lastReading = reading;

        const drift = reading - root.position;
        // Ahead of us, or a long way behind (a seek): believe it.
        if (drift > 0.015 || drift < -1.2)
            root.anchor(reading);
        // Otherwise it is an older sample than the clock already has.
    }

    Component.onCompleted: root.resync(true)
}
