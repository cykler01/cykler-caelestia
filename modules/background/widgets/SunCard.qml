pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.modules.background

// --- Daylight: the sun's path across the sky today, the day's sunrise and sunset, or both as a
// strip. The times are the weather service's, for wherever the weather is for ---
WidgetCard {
    id: root

    readonly property string style: root.variant === "" ? "arc" : root.variant

    // Minute precision is all this needs, and Time.date already ticks once a minute
    readonly property real now: Time.date.getTime()
    readonly property real rise: Weather.cc ? new Date(Weather.cc.sunrise).getTime() : NaN
    readonly property real set: Weather.cc ? new Date(Weather.cc.sunset).getTime() : NaN
    readonly property bool known: !isNaN(root.rise) && !isNaN(root.set) && root.set > root.rise

    readonly property bool beforeRise: root.known && root.now < root.rise
    readonly property bool afterSet: root.known && root.now >= root.set
    readonly property bool daytime: root.known && !root.beforeRise && !root.afterSet
    // How far through the day's light it is, 0 at sunrise and 1 at sunset
    readonly property real progress: root.known ? Math.max(0, Math.min(1, (root.now - root.rise) / (root.set - root.rise))) : 0

    // "9 h 41 min", or just one of the two when the other is nothing
    function duration(ms: real): string {
        const mins = Math.max(0, Math.round(ms / 60000));
        const h = Math.floor(mins / 60);
        const m = mins % 60;
        if (h > 0 && m > 0)
            return Tr.tr("%1 h %2 min").arg(h).arg(m);
        if (h > 0)
            return Tr.tr("%1 h").arg(h);
        return Tr.tr("%1 min").arg(m);
    }

    // One line on where the day is at, which each style puts under or beside its picture
    readonly property string status: {
        if (!root.known)
            return Tr.tr("No daylight times yet");
        if (root.beforeRise)
            return Tr.tr("Sunrise in %1").arg(root.duration(root.rise - root.now));
        if (root.afterSet)
            return Tr.tr("The sun has set");
        return Tr.tr("%1 left").arg(root.duration(root.set - root.now));
    }

    title: root.style === "arc" ? Tr.tr("Daylight") : ""
    icon: "wb_sunny"
    padding: root.style === "strip" ? Tokens.padding.large : Tokens.padding.largeIncreased

    // The card is created again each time the desktop is uncovered, so only fetch when there is nothing to show
    Component.onCompleted: {
        if (!Weather.cc)
            Weather.reload();
    }

    // Arc: the sun's path drawn as a half-ellipse over the horizon, the part it has covered filled
    // in and the sun sitting where it is now
    Loader {
        Layout.fillWidth: true
        Layout.fillHeight: true
        active: root.style === "arc"
        visible: active

        sourceComponent: ColumnLayout {
            spacing: Tokens.spacing.small

            Canvas {
                id: sky

                Layout.fillWidth: true
                Layout.fillHeight: true

                onPaint: {
                    const ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);

                    const sunR = Math.max(4, height * 0.09);
                    const horizon = height - 2;
                    const cx = width / 2;
                    const rx = width / 2 - sunR - 2;
                    const ry = horizon - sunR * 2;
                    if (rx <= 0 || ry <= 0)
                        return;

                    const point = t => [cx - Math.cos(t * Math.PI) * rx, horizon - Math.sin(t * Math.PI) * ry];

                    // The horizon
                    ctx.strokeStyle = Colours.palette.m3outlineVariant;
                    ctx.lineWidth = 1;
                    ctx.beginPath();
                    ctx.moveTo(0, horizon);
                    ctx.lineTo(width, horizon);
                    ctx.stroke();

                    // The whole path, dashed, so the way still to go reads as a promise
                    ctx.setLineDash([3, 5]);
                    ctx.strokeStyle = Colours.palette.m3outline;
                    ctx.lineWidth = 2;
                    ctx.beginPath();
                    for (let i = 0; i <= 64; i++) {
                        const [x, y] = point(i / 64);
                        if (i === 0)
                            ctx.moveTo(x, y);
                        else
                            ctx.lineTo(x, y);
                    }
                    ctx.stroke();
                    ctx.setLineDash([]);

                    if (!root.known || root.beforeRise)
                        return;

                    // The part already travelled: a wash under it and a solid line along it
                    const steps = Math.max(1, Math.round(64 * root.progress));
                    const grad = ctx.createLinearGradient(0, horizon - ry, 0, horizon);
                    grad.addColorStop(0, Qt.alpha(Colours.palette.m3tertiary, 0.3));
                    grad.addColorStop(1, Qt.alpha(Colours.palette.m3tertiary, 0.02));
                    ctx.fillStyle = grad;
                    ctx.beginPath();
                    ctx.moveTo(point(0)[0], horizon);
                    for (let i = 0; i <= steps; i++) {
                        const [x, y] = point(root.progress * i / steps);
                        ctx.lineTo(x, y);
                    }
                    ctx.lineTo(point(root.progress)[0], horizon);
                    ctx.closePath();
                    ctx.fill();

                    ctx.strokeStyle = Colours.palette.m3tertiary;
                    ctx.lineWidth = 3;
                    ctx.lineCap = "round";
                    ctx.beginPath();
                    for (let i = 0; i <= steps; i++) {
                        const [x, y] = point(root.progress * i / steps);
                        if (i === 0)
                            ctx.moveTo(x, y);
                        else
                            ctx.lineTo(x, y);
                    }
                    ctx.stroke();

                    // The sun, with a halo, while it is up
                    if (root.daytime) {
                        const [sx, sy] = point(root.progress);
                        ctx.fillStyle = Qt.alpha(Colours.palette.m3tertiary, 0.25);
                        ctx.beginPath();
                        ctx.arc(sx, sy, sunR * 1.8, 0, Math.PI * 2);
                        ctx.fill();
                        ctx.fillStyle = Colours.palette.m3tertiary;
                        ctx.beginPath();
                        ctx.arc(sx, sy, sunR, 0, Math.PI * 2);
                        ctx.fill();
                    }
                }

                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()

                Connections {
                    function onProgressChanged(): void {
                        sky.requestPaint();
                    }

                    function onKnownChanged(): void {
                        sky.requestPaint();
                    }

                    function onDaytimeChanged(): void {
                        sky.requestPaint();
                    }

                    target: root
                }

                Connections {
                    function onM3tertiaryChanged(): void {
                        sky.requestPaint();
                    }

                    target: Colours.palette
                }

                // Once the sun is down the arc is empty, so a moon keeps it from looking unfinished
                MaterialIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: parent.height * 0.3
                    visible: root.known && !root.daytime
                    text: "bedtime"
                    fill: 1
                    color: Colours.palette.m3outline
                    fontStyle: Tokens.font.icon.large
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                SunTime {
                    icon: "wb_twilight"
                    time: Weather.sunrise
                }

                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: root.status
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.small
                }

                SunTime {
                    icon: "bedtime"
                    time: Weather.sunset
                    trailing: true
                }
            }
        }
    }

    // Times: sunrise and sunset side by side, and how long the day is under them
    Loader {
        Layout.fillWidth: true
        Layout.fillHeight: true
        active: root.style === "times"
        visible: active

        sourceComponent: ColumnLayout {
            spacing: Tokens.spacing.small

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Tokens.spacing.small
                uniformCellSizes: true

                TimeTile {
                    icon: "wb_twilight"
                    label: Tr.tr("Sunrise")
                    time: Weather.sunrise
                    lit: root.beforeRise
                }

                TimeTile {
                    icon: "bedtime"
                    label: Tr.tr("Sunset")
                    time: Weather.sunset
                    lit: root.daytime
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: Tokens.spacing.extraSmall

                MaterialIcon {
                    text: "hourglass_top"
                    color: Colours.palette.m3primary
                    fontStyle: Tokens.font.icon.small
                }

                StyledText {
                    text: root.known ? Tr.tr("%1 of daylight").arg(root.duration(root.set - root.rise)) : root.status
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.medium
                }
            }
        }
    }

    // Strip: sunrise, a bar the sun travels along, sunset
    Loader {
        Layout.fillWidth: true
        Layout.fillHeight: true
        active: root.style === "strip"
        visible: active

        sourceComponent: RowLayout {
            spacing: Tokens.spacing.small

            SunTime {
                icon: "wb_twilight"
                time: Weather.sunrise
            }

            Item {
                id: track

                Layout.fillWidth: true
                Layout.fillHeight: true

                StyledRect {
                    id: bar

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    implicitHeight: Tokens.padding.small
                    radius: Tokens.rounding.full
                    color: Qt.alpha(Colours.palette.m3outline, 0.35)

                    StyledRect {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: parent.width * root.progress
                        radius: Tokens.rounding.full
                        color: Colours.palette.m3tertiary
                        opacity: root.afterSet ? 0.5 : 1
                    }
                }

                StyledRect {
                    visible: root.daytime
                    x: bar.width * root.progress - width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: Tokens.padding.large
                    implicitHeight: Tokens.padding.large
                    radius: Tokens.rounding.full
                    color: Colours.palette.m3tertiary
                    border.width: 3
                    border.color: Colours.palette.m3surfaceContainer
                }
            }

            SunTime {
                icon: "bedtime"
                time: Weather.sunset
                trailing: true
            }
        }
    }

component SunTime: RowLayout {
    id: sunTime

    property string icon
    property string time
    // On the right-hand end the icon goes after the time, so both ends point outwards
    property bool trailing

    spacing: Tokens.spacing.extraSmall
    layoutDirection: sunTime.trailing ? Qt.RightToLeft : Qt.LeftToRight

    MaterialIcon {
        text: sunTime.icon
        color: Colours.palette.m3tertiary
        fontStyle: Tokens.font.icon.small
    }

    StyledText {
        text: sunTime.time
        color: Colours.palette.m3onSurface
        font: Tokens.font.label.builders.medium.weight(Font.DemiBold).build()
    }
}

component TimeTile: StyledRect {
    id: tile

    property string icon
    property string label
    property string time
    // The one coming up next is picked out
    property bool lit

    Layout.fillWidth: true
    Layout.fillHeight: true
    radius: Tokens.rounding.large
    color: tile.lit ? Colours.palette.m3tertiaryContainer : Colours.palette.m3surfaceContainerHigh

    ColumnLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: Tokens.padding.medium
        spacing: 0

        RowLayout {
            spacing: Tokens.spacing.extraSmall

            MaterialIcon {
                text: tile.icon
                fill: 1
                color: tile.lit ? Colours.palette.m3onTertiaryContainer : Colours.palette.m3tertiary
                fontStyle: Tokens.font.icon.small
            }

            StyledText {
                text: tile.label
                color: tile.lit ? Colours.palette.m3onTertiaryContainer : Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.medium
            }
        }

        StyledText {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: tile.time
            color: tile.lit ? Colours.palette.m3onTertiaryContainer : Colours.palette.m3onSurface
            font: Tokens.font.title.builders.large.weight(Font.DemiBold).build()
        }
    }
}
}
