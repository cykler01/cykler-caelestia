pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia
import Caelestia.Config
import qs.components
import qs.services
import qs.utils

// A slippy map built out of OpenStreetMap raster tiles. Qt's own Map type lives in QtLocation,
// which is not a dependency of the shell (only QtPositioning is installed), so rather than add one
// for a single settings page the tiles are laid out by hand: it is a grid of 256px Images at
// whole-number offsets, which is all a slippy map is.
//
// Zoom is capped deliberately low. Picking the town the weather comes from does not need street
// level detail, and every zoom step doubles the tiles asked of a volunteer-run tile server.
//
// The tiles are downloaded by assets/fetch-tile.sh rather than loaded straight into the Images,
// because OpenStreetMap's usage policy wants a User-Agent naming the application and Qt's image
// loader sends its own - ask it directly and every tile comes back as an "Access blocked" 418.
// The script caches to disk, so a tile is only ever fetched once.
Item {
    id: root

    readonly property string cacheDir: `${Paths.cache}/maptiles`
    readonly property string fetchScript: `${Quickshell.shellDir}/assets/fetch-tile.sh`
    // Tiles already on disk this session, so panning back over somewhere does not start a process
    // per tile just to have it find the file and exit
    readonly property var fetched: new Set()

    // Where the view is centred, in degrees
    property real centreLat: 51.5
    property real centreLon: -0.12
    property int zoom: 9

    readonly property int minZoom: 2
    readonly property int maxZoom: 12
    readonly property int tileSize: 256

    // The pin, in degrees. Negative latitude is a valid place, so a separate flag says whether one
    // has been dropped at all
    property real pinLat: 0
    property real pinLon: 0
    property bool hasPin

    readonly property int scaleTiles: Math.pow(2, root.zoom)
    // The centre in world pixels: the whole map at this zoom is scaleTiles * tileSize across
    readonly property real centreX: root.lonToTileX(root.centreLon, root.zoom) * root.tileSize
    readonly property real centreY: root.latToTileY(root.centreLat, root.zoom) * root.tileSize
    readonly property real originX: root.centreX - root.width / 2
    readonly property real originY: root.centreY - root.height / 2

    // Which tiles the viewport covers. Rebuilt whenever the view moves, which is what the Repeater
    // below draws
    readonly property var tiles: {
        const first = Math.floor(root.originX / root.tileSize);
        const last = Math.floor((root.originX + root.width) / root.tileSize);
        const top = Math.floor(root.originY / root.tileSize);
        const bottom = Math.floor((root.originY + root.height) / root.tileSize);

        const out = [];
        for (let ty = top; ty <= bottom; ty++) {
            // There is no map above the north pole or below the south one, so those rows are left
            // blank rather than wrapped round like longitude is
            if (ty < 0 || ty >= root.scaleTiles)
                continue;
            for (let tx = first; tx <= last; tx++)
                out.push({
                    tx,
                    ty,
                    // The date line is a seam, not an edge: panning past it carries on into the
                    // other side of the world
                    wrapped: ((tx % root.scaleTiles) + root.scaleTiles) % root.scaleTiles
                });
        }
        return out;
    }

    // Emitted when a point on the map is chosen, as opposed to the view merely being moved
    signal picked(real lat, real lon)

    // Web Mercator, the projection every slippy map uses
    function lonToTileX(lon: real, z: int): real {
        return (lon + 180) / 360 * Math.pow(2, z);
    }

    function latToTileY(lat: real, z: int): real {
        const clamped = Math.max(-85.05112878, Math.min(85.05112878, lat));
        const rad = clamped * Math.PI / 180;
        return (1 - Math.log(Math.tan(rad) + 1 / Math.cos(rad)) / Math.PI) / 2 * Math.pow(2, z);
    }

    function tileXToLon(x: real, z: int): real {
        return x / Math.pow(2, z) * 360 - 180;
    }

    function tileYToLat(y: real, z: int): real {
        const n = Math.PI - 2 * Math.PI * y / Math.pow(2, z);
        return 180 / Math.PI * Math.atan(0.5 * (Math.exp(n) - Math.exp(-n)));
    }

    // A point in the view, in degrees
    function latAt(viewY: real): real {
        return root.tileYToLat((root.originY + viewY) / root.tileSize, root.zoom);
    }

    function lonAt(viewX: real): real {
        const lon = root.tileXToLon((root.originX + viewX) / root.tileSize, root.zoom);
        // Panning across the date line several times would otherwise run the longitude off to
        // ±540 and beyond
        return ((lon + 180) % 360 + 360) % 360 - 180;
    }

    // Where a point in degrees sits in the view. Off-screen values are fine; the pin is simply
    // clipped when the place it marks has been panned away from
    function viewXOf(lon: real): real {
        return root.lonToTileX(lon, root.zoom) * root.tileSize - root.originX;
    }

    function viewYOf(lat: real): real {
        return root.latToTileY(lat, root.zoom) * root.tileSize - root.originY;
    }

    function panBy(dx: real, dy: real): void {
        root.centreLat = root.tileYToLat((root.centreY + dy) / root.tileSize, root.zoom);
        root.centreLon = root.lonAt(root.width / 2 + dx);
    }

    // Zooms about a point in the view, so the place under the cursor stays under it
    function zoomAt(step: int, viewX: real, viewY: real): void {
        const next = Math.max(root.minZoom, Math.min(root.maxZoom, root.zoom + step));
        if (next === root.zoom)
            return;

        const lat = root.latAt(viewY);
        const lon = root.lonAt(viewX);
        root.zoom = next;

        // Put that same point back where the cursor is
        const offX = viewX - root.width / 2;
        const offY = viewY - root.height / 2;
        root.centreLat = root.tileYToLat(root.latToTileY(lat, next) - offY / root.tileSize, next);
        root.centreLon = root.tileXToLon(root.lonToTileX(lon, next) - offX / root.tileSize, next);
    }

    clip: true

    Rectangle {
        anchors.fill: parent
        color: Colours.palette.m3surfaceContainerHighest
    }

    Repeater {
        model: root.tiles

        Item {
            id: tile

            required property var modelData

            readonly property string key: `${root.zoom}/${tile.modelData.wrapped}/${tile.modelData.ty}`
            readonly property url fileUrl: `file://${root.cacheDir}/${tile.key}.png`

            x: tile.modelData.tx * root.tileSize - root.originX
            y: tile.modelData.ty * root.tileSize - root.originY
            width: root.tileSize
            height: root.tileSize

            Component.onCompleted: {
                if (root.fetched.has(tile.key))
                    image.source = tile.fileUrl;
                else
                    fetch.running = true;
            }

            Image {
                id: image

                anchors.fill: parent
                asynchronous: true
                cache: true
                smooth: true
                sourceSize.width: root.tileSize
                sourceSize.height: root.tileSize
            }

            Process {
                id: fetch

                command: ["bash", root.fetchScript, root.cacheDir, String(root.zoom), String(tile.modelData.wrapped), String(tile.modelData.ty), CUtils.version]

                onExited: code => {
                    if (code !== 0)
                        return;
                    root.fetched.add(tile.key);
                    image.source = tile.fileUrl;
                }
            }
        }
    }

    MouseArea {
        id: dragger

        // Where the press started and how far it has moved, so a drag can be told from a tap: a
        // pan should move the view, not drop the pin wherever it let go
        property real lastX
        property real lastY
        property real travelled

        anchors.fill: parent
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        acceptedButtons: Qt.LeftButton

        onPressed: mouse => {
            lastX = mouse.x;
            lastY = mouse.y;
            travelled = 0;
        }

        onPositionChanged: mouse => {
            const dx = mouse.x - lastX;
            const dy = mouse.y - lastY;
            lastX = mouse.x;
            lastY = mouse.y;
            travelled += Math.abs(dx) + Math.abs(dy);
            root.panBy(-dx, -dy);
        }

        onClicked: mouse => {
            if (dragger.travelled > 6)
                return;
            root.picked(root.latAt(mouse.y), root.lonAt(mouse.x));
        }

        onWheel: wheel => root.zoomAt(wheel.angleDelta.y > 0 ? 1 : -1, wheel.x, wheel.y)
    }

    // The chosen place. Drawn as a teardrop sitting on the point rather than centred over it, so
    // the tip marks the spot
    Item {
        visible: root.hasPin
        x: root.viewXOf(root.pinLon)
        y: root.viewYOf(root.pinLat)

        StyledRect {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.top
            implicitWidth: 22
            implicitHeight: 22
            radius: Tokens.rounding.full
            color: Colours.palette.m3primary
            border.width: 2
            border.color: Colours.palette.m3onPrimary

            MaterialIcon {
                anchors.centerIn: parent
                text: "place"
                color: Colours.palette.m3onPrimary
                fontStyle: Tokens.font.icon.small
                fill: 1
            }
        }

        // The point itself, under the marker
        Rectangle {
            anchors.centerIn: parent
            implicitWidth: 6
            implicitHeight: 6
            radius: width / 2
            color: Colours.palette.m3primary
            border.width: 1
            border.color: Colours.palette.m3onPrimary
        }
    }

    // OpenStreetMap's licence asks for this wherever its tiles are shown
    StyledRect {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        implicitWidth: attribution.implicitWidth + Tokens.padding.small * 2
        implicitHeight: attribution.implicitHeight + Tokens.padding.extraSmall * 2
        topLeftRadius: Tokens.rounding.small
        color: Qt.alpha(Colours.palette.m3surface, 0.75)

        StyledText {
            id: attribution

            anchors.centerIn: parent
            text: "© OpenStreetMap"
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.label.small
        }
    }
}
