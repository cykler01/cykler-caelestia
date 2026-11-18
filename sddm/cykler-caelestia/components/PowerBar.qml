import QtQuick

// the ways out, each destructive one asking once before it takes them.
//
// NOTE(fork): the first cut grew each button into its own label, which moved
// every button beside it and shifted the whole bar under the pointer -- a
// hover that could knock itself off the thing being hovered. the bar is one
// fixed size now: the buttons never move, and the one label floats above it,
// sliding from button to button. the question, when there is one, is asked in
// that same place rather than by widening the bar
Rectangle {
    id: bar

    property string pending: ""
    readonly property int morphMs: Theme.ms(380)
    readonly property var pendingAction: {
        for (var i = 0; i < Lock.powerActions.length; i++) {
            if (Lock.powerActions[i].id === bar.pending)
                return Lock.powerActions[i];

        }
        return null;
    }
    // the action under the pointer, and where its middle is, in bar coords
    property var hovered: null
    property real hoverCentre: 0

    function choose(a) {
        if (a.confirm) {
            bar.pending = a.id;
            recant.restart();
            return ;
        }
        Lock.runPower(a.id);
    }

    // 0 showing the ways out, 1 asking about one of them
    property real morph: bar.pending !== "" ? 1 : 0

    height: Theme.dp(60)
    radius: Theme.dp(999)
    color: Theme.card
    // the resting size is the whole bar's size: only a question that cannot
    // fit inside it is allowed to stretch it, and only while it is asked
    width: Math.max(actions.implicitWidth + Theme.dp(24), bar.pending !== "" ? confirm.implicitWidth + Theme.dp(16) : 0)
    // the greeter dims and disables this while the field has the screen; a
    // question left hanging there is withdrawn
    onEnabledChanged: {
        if (!bar.enabled)
            bar.pending = "";

    }

    // a question nobody answers is a question withdrawn
    Timer {
        id: recant

        interval: 7000
        onTriggered: bar.pending = ""
    }

    Behavior on morph {
        NumberAnimation {
            duration: bar.morphMs
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.easeEmphasizedDecel
        }

    }

    Behavior on width {
        NumberAnimation {
            duration: bar.morphMs
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.easeEmphasizedDecel
        }

    }

    // a round button that stays exactly where it is. the glyph lights and the
    // state layer fills under it; the name of the thing is said by the label
    // above the bar
    component PowerButton: Item {
        id: pb

        required property var action
        readonly property bool hot: hover.hovered
        readonly property bool danger: pb.action.id === "shutdown"
        readonly property color tone: pb.danger ? Theme.error : Theme.text
        readonly property color rest: pb.danger ? Theme.alpha(Theme.error, 0.85) : Theme.subtext

        width: Theme.dp(48)
        height: Theme.dp(48)
        scale: tap.pressed ? 0.92 : 1

        onHotChanged: {
            if (pb.hot) {
                bar.hovered = pb.action;
                bar.hoverCentre = pb.mapToItem(bar, pb.width / 2, 0).x;
            } else if (bar.hovered === pb.action) {
                bar.hovered = null;
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: Theme.ms(110)
                easing.type: Easing.OutCubic
            }

        }

        Rectangle {
            anchors.fill: parent
            radius: Theme.dp(999)
            color: pb.danger ? Theme.error : Theme.text
            opacity: tap.pressed ? (pb.danger ? 0.24 : Theme.statePressed + 0.04) : (pb.hot ? (pb.danger ? 0.18 : 0.12) : 0)

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.ms(140)
                    easing.type: Easing.OutCubic
                }

            }

        }

        Glyph {
            anchors.centerIn: parent
            name: pb.action.glyph
            size: Theme.dp(21)
            color: pb.hot ? pb.tone : pb.rest

            Behavior on color {
                ColorAnimation {
                    duration: Theme.ms(140)
                }

            }

        }

        HoverHandler {
            id: hover

            // a pointer handler ignores Item.enabled unless told to
            enabled: pb.enabled
            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            id: tap

            onTapped: bar.choose(pb.action)
        }

    }

    Row {
        id: actions

        anchors.centerIn: parent
        spacing: Theme.dp(4)
        opacity: Math.max(0, 1 - bar.morph * 2.5)
        visible: opacity > 0.01

        Repeater {
            model: Lock.powerActions

            PowerButton {
                required property var modelData

                action: modelData
            }

        }

    }

    Row {
        id: confirm

        anchors.centerIn: parent
        spacing: Theme.dp(8)
        opacity: Math.max(0, (bar.morph - 0.45) / 0.55)
        visible: opacity > 0.01

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: cancelText.implicitWidth + Theme.dp(32)
            height: Theme.dp(44)
            radius: Theme.dp(999)
            color: Theme.alpha(Theme.text, cancelTap.pressed ? Theme.statePressed + 0.04 : (cancelHover.hovered ? 0.12 : 0.06))

            Behavior on color {
                ColorAnimation {
                    duration: Theme.ms(140)
                }

            }

            Text {
                id: cancelText

                anchors.centerIn: parent
                text: "Cancel"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLabelLg
                font.variableAxes: Theme.axes(Theme.fontLabelLg, 520, 0)
                font.weight: Font.Medium
            }

            HoverHandler {
                id: cancelHover

                enabled: bar.enabled
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                id: cancelTap

                onTapped: bar.pending = ""
            }

        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: goRow.implicitWidth + Theme.dp(34)
            height: Theme.dp(44)
            radius: Theme.dp(999)
            color: goHover.hovered ? Theme.errorHover : Theme.error
            scale: goTap.pressed ? 0.94 : 1

            Behavior on scale {
                NumberAnimation {
                    duration: Theme.ms(110)
                    easing.type: Easing.OutCubic
                }

            }

            Row {
                id: goRow

                anchors.centerIn: parent
                spacing: Theme.dp(8)

                Glyph {
                    anchors.verticalCenter: parent.verticalCenter
                    name: bar.pendingAction ? bar.pendingAction.glyph : "power"
                    size: Theme.dp(19)
                    color: Theme.fgError
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: bar.pendingAction ? bar.pendingAction.label : ""
                    color: Theme.fgError
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontLabelLg
                    font.variableAxes: Theme.axes(Theme.fontLabelLg, 520, 0)
                    font.weight: Font.Medium
                }

            }

            HoverHandler {
                id: goHover

                enabled: bar.enabled
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                id: goTap

                onTapped: {
                    var id = bar.pending;
                    bar.pending = "";
                    Lock.runPower(id);
                }
            }

        }

    }

    // the one label, floating over the bar rather than inside it: it slides
    // from button to button while the pointer walks the row, and stands in the
    // middle to ask about the one that needs asking
    Rectangle {
        id: tip

        readonly property bool asking: bar.pending !== ""
        readonly property var action: tip.asking ? bar.pendingAction : bar.hovered
        readonly property string label: tip.action ? tip.action.label + (tip.asking ? "?" : "") : ""
        readonly property bool on: tip.label !== "" && bar.enabled
        // what it last said, kept while it fades out so the pill does not
        // empty itself on the way
        property string held: ""
        property bool heldDanger: false
        readonly property color tone: tip.heldDanger ? Theme.error : Theme.text

        onLabelChanged: {
            if (tip.label === "")
                return ;

            tip.held = tip.label;
            tip.heldDanger = tip.action.id === "shutdown";
        }
        width: tipText.implicitWidth + Theme.dp(26)
        height: Theme.dp(32)
        radius: Theme.dp(999)
        color: Theme.card
        y: -height - Theme.dp(10)
        // centred on what is hovered, kept inside the bar's own width, and in
        // the middle of it while a question stands
        x: tip.asking ? (bar.width - tip.width) / 2 : Math.max(0, Math.min(bar.width - tip.width, bar.hoverCentre - tip.width / 2))
        opacity: tip.on ? 1 : 0
        scale: 0.94 + 0.06 * opacity
        visible: opacity > 0.01

        // while it is out of sight it jumps to wherever it is next needed; the
        // slide is only for a walk from one button to the next
        Behavior on x {
            enabled: tip.opacity > 0.2

            NumberAnimation {
                duration: Theme.ms(260)
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.easeEmphasizedDecel
            }

        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.ms(150)
                easing.type: Easing.OutCubic
            }

        }

        Text {
            id: tipText

            anchors.centerIn: parent
            text: tip.held
            color: tip.tone
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontLabelLg
            font.variableAxes: Theme.axes(Theme.fontLabelLg, 520, 0)
            font.weight: Font.Medium

            Behavior on color {
                ColorAnimation {
                    duration: Theme.ms(140)
                }

            }

        }

    }

}
