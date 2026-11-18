pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.dashboard.media

// An invisible strip laid over a media widget's progress bar that seeks the track: click or drag along
// it to jump there, or scroll over it to step back and forth. The bar under it is too thin to aim at,
// so this reaches past it above and below (see the margins where it is placed).
//
// While a drag or a scroll is in progress the bar should show where the track is going rather than
// where it is, so the host binds its bar to `shown` instead of its own progress. A scroll is only sent
// to the player once the wheel has settled, so a trackpad's stream of small events turns into one seek
// rather than dozens.
MouseArea {
    id: root

    required property MediaSource source
    // The bar's own value, 0 to 1, shown whenever nothing is being dragged or scrolled
    required property real progress
    // Seconds one wheel notch moves the track
    property real step: 5

    // Where the track is being moved to, 0 to 1, or -1 when nothing is in progress
    property real preview: -1
    readonly property real shown: root.preview >= 0 ? root.preview : root.progress
    // Seconds the scroll has got to so far, -1 when no scroll is pending
    property real pending: -1

    readonly property real length: root.source.length
    readonly property bool canSeek: root.source.available && root.source.canSeek && root.length > 0 && root.length < 2147483647

    function fractionAt(x: real): real {
        return Math.max(0, Math.min(1, x / Math.max(1, root.width)));
    }

    function commit(seconds: real): void {
        root.source.seek(Math.max(0, Math.min(root.length - 1, seconds)));
        root.source.refresh();
    }

    // Off when the player can't seek, so the press and the wheel fall through to whatever is under it
    enabled: root.canSeek
    hoverEnabled: true
    preventStealing: true
    cursorShape: Qt.PointingHandCursor

    onPressed: mouse => {
        settle.stop();
        root.pending = -1;
        root.preview = root.fractionAt(mouse.x);
    }
    onPositionChanged: mouse => {
        if (root.pressed)
            root.preview = root.fractionAt(mouse.x);
    }
    onReleased: {
        if (root.preview >= 0)
            root.commit(root.preview * root.length);
        root.preview = -1;
    }
    onCanceled: root.preview = -1

    onWheel: wheel => {
        // Up or right moves forward. A mouse wheel notch is 120; a trackpad sends fractions of that
        const delta = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : -wheel.angleDelta.x;
        if (delta === 0)
            return;

        const from = root.pending >= 0 ? root.pending : root.source.position;
        root.pending = Math.max(0, Math.min(root.length - 1, from + root.step * delta / 120));
        root.preview = root.pending / root.length;
        settle.restart();
    }

    Timer {
        id: settle

        interval: 250
        onTriggered: {
            if (root.pending >= 0)
                root.commit(root.pending);
            root.pending = -1;
            root.preview = -1;
        }
    }
}
