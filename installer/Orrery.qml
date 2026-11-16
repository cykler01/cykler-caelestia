import QtQuick
import QtQuick.Shapes

// The installer's sky. What you are installing is a system: the shell is the
// star, every switch on the right is a world in orbit around it, and turning one
// off takes that world out of the sky. The install itself is the star drawing
// the system in, traced as an orbit of its own.
//
// Nothing here is decoration only -- the sky is the selection, read a second way.
Item {
    id: orrery

    // the big pieces, one orbit each: orbit 0 is innermost
    required property var bodies
    // the optional feature groups, which share one wide orbit outside the rest
    required property var belt
    // where the belt starts in the shared index space the panel also uses
    required property int beltFrom
    // which tier the panel is on: 0 the system, 1 the belt. Both stay in the
    // sky, but whichever is being chosen comes forward
    required property int stage
    // the body the pointer is on, in either pane, or -1
    required property int focused
    required property bool installing
    // the run stopped short, so the sky says so instead of sitting at whatever
    // percentage it had reached
    required property bool failed
    required property real progress
    required property string phaseText

    // the caption sits in this much room below the system
    readonly property real footHeight: Theme.dp(96)
    readonly property int count: orrery.bodies.length
    readonly property int beltCount: orrery.belt.length
    // the planets keep to the inside, so the belt has somewhere to be
    readonly property real rPlanets: orrery.rOuter * 0.76
    // how far the plane is tipped away: 1 would be face on, 0 edge on
    readonly property real tilt: 0.5
    readonly property real cx: orrery.width / 2
    readonly property real cy: (orrery.height - orrery.footHeight) / 2 + Theme.dp(8)
    readonly property real rOuter: Math.max(Theme.dp(60), Math.min(orrery.width * 0.44, (orrery.height - orrery.footHeight) * 0.44 / orrery.tilt))
    readonly property real rInner: orrery.rOuter * 0.34
    // turns the whole system; each world divides it down by its own orbit
    property real phase
    readonly property int lit: orrery.stage === 1 ? orrery.belt.filter(b => b.on).length : orrery.bodies.filter(b => b.on).length
    readonly property int total: orrery.stage === 1 ? orrery.beltCount : orrery.count
    // the shots are up, so the system steps aside for them
    readonly property bool shotsUp: orrery.installing && shotView.ready
    // the tier being chosen is at full strength, the other recedes. Plain
    // rather than readonly so the Behaviors below can ease them: a Shape's
    // strokeColor has no transition of its own, so these used to snap while the
    // bodies faded, and the two halves of the change disagreed
    property real planetWeight: orrery.shotsUp ? 0 : orrery.stage === 1 ? 0.35 : 1
    property real beltWeight: orrery.shotsUp ? 0 : orrery.stage === 1 ? 1 : 0.5
    // plain, not readonly: the Behavior below needs something it can write to
    property real beltScale: orrery.stage === 1 ? 1.3 : 1
    // whichever of the two lists the pointer is in, or null
    readonly property var here: orrery.focused < 0 ? null : orrery.focused >= orrery.beltFrom ? orrery.belt[orrery.focused - orrery.beltFrom] ?? null : orrery.bodies[orrery.focused] ?? null

    signal bodyEntered(int index)
    signal bodyExited(int index)
    signal bodyToggled(int index)

    function radiusOf(i: int): real {
        if (orrery.count < 2)
            return orrery.rPlanets;
        return orrery.rInner + (orrery.rPlanets - orrery.rInner) * i / (orrery.count - 1);
    }

    // Further out is slower, the way it is in a real system -- but in WHOLE
    // turns per cycle. phase runs 0..360 and wraps; with a fractional speed,
    // phase * speed does not land back where it started, so every body
    // teleported once a cycle. An integer always lands back on itself.
    function speedOf(i: int): int {
        return Math.max(1, orrery.count + 1 - i);
    }

    // The starting angles are scattered rather than evenly stepped. With speeds
    // falling by exactly 1 per orbit AND offsets rising by a fixed step, the
    // difference between any two bodies came out as i * (step - phase) -- which
    // is zero for EVERY body at once when phase reaches the step, stacking all
    // five into the same ray once a cycle. A scattered offset cannot line up
    // that way: measured worst case is 160 degrees of spread, not 0.4
    function angleOf(i: int): real {
        return orrery.phase * orrery.speedOf(i) + orrery.scatter(i, 2) * 360;
    }

    // the belt is the outermost, so one turn a cycle
    function beltAngleOf(i: int): real {
        const spread = orrery.beltCount > 0 ? 360 / orrery.beltCount : 0;
        return orrery.phase + i * spread;
    }

    // a stable scatter, so the stars do not jump about on every repaint
    function scatter(i: int, salt: real): real {
        const x = Math.sin(i * 127.1 + salt * 311.7) * 43758.5453;
        return x - Math.floor(x);
    }

    Behavior on planetWeight {
        NumberAnimation {
            duration: Theme.durLong
            easing.type: Theme.easeStandard
        }
    }

    Behavior on beltWeight {
        NumberAnimation {
            duration: Theme.durLong
            easing.type: Theme.easeStandard
        }
    }

    Behavior on beltScale {
        NumberAnimation {
            duration: Theme.durLong
            easing.type: Theme.easeStandard
        }
    }

    NumberAnimation on phase {
        from: 0
        to: 360
        duration: 120000
        loops: Animation.Infinite
        running: true
    }

    Rectangle {
        id: sky

        anchors.fill: parent
        radius: Theme.shapeXl
        color: Theme.bgSunken
        clip: true

        // deep sky, lifted towards the accent where the star sits. It carries the
        // same radius as the sky: clip only trims a child to the bounding box,
        // not to rounded corners, so a square child pokes out of all four
        Rectangle {
            anchors.fill: parent
            radius: sky.radius
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Theme.alpha(Theme.accent, Theme.isLight ? 0.1 : 0.07)
                }

                GradientStop {
                    position: 0.55
                    color: Theme.alpha(Theme.bgTile, 0.65)
                }

                GradientStop {
                    position: 1
                    color: Theme.alpha(Theme.bgSunken, 0.95)
                }
            }
        }

        // the field the system hangs in
        Repeater {
            model: 70

            Rectangle {
                id: star

                required property int index
                readonly property real s: Theme.dp(1) + orrery.scatter(star.index, 3) * Theme.dp(1.6)

                x: orrery.scatter(star.index, 1) * sky.width
                y: orrery.scatter(star.index, 2) * sky.height
                width: star.s
                height: star.s
                radius: star.s / 2
                color: Theme.text
                opacity: 0.1 + orrery.scatter(star.index, 4) * 0.3
            }
        }

        // a handful breathe, which is enough to make the whole field look alive
        Repeater {
            model: 9

            Rectangle {
                id: twinkler

                required property int index
                readonly property real s: Theme.dp(1.6)

                x: orrery.scatter(twinkler.index, 7) * sky.width
                y: orrery.scatter(twinkler.index, 8) * sky.height
                width: twinkler.s
                height: twinkler.s
                radius: twinkler.s / 2
                color: Theme.text

                SequentialAnimation {
                    running: true
                    loops: Animation.Infinite

                    NumberAnimation {
                        target: twinkler
                        property: "opacity"
                        to: 0.55
                        duration: 1200 + orrery.scatter(twinkler.index, 9) * 1800
                        easing.type: Easing.InOutSine
                    }

                    NumberAnimation {
                        target: twinkler
                        property: "opacity"
                        to: 0.12
                        duration: 1200 + orrery.scatter(twinkler.index, 10) * 1800
                        easing.type: Easing.InOutSine
                    }
                }
            }
        }

        // a cloud off to one side. The sky needs somewhere to recede to, or the
        // whole field reads as flat black behind the system
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            asynchronous: true
            opacity: Theme.isLight ? 0.5 : 1

            ShapePath {
                strokeWidth: 0
                strokeColor: "transparent"
                fillGradient: RadialGradient {
                    centerX: sky.width * 0.78
                    centerY: sky.height * 0.26
                    centerRadius: Math.max(sky.width, sky.height) * 0.45
                    focalX: centerX
                    focalY: centerY

                    GradientStop {
                        position: 0
                        color: Theme.alpha(Theme.success, 0.16)
                    }

                    GradientStop {
                        position: 1
                        color: Theme.alpha(Theme.success, 0)
                    }
                }

                // rounded to match the sky. The cloud is centred up in the top
                // right and reaches well past that corner, so a square path put
                // a hard corner over the rounded one -- clip does not round
                PathRectangle {
                    x: 0
                    y: 0
                    width: sky.width
                    height: sky.height
                    radius: sky.radius
                }
            }
        }

        // the orbits. One Shape each rather than one Shape of many paths: a
        // Repeater only makes Items, and a ShapePath is not one
        Repeater {
            model: orrery.count

            Shape {
                id: ring

                required property int index
                readonly property bool on: orrery.bodies[ring.index]?.on ?? false
                readonly property bool here: orrery.focused === ring.index

                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                asynchronous: true

                ShapePath {
                    fillColor: "transparent"
                    strokeWidth: ring.here ? Theme.dp(1.6) : Theme.dp(1)
                    strokeColor: ring.here ? Theme.alpha(Theme.accent, 0.9) : ring.on ? Theme.alpha(Theme.accent, 0.5 * orrery.planetWeight) : Theme.alpha(Theme.outline, 0.55 * orrery.planetWeight)
                    strokeStyle: ring.on ? ShapePath.SolidLine : ShapePath.DashLine
                    dashPattern: [3, 5]

                    PathAngleArc {
                        centerX: orrery.cx
                        centerY: orrery.cy
                        radiusX: orrery.radiusOf(ring.index)
                        radiusY: orrery.radiusOf(ring.index) * orrery.tilt
                        startAngle: 0
                        sweepAngle: 360
                    }
                }
            }
        }

        // the belt's own orbit, drawn whole however many of its bodies are lit
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            asynchronous: true
            visible: orrery.beltCount > 0

            ShapePath {
                fillColor: "transparent"
                strokeWidth: Theme.dp(1) + Theme.dp(0.8) * (orrery.beltWeight - 0.5)
                strokeColor: Theme.alpha(Theme.accent, 0.18 + 0.64 * (orrery.beltWeight - 0.5))

                PathAngleArc {
                    centerX: orrery.cx
                    centerY: orrery.cy
                    radiusX: orrery.rOuter
                    radiusY: orrery.rOuter * orrery.tilt
                    startAngle: 0
                    sweepAngle: 360
                }
            }
        }

        // the star: the shell itself, which everything else is in orbit around
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            asynchronous: true
            opacity: orrery.shotsUp ? 0 : 1

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.durLong
                }
            }

            ShapePath {
                strokeWidth: 0
                strokeColor: "transparent"
                fillGradient: RadialGradient {
                    centerX: orrery.cx
                    centerY: orrery.cy
                    centerRadius: Theme.dp(96) * (orrery.installing ? 1 + orrery.progress * 0.85 : 1)
                    focalX: centerX
                    focalY: centerY

                    GradientStop {
                        position: 0
                        color: Theme.alpha(orrery.failed ? Theme.error : Theme.accent, 0.42)
                    }

                    GradientStop {
                        position: 0.45
                        color: Theme.alpha(orrery.failed ? Theme.error : Theme.accent, 0.12)
                    }

                    GradientStop {
                        position: 1
                        color: Theme.alpha(orrery.failed ? Theme.error : Theme.accent, 0)
                    }
                }

                PathAngleArc {
                    centerX: orrery.cx
                    centerY: orrery.cy
                    radiusX: Theme.dp(120)
                    radiusY: Theme.dp(120)
                    startAngle: 0
                    sweepAngle: 360
                }
            }
        }

        // the star is the shell's own mark, in its own colours. A disc would have
        // done, but the thing at the centre of this system is the shell itself
        Logo {
            id: core

            readonly property real d: Theme.dp(86)
            // The breathing drives a property of its own. An animation that
            // wrote straight to opacity would replace the binding below, and the
            // star would then never fade out of the way of the shots
            property real pulse: 1

            x: orrery.cx - width / 2
            y: orrery.cy - height / 2
            width: core.d
            height: core.d
            scale: orrery.installing ? 1 + orrery.progress * 0.22 : 1
            z: 1
            opacity: (orrery.shotsUp ? 0 : 1) * core.pulse

            Behavior on scale {
                NumberAnimation {
                    duration: Theme.durLong
                    easing.type: Theme.easeStandard
                }
            }

            SequentialAnimation {
                running: true
                loops: Animation.Infinite

                NumberAnimation {
                    target: core
                    property: "pulse"
                    to: 0.78
                    duration: 2600
                    easing.type: Easing.InOutSine
                }

                NumberAnimation {
                    target: core
                    property: "pulse"
                    to: 1
                    duration: 2600
                    easing.type: Easing.InOutSine
                }
            }
        }

        // the worlds
        Repeater {
            model: orrery.count

            Item {
                id: world

                required property int index
                readonly property var body: orrery.bodies[world.index] ?? null
                readonly property bool on: world.body?.on ?? false
                readonly property bool here: orrery.focused === world.index
                readonly property real a: orrery.angleOf(world.index) * Math.PI / 180
                readonly property real r: orrery.radiusOf(world.index)
                // behind the star for half of every turn, which is what sells the plane
                readonly property real depth: Math.sin(world.a)
                // Icon is a Text with variable axes, and one of them is opsz, so a
                // pixelSize that follows the orbit re-instances the font and
                // re-rasterises its glyphs on every frame. The size only moves when
                // the state does; the breathing is a transform, which is free
                readonly property real d: world.on ? Theme.dp(38) : Theme.dp(24)
                readonly property real lean: (0.82 + 0.18 * world.depth) * (world.here ? 1.22 : 1)

                x: orrery.cx + world.r * Math.cos(world.a) - width / 2
                y: orrery.cy + world.r * orrery.tilt * world.depth - height / 2
                z: world.depth > 0 ? 2 : 0
                width: world.d
                height: world.d
                scale: world.lean
                opacity: (world.on ? 1 : 0.8) * orrery.planetWeight

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.durLong
                    }
                }

                // a required piece is ringed rather than switched: it is in the sky
                // whatever you do, and the ring is what says so
                Rectangle {
                    anchors.centerIn: parent
                    visible: world.body?.required ?? false
                    width: parent.width + Theme.dp(9)
                    height: width
                    radius: width / 2
                    color: "transparent"
                    border.width: Theme.dp(1)
                    border.color: Theme.alpha(Theme.accent, 0.45)
                }

                // the halo that marks whichever world the pointer is on, in either pane
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width + Theme.dp(14)
                    height: width
                    radius: width / 2
                    color: "transparent"
                    border.width: Theme.dp(1.5)
                    border.color: Theme.alpha(Theme.accent, 0.7)
                    opacity: world.here ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.durShort
                        }
                    }
                }

                Rectangle {
                    id: globe

                    anchors.fill: parent
                    radius: width / 2
                    color: world.on ? Theme.accent : Theme.alpha(Theme.bgHigh, 0.95)
                    border.width: world.on ? 0 : Theme.dp(1.5)
                    border.color: Theme.alpha(Theme.outline, 0.9)

                    Icon {
                        anchors.centerIn: parent
                        name: world.body?.icon ?? "circle"
                        size: world.d * 0.46
                        fill: world.on ? 1 : 0
                        color: world.on ? Theme.onAccent : Theme.subtextDim
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -Theme.dp(6)
                    enabled: orrery.stage === 0
                    hoverEnabled: true
                    cursorShape: world.body?.locked ? Qt.ArrowCursor : Qt.PointingHandCursor
                    onEntered: orrery.bodyEntered(world.index)
                    onExited: orrery.bodyExited(world.index)
                    onClicked: orrery.bodyToggled(world.index)
                }
            }
        }

        // the belt: the optional groups, smaller and packed, the way a belt is
        Repeater {
            model: orrery.beltCount

            Item {
                id: rock

                required property int index
                readonly property var body: orrery.belt[rock.index] ?? null
                readonly property bool on: rock.body?.on ?? false
                readonly property bool here: orrery.focused === orrery.beltFrom + rock.index
                readonly property real a: orrery.beltAngleOf(rock.index) * Math.PI / 180
                readonly property real depth: Math.sin(rock.a)
                readonly property real d: rock.on ? Theme.dp(24) : Theme.dp(18)
                readonly property real lean: orrery.beltScale * (0.82 + 0.18 * rock.depth) * (rock.here ? 1.35 : 1)

                x: orrery.cx + orrery.rOuter * Math.cos(rock.a) - width / 2
                y: orrery.cy + orrery.rOuter * orrery.tilt * rock.depth - height / 2
                z: rock.depth > 0 ? 3 : 0
                width: rock.d
                height: rock.d
                scale: rock.lean
                opacity: (rock.on ? 1 : 0.75) * orrery.beltWeight

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.durLong
                    }
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width + Theme.dp(12)
                    height: width
                    radius: width / 2
                    color: "transparent"
                    border.width: Theme.dp(1.5)
                    border.color: Theme.alpha(Theme.accent, 0.7)
                    opacity: rock.here ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.durShort
                        }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: rock.on ? Theme.accent : Theme.alpha(Theme.bgHigh, 0.95)
                    border.width: rock.on ? 0 : Theme.dp(1.2)
                    border.color: Theme.alpha(Theme.outline, 0.9)

                    Icon {
                        anchors.centerIn: parent
                        name: rock.body?.icon ?? "circle"
                        size: rock.d * 0.5
                        fill: rock.on ? 1 : 0
                        color: rock.on ? Theme.onAccent : Theme.subtextDim
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -Theme.dp(5)
                    enabled: orrery.stage === 1
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: orrery.bodyEntered(orrery.beltFrom + rock.index)
                    onExited: orrery.bodyExited(orrery.beltFrom + rock.index)
                    onClicked: orrery.bodyToggled(orrery.beltFrom + rock.index)
                }
            }
        }

        Shots {
            id: shotView

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: Theme.dp(26)
            anchors.bottomMargin: orrery.footHeight
            dir: Qt.resolvedUrl("../docs/screenshots").toString().replace("file://", "")
            opacity: orrery.shotsUp ? 1 : 0
            visible: opacity > 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.durLong
                }
            }
        }

        // what the sky is saying, which is the world under the pointer when there
        // is one and the shape of the whole system when there is not
        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Theme.dp(32)
            spacing: Theme.dp(6)

            Text {
                text: orrery.installing ? orrery.phaseText : orrery.here ? orrery.here.label : orrery.stage === 1 ? "Features" : "Your system"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontTitleLg
                font.variableAxes: Theme.axes(Theme.fontTitleLg, 560, 0)
            }

            Text {
                width: parent.width
                text: orrery.failed ? "It stopped part way. The log says where." : orrery.here ? orrery.here.sub : ""
                visible: text !== ""
                color: orrery.failed ? Theme.error : Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontBodyMd
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            Item {
                width: 1
                height: Theme.dp(10)
            }

            // how far through, in the room the arc used to take up
            Row {
                width: parent.width
                spacing: Theme.dp(10)
                visible: orrery.installing

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - Theme.dp(56)
                    height: Theme.dp(6)
                    radius: height / 2
                    color: Theme.alpha(Theme.outline, 0.5)

                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(1, orrery.progress))
                        height: parent.height
                        radius: height / 2
                        color: orrery.failed ? Theme.error : Theme.accent

                        Behavior on width {
                            NumberAnimation {
                                duration: Theme.durLong
                                easing.type: Theme.easeStandard
                            }
                        }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(orrery.progress * 100) + "%"
                    color: orrery.failed ? Theme.error : Theme.subtext
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontBodySm
                }
            }

            // one pip per orbit, lit for what is coming: the page dots, but saying
            // something
            Row {
                spacing: Theme.dp(6)
                visible: !orrery.installing

                Repeater {
                    model: orrery.total

                    Rectangle {
                        id: pip

                        required property int index
                        readonly property int at: (orrery.stage === 1 ? orrery.beltFrom : 0) + pip.index
                        readonly property bool on: (orrery.stage === 1 ? orrery.belt[pip.index] : orrery.bodies[pip.index])?.on ?? false

                        width: orrery.focused === pip.at ? Theme.dp(22) : Theme.dp(6)
                        height: Theme.dp(6)
                        radius: height / 2
                        color: pip.on ? Theme.accent : Theme.outline

                        Behavior on width {
                            NumberAnimation {
                                duration: Theme.durShort
                                easing.type: Theme.easeStandard
                            }
                        }
                    }
                }
            }
        }
    }
}
