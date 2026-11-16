import QtQuick
import Quickshell.Io

// The screenshots in docs/screenshots, cycled while the install runs.
//
// They are read out of the checkout rather than fetched from GitHub: install.sh
// always runs from a clone of the repo they live in, so they are already on
// disk. That means no network round trip in the middle of an install, nothing
// to fail on a slow connection, and it still works offline.
//
// webp needs qt6-imageformats, which is one of the packages being installed, so
// on a bare machine the images may not decode. Nothing is shown until one has
// actually loaded, and the sky stays up behind until then.
Item {
    id: shots

    required property string dir
    property var files: []
    property int index: 0
    // only once a picture is really on screen does the sky step aside
    readonly property bool ready: front.status === Image.Ready || back.status === Image.Ready

    function show(path: string): void {
        back.source = front.source;
        front.opacity = 0;
        front.source = path === "" ? "" : "file://" + path;
    }

    onIndexChanged: shots.show(shots.files[shots.index] ?? "")

    Process {
        running: true
        command: ["sh", "-c", "ls \"$1\"/*.webp \"$1\"/*.png \"$1\"/*.jpg 2>/dev/null | sort", "sh", shots.dir]

        stdout: StdioCollector {
            onStreamFinished: {
                const list = this.text.split("\n").filter(l => l !== "");
                shots.files = list;
                if (list.length > 0)
                    shots.show(list[0]);
            }
        }
    }

    Timer {
        interval: 9000
        running: shots.files.length > 1
        repeat: true
        onTriggered: shots.index = (shots.index + 1) % shots.files.length
    }

    // the one going out, left underneath so the change is a dissolve rather
    // than a blink through the background
    Image {
        id: back

        anchors.fill: parent
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        cache: false
        sourceSize.width: 1600
        smooth: true
    }

    Image {
        id: front

        anchors.fill: parent
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        cache: false
        sourceSize.width: 1600
        smooth: true
        opacity: 0
        onStatusChanged: {
            if (front.status === Image.Ready)
                front.opacity = 1;
        }

        Behavior on opacity {
            NumberAnimation {
                duration: 600
                easing.type: Easing.InOutQuad
            }
        }
    }
}
