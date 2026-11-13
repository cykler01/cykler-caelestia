pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common
import qs.modules.nexus.pages.weather

// Where the weather comes from. The shell works it out from your IP address unless told otherwise
// (see services/Weather.qml), which is right until you are travelling, on a VPN, or your provider
// places you two counties away - so this sets services.weatherLocation to a fixed point.
//
// Two ways in, because neither covers everything: search knows the name of a place but not which of
// the eleven Springfields you meant, and the map has no idea what anywhere is called but shows you
// exactly where you are pointing. Picking in one moves the other.
PageBase {
    id: root

    // What the picker currently has chosen, as opposed to what is saved. Nothing is written until
    // the Save button, so a stray click on the map does not change your weather
    property real lat
    property real lon
    property bool hasChoice
    // The name looked up for the chosen point, or "" while it is still being fetched
    property string placeName
    property bool lookingUp

    // Whether the map has been put where the weather currently comes from. Once is enough: the
    // service re-reads its location from time to time, and the map should not jump back there
    // while it is being panned around
    property bool centredOnCurrent

    property var searchResults: []
    property bool searching
    property string searchError

    // The location as the config holds it: "lat,lon", a place name, or empty for automatic
    readonly property string saved: GlobalConfig.services.weatherLocation
    readonly property bool savedIsAuto: root.saved === ""
    readonly property string choiceCoords: `${root.lat.toFixed(4)},${root.lon.toFixed(4)}`
    readonly property bool dirty: root.hasChoice && root.choiceCoords !== root.saved

    // Opens on what is already set, so the map starts where you left it rather than at 0°,0°.
    // Coordinates can be shown straight away; a saved place name has none, so that waits for the
    // weather service to resolve it - which usually lands after this page is built, hence the
    // Connections below rather than only a one-off read here
    function centreOnCurrent(): void {
        if (root.centredOnCurrent || root.hasChoice)
            return;

        const current = Weather.loc.split(",");
        if (current.length !== 2)
            return;

        const curLat = parseFloat(current[0]);
        const curLon = parseFloat(current[1]);
        if (!Number.isFinite(curLat) || !Number.isFinite(curLon))
            return;

        // Marked on the map, but not a choice: nothing has been picked, so Save stays off until
        // something is
        map.centreLat = curLat;
        map.centreLon = curLon;
        map.pinLat = curLat;
        map.pinLon = curLon;
        map.hasPin = true;
        root.centredOnCurrent = true;
        if (!root.placeName)
            root.placeName = Weather.city;
    }

    function choose(newLat: real, newLon: real, name: string): void {
        root.lat = newLat;
        root.lon = newLon;
        root.hasChoice = true;
        map.pinLat = newLat;
        map.pinLon = newLon;
        map.hasPin = true;
        map.centreLat = newLat;
        map.centreLon = newLon;

        if (name) {
            root.placeName = name;
            root.lookingUp = false;
        } else {
            root.lookUpName();
        }
    }

    // What the chosen point is called. Nominatim is the same service the weather already reverse
    // geocodes through, asked the same way and identifying itself the same way
    function lookUpName(): void {
        root.placeName = "";
        root.lookingUp = true;

        const lang = Tr.locale.name.split("_")[0] || "en";
        const url = `https://nominatim.openstreetmap.org/reverse?lat=${root.lat}&lon=${root.lon}&format=geocodejson&accept-language=${lang}`;
        const headers = {
            "User-Agent": `caelestia-shell/${CUtils.version} (+https://github.com/caelestia-dots/shell)`
        };

        Requests.get(url, text => {
            root.lookingUp = false;
            try {
                const geo = JSON.parse(text).features?.[0]?.properties?.geocoding;
                if (geo)
                    root.placeName = [geo.city || geo.name, geo.state, geo.country].filter(p => p).join(", ");
            } catch (error) {
                console.warn(lc, `Could not read the reverse lookup: ${error}`);
            }
        }, error => {
            root.lookingUp = false;
            console.warn(lc, `Reverse lookup failed: ${error}`);
        }, headers);
    }

    // Place search, through the same geocoder the weather service uses for a configured city name
    function runSearch(text: string): void {
        const query = text.trim();
        if (query.length < 2) {
            root.searchResults = [];
            root.searchError = "";
            return;
        }

        root.searching = true;
        root.searchError = "";

        const lang = Tr.locale.name.split("_")[0] || "en";
        const url = `https://geocoding-api.open-meteo.com/v1/search?name=${encodeURIComponent(query)}&count=8&language=${lang}&format=json`;

        Requests.get(url, text2 => {
            root.searching = false;
            try {
                const results = JSON.parse(text2).results ?? [];
                root.searchResults = results.map(r => ({
                            name: r.name,
                            detail: [r.admin1, r.country].filter(p => p).join(", "),
                            lat: r.latitude,
                            lon: r.longitude
                        }));
                if (root.searchResults.length === 0)
                    root.searchError = Tr.tr("Nothing found for that name");
            } catch (error) {
                root.searchError = Tr.tr("Could not read the search results");
                console.warn(lc, `Could not read the place search: ${error}`);
            }
        }, error => {
            root.searching = false;
            root.searchError = Tr.tr("Could not reach the place search");
            console.warn(lc, `Place search failed: ${error}`);
        });
    }

    function save(): void {
        GlobalConfig.services.weatherLocation = root.choiceCoords;
        Weather.reload();
    }

    function useAutomatic(): void {
        GlobalConfig.services.weatherLocation = "";
        root.hasChoice = false;
        map.hasPin = false;
        root.placeName = "";
        Weather.reload();
    }

    title: Tr.tr("Weather location")
    isSubPage: true

    Component.onCompleted: {
        const parts = root.saved.split(",");
        if (parts.length === 2) {
            const parsedLat = parseFloat(parts[0]);
            const parsedLon = parseFloat(parts[1]);
            if (Number.isFinite(parsedLat) && Number.isFinite(parsedLon)) {
                root.choose(parsedLat, parsedLon, Weather.city);
                root.centredOnCurrent = true;
                return;
            }
        }

        root.placeName = Weather.city;
        root.centreOnCurrent();

        // Nothing else need have asked for the weather yet - the dashboard's weather tab is what
        // usually does - and without a reading there is nowhere to centre the map
        if (!Weather.loc)
            Weather.reload();
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // Inside the layout rather than beside it: PageBase takes a single Item as its content, so
        // a bare QObject cannot be a child of the page itself
        Connections {
            function onLocChanged(): void {
                root.centreOnCurrent();
            }

            function onCityChanged(): void {
                if (!root.hasChoice)
                    root.placeName = Weather.city;
            }

            target: Weather
        }

        LoggingCategory {
            id: lc

            name: "caelestia.nexus.weatherlocation"
            defaultLogLevel: LoggingCategory.Warning
        }

        SectionHeader {
            first: true
            text: Tr.tr("Find a place")
        }

        ConnectedRect {
            Layout.fillWidth: true
            first: true
            last: root.searchResults.length === 0 && !root.searchError
            implicitHeight: searchRow.implicitHeight + Tokens.padding.medium * 2

            RowLayout {
                id: searchRow

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Tokens.padding.largeIncreased
                anchors.rightMargin: Tokens.padding.medium
                spacing: Tokens.spacing.medium

                MaterialIcon {
                    text: "search"
                    color: Colours.palette.m3onSurfaceVariant
                    fontStyle: Tokens.font.icon.medium
                }

                StyledTextField {
                    id: searchField

                    Layout.fillWidth: true
                    placeholderText: Tr.tr("Town, city or postcode")
                    onAccepted: root.runSearch(text)
                }

                Loader {
                    active: root.searching
                    visible: active

                    sourceComponent: StyledText {
                        text: Tr.tr("Searching…")
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.label.small
                    }
                }

                IconButton {
                    icon: "arrow_forward"
                    type: IconButton.Tonal
                    isRound: true
                    font: Tokens.font.icon.small
                    onClicked: root.runSearch(searchField.text)
                }
            }
        }

        ConnectedRect {
            Layout.fillWidth: true
            last: true
            visible: !!root.searchError && root.searchResults.length === 0
            implicitHeight: errorText.implicitHeight + Tokens.padding.large * 2

            StyledText {
                id: errorText

                anchors.centerIn: parent
                text: root.searchError
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.small
            }
        }

        Repeater {
            model: root.searchResults

            RowButton {
                required property var modelData
                required property int index

                last: index === root.searchResults.length - 1
                icon: "location_on"
                text: modelData.name
                subtext: modelData.detail
                onClicked: {
                    root.choose(modelData.lat, modelData.lon, [modelData.name, modelData.detail].filter(p => p).join(", "));
                    map.zoom = 10;
                }
            }
        }

        SectionHeader {
            text: Tr.tr("Or point at it")
        }

        ConnectedRect {
            id: mapCard

            Layout.fillWidth: true
            first: true
            implicitHeight: Math.round(Math.min(360, root.cappedWidth * 0.62))

            // The tiles are square and Item.clip is rectangular, so the card's rounded corners are
            // cut by a mask instead, the same way the desktop cards shape their blur
            Item {
                id: mapClip

                anchors.fill: parent
                anchors.margins: 1
                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: mapMask
                }

                TileMap {
                    id: map

                    anchors.fill: parent

                    // The page scrolls, and a Flickable takes a drag from whatever is inside it
                    // after a few pixels. Over the map the page stops scrolling, so a drag pans and
                    // the wheel zooms, which is what every map does
                    onHoveredChanged: root.flickable.interactive = !map.hovered

                    onPicked: (pickedLat, pickedLon) => {
                        root.lat = pickedLat;
                        root.lon = pickedLon;
                        root.hasChoice = true;
                        map.pinLat = pickedLat;
                        map.pinLon = pickedLon;
                        map.hasPin = true;
                        root.lookUpName();
                    }
                }
            }

            StyledRect {
                id: mapMask

                anchors.fill: mapClip
                visible: false
                layer.enabled: true
                color: "black"
                topLeftRadius: mapCard.topLeftRadius
                topRightRadius: mapCard.topRightRadius
                bottomLeftRadius: mapCard.bottomLeftRadius
                bottomRightRadius: mapCard.bottomRightRadius
            }

            // Zoom without a scroll wheel, and a reminder that the map is pressable at all
            ColumnLayout {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Tokens.padding.small
                spacing: Tokens.spacing.extraSmall

                IconButton {
                    icon: "add"
                    type: IconButton.Tonal
                    isRound: true
                    font: Tokens.font.icon.small
                    disabled: map.zoom >= map.maxZoom
                    onClicked: map.zoomAt(1, map.width / 2, map.height / 2)
                }

                IconButton {
                    icon: "remove"
                    type: IconButton.Tonal
                    isRound: true
                    font: Tokens.font.icon.small
                    disabled: map.zoom <= map.minZoom
                    onClicked: map.zoomAt(-1, map.width / 2, map.height / 2)
                }
            }
        }

        ConnectedRect {
            Layout.fillWidth: true
            last: true
            implicitHeight: chosen.implicitHeight + Tokens.padding.large * 2

            RowLayout {
                id: chosen

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Tokens.padding.largeIncreased
                anchors.rightMargin: Tokens.padding.largeIncreased
                spacing: Tokens.spacing.medium

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        Layout.fillWidth: true
                        text: {
                            if (!root.hasChoice)
                                return root.savedIsAuto ? Tr.tr("Working it out from your connection") : root.saved;
                            if (root.lookingUp)
                                return Tr.tr("Looking up that place…");
                            return root.placeName || Tr.tr("Unnamed place");
                        }
                        font: Tokens.font.body.medium
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        visible: root.hasChoice
                        // TRANSLATORS: latitude and longitude, already formatted
                        text: Tr.tr("%1, %2").arg(root.lat.toFixed(4)).arg(root.lon.toFixed(4))
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.label.small
                        elide: Text.ElideRight
                    }
                }

                TextButton {
                    type: TextButton.Text
                    visible: !root.savedIsAuto
                    text: Tr.tr("Use my connection")
                    onClicked: root.useAutomatic()
                }

                TextButton {
                    type: TextButton.Filled
                    disabled: !root.dirty
                    text: root.dirty ? Tr.tr("Save") : Tr.tr("Saved")
                    onClicked: root.save()
                }
            }
        }
    }
}
