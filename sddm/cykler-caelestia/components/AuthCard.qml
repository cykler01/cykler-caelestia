import QtQuick

// who is being asked, the field they answer in, and the one line that tells
// them how it went. picking another account turns the card over to a sheet
// that pushes in from the side, then pushes back out again; the session, a
// list of two or three, opens as a menu standing on its own pill
Rectangle {
    id: card

    // 0 the question, 1 a sheet laid over it
    property real k: Lock.sheet !== "" ? 1 : 0
    // the ring only follows the keyboard, never the pointer
    property bool kbd: false
    readonly property string layoutShort: {
        if (!keyboard.layouts || keyboard.layouts.length === 0)
            return "";

        var l = keyboard.layouts[keyboard.currentLayout];
        if (!l)
            return "";

        var t = l.shortName !== undefined && l.shortName !== "" ? l.shortName : l.longName;
        return t === undefined ? "" : String(t).substring(0, 6).toUpperCase();
    }
    readonly property bool hasStatus: Lock.statusText !== "" || card.layoutShort !== "" || keyboard.capsLock
    readonly property int rows: Lock.accounts.length + 1
    readonly property int rowH: Theme.dp(60)

    function focusInput() {
        if (Lock.sheet !== "")
            return ;

        if (Lock.manual && Lock.manualName === "")
            nameInput.forceActiveFocus();
        else
            pw.focusInput();
    }

    function discard() {
        pw.reveal = false;
        pw.clear();
        Lock.closeSheet();
    }

    function activate(i) {
        if (i >= Lock.accounts.length)
            Lock.pickOther();
        else
            Lock.pick(i);
    }

    function selectedRow() {
        return Lock.manual ? Lock.accounts.length : Lock.index;
    }

    radius: Theme.shapeXl
    color: Theme.card
    // only while a face is in motion through the side of the card: at rest the
    // session menu is allowed to stand above the card's own edge
    clip: card.k > 0.001
    // no Behavior: k is the one clock, and each face already eases its own
    // height, so easing the sum again would only put the card out of step
    implicitHeight: Theme.dp(48) + (1 - card.k) * face.implicitHeight + card.k * sheet.implicitHeight

    Behavior on k {
        NumberAnimation {
            duration: Theme.ms(460)
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.easeEmphasizedDecel
        }

    }

    Connections {
        function onSheetChanged() {
            if (Lock.sheet === "") {
                Qt.callLater(card.focusInput);
                return ;
            }
            card.kbd = false;
            list.currentIndex = card.selectedRow();
            list.positionViewAtIndex(list.currentIndex, ListView.Contain);
            list.forceActiveFocus();
        }

        function onSwitched() {
            nameInput.text = "";
            Qt.callLater(card.focusInput);
        }

        target: Lock
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            Lock.engage();
            Lock.closeSessionMenu();
            card.focusInput();
        }
    }

    // the push is cut to the card by a layer while it runs: the software
    // renderer lets shapes and masks draw straight past an ancestor's clip
    Item {
        id: pages

        anchors.fill: parent
        layer.enabled: card.k > 0.001 && card.k < 0.999

        // ── the question ───────────────────────────────────────────────────────
        Column {
            id: face

            // the scallops turn a little while the password is checked
            property real spin: Lock.phase === "checking" ? 30 : 0

            x: Theme.dp(24) - card.k * card.width
            y: Theme.dp(24)
            width: card.width - Theme.dp(48)
            spacing: Theme.dp(14)
            visible: card.k < 0.999

            Behavior on spin {
                NumberAnimation {
                    duration: Theme.ms(650)
                    easing.type: Easing.OutBack
                }

            }

            Item {
                id: avatarBox

                anchors.horizontalCenter: parent.horizontalCenter
                width: Theme.dp(88)
                height: Theme.dp(88)

                // a ring in the avatar's own shape: accent while typing, red on
                // refusal. it sits behind the face, so the face cuts it to a rim
                Cookie {
                    anchors.centerIn: parent
                    width: parent.width + Theme.dp(10)
                    height: parent.height + Theme.dp(10)
                    spin: face.spin
                    color: Lock.granted ? Theme.success : (Lock.phase === "failed" ? Theme.error : Theme.alpha(Theme.accent, 0.7))
                    opacity: Lock.focused ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.ms(240)
                            easing.type: Easing.OutCubic
                        }

                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.ms(200)
                        }

                    }

                }

                Avatar {
                    anchors.fill: parent
                    source: Lock.avatar
                    initials: Lock.initials
                    spin: face.spin
                    visible: !Lock.manual
                }

                Cookie {
                    anchors.fill: parent
                    spin: face.spin
                    color: Theme.cardHigh
                    visible: Lock.manual

                    Glyph {
                        anchors.centerIn: parent
                        name: "person"
                        size: Theme.dp(38)
                        color: Theme.subtext
                    }

                }

                TapHandler {
                    enabled: Lock.canSwitchUser
                    onTapped: Lock.openSheet("users")
                }

                HoverHandler {
                    enabled: Lock.canSwitchUser
                    cursorShape: Qt.PointingHandCursor
                }

            }

            // the name doubles as the way to someone else, once there is anyone
            Column {
                anchors.horizontalCenter: parent.horizontalCenter

                Item {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: nameRow.implicitWidth + (Lock.canSwitchUser ? Theme.dp(30) : 0)
                    height: Theme.dp(40)

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.pill(height)
                        color: Theme.text
                        opacity: nameTap.pressed ? Theme.statePressed : (nameHover.hovered ? Theme.stateHover : 0)

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.ms(120)
                            }

                        }

                    }

                    Row {
                        id: nameRow

                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: Lock.canSwitchUser ? Theme.dp(3) : 0
                        spacing: Theme.dp(4)

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Lock.manual ? "Other account" : Lock.displayName
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontHeadlineSm
                            font.variableAxes: Theme.axes(Theme.fontHeadlineSm, 520, 0)
                            font.weight: Font.Medium
                        }

                        Glyph {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "expand"
                            size: Theme.dp(22)
                            color: Theme.subtext
                            visible: Lock.canSwitchUser
                        }

                    }

                    HoverHandler {
                        id: nameHover

                        enabled: Lock.canSwitchUser
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        id: nameTap

                        enabled: Lock.canSwitchUser
                        onTapped: Lock.openSheet("users")
                    }

                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Lock.userName
                    color: Theme.subtextDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontBodySm
                    font.variableAxes: Theme.axes(Theme.fontBodySm, 420, 0)
                    visible: !Lock.manual && Lock.userName !== "" && Lock.userName !== Lock.displayName
                }

            }

            Item {
                width: parent.width
                height: Theme.dp(6)
            }

            // an account sddm does not list is named by hand, above the password
            Rectangle {
                width: parent.width
                height: Theme.dp(56)
                radius: Theme.pill(height)
                color: Theme.cardHigh
                border.width: nameInput.activeFocus ? 2 : 0
                border.color: Theme.accent
                visible: Lock.manual

                Glyph {
                    id: nameLead

                    anchors.left: parent.left
                    anchors.leftMargin: Theme.dp(20)
                    anchors.verticalCenter: parent.verticalCenter
                    name: "person"
                    size: Theme.dp(20)
                    color: nameInput.activeFocus ? Theme.accent : Theme.subtext
                }

                Text {
                    anchors.left: nameLead.right
                    anchors.leftMargin: Theme.dp(14)
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Username"
                    color: Theme.subtextDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontBodyLg
                    font.variableAxes: Theme.axes(Theme.fontBodyLg, 420, 0)
                    visible: nameInput.text.length === 0
                }

                TextInput {
                    id: nameInput

                    anchors.left: nameLead.right
                    anchors.leftMargin: Theme.dp(14)
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.dp(20)
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.text
                    selectionColor: Theme.alpha(Theme.accent, 0.4)
                    selectedTextColor: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontBodyLg
                    font.variableAxes: Theme.axes(Theme.fontBodyLg, 420, 0)
                    readOnly: !Lock.acceptsInput
                    clip: true
                    onTextChanged: {
                        Lock.manualName = nameInput.text;
                        if (nameInput.text.length > 0)
                            Lock.engage();

                    }
                    onAccepted: pw.focusInput()
                    Keys.onTabPressed: pw.focusInput()
                    Keys.onDownPressed: pw.focusInput()
                }

            }

            Field {
                id: pw

                width: parent.width
            }

            // the status line: sddm's verdict, the keyboard's warnings, or nothing
            Item {
                width: parent.width
                height: card.hasStatus ? Theme.dp(22) : 0
                clip: true

                Behavior on height {
                    NumberAnimation {
                        duration: Theme.ms(260)
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.easeEmphasizedDecel
                    }

                }

                Text {
                    id: status

                    anchors.left: parent.left
                    anchors.right: marks.left
                    anchors.rightMargin: Theme.dp(8)
                    anchors.verticalCenter: parent.verticalCenter
                    text: Lock.statusText
                    elide: Text.ElideRight
                    color: {
                        switch (Lock.statusKind) {
                        case "error":
                            return Theme.error;
                        case "good":
                            return Theme.success;
                        case "info":
                            return Theme.subtext;
                        }
                        return Theme.subtextDim;
                    }
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontBodySm
                    font.variableAxes: Theme.axes(Theme.fontBodySm, Lock.statusKind === "error" ? 520 : 420, 0)
                    font.weight: Lock.statusKind === "error" ? Font.Medium : Font.Normal
                    transform: Translate {
                        id: statusShift
                    }

                    onTextChanged: {
                        if (status.text !== "")
                            statusIn.restart();

                    }

                    SequentialAnimation {
                        id: statusIn

                        ParallelAnimation {
                            NumberAnimation {
                                target: status
                                property: "opacity"
                                from: 0
                                to: 1
                                duration: Theme.ms(220)
                                easing.type: Easing.OutCubic
                            }

                            NumberAnimation {
                                target: statusShift
                                property: "y"
                                from: 7
                                to: 0
                                duration: Theme.ms(300)
                                easing.type: Easing.Bezier
                                easing.bezierCurve: Theme.easeEmphasizedDecel
                            }

                        }

                    }

                }

                Row {
                    id: marks

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.dp(6)

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: capsRow.implicitWidth + Theme.dp(16)
                        height: Theme.dp(20)
                        radius: Theme.dp(999)
                        color: Theme.alpha(Theme.warning, 0.18)
                        visible: keyboard.capsLock

                        Row {
                            id: capsRow

                            anchors.centerIn: parent
                            spacing: Theme.dp(4)

                            Glyph {
                                anchors.verticalCenter: parent.verticalCenter
                                name: "caps"
                                size: Theme.dp(13)
                                color: Theme.warning
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Caps Lock"
                                color: Theme.warning
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontLabelSm
                                font.variableAxes: Theme.axes(Theme.fontLabelSm, 520, 0)
                                font.weight: Font.Medium
                            }

                        }

                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: layoutText.implicitWidth + Theme.dp(18)
                        height: Theme.dp(20)
                        radius: Theme.dp(999)
                        color: Theme.cardHigh
                        visible: card.layoutShort !== "" && Lock.focused

                        Text {
                            id: layoutText

                            anchors.centerIn: parent
                            text: card.layoutShort
                            color: Theme.subtext
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontLabelSm
                            font.variableAxes: Theme.axes(Theme.fontLabelSm, 520, 0)
                            font.weight: Font.Medium
                        }

                    }

                }

            }

            // what the password opens, and the way to open something else
            Item {
                width: parent.width
                height: Theme.dp(40)
                visible: Lock.sessions.length > 1

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: sessionRow.implicitWidth + Theme.dp(32)
                    height: parent.height
                    radius: Theme.pill(height)
                    color: Theme.alpha(Theme.text, sessionTap.pressed ? 0.14 : (sessionHover.hovered ? 0.1 : 0.05))

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.ms(120)
                        }

                    }

                    Row {
                        id: sessionRow

                        anchors.centerIn: parent
                        spacing: Theme.dp(8)

                        Glyph {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "session"
                            size: Theme.dp(17)
                            color: Theme.accent
                        }

                        // an eliding Text reports its elided width, so the full one
                        // is read off an unelided twin
                        Text {
                            id: sessionMeasure

                            visible: false
                            text: Lock.sessionName
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontLabelLg
                            font.variableAxes: Theme.axes(Theme.fontLabelLg, 520, 0)
                            font.weight: Font.Medium
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(Math.ceil(sessionMeasure.implicitWidth), face.width - Theme.dp(110))
                            text: Lock.sessionName
                            elide: Text.ElideRight
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontLabelLg
                            font.variableAxes: Theme.axes(Theme.fontLabelLg, 520, 0)
                            font.weight: Font.Medium
                        }

                        Glyph {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "expand"
                            size: Theme.dp(18)
                            color: Theme.subtext
                            rotation: Lock.sessionMenu ? 180 : 0

                            Behavior on rotation {
                                NumberAnimation {
                                    duration: Theme.ms(260)
                                    easing.type: Easing.Bezier
                                    easing.bezierCurve: Theme.easeEmphasizedDecel
                                }

                            }

                        }

                    }

                    HoverHandler {
                        id: sessionHover

                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        id: sessionTap

                        onTapped: {
                            if (Lock.sessionMenu)
                                Lock.closeSessionMenu();
                            else
                                Lock.openSessionMenu();
                        }
                    }

                }

            }

        }

        // ── the sheet ──────────────────────────────────────────────────────────
        Item {
            id: sheet

            x: Theme.dp(24) + (1 - card.k) * card.width
            y: Theme.dp(24)
            width: card.width - Theme.dp(48)
            implicitHeight: head.height + Theme.dp(10) + list.height
            visible: card.k > 0.001

            Item {
                id: head

                width: parent.width
                height: Theme.dp(44)

                IconButton {
                    id: back

                    anchors.left: parent.left
                    anchors.leftMargin: -Theme.dp(6)
                    anchors.verticalCenter: parent.verticalCenter
                    diameter: Theme.dp(44)
                    glyph: "back"
                    glyphSize: Theme.dp(22)
                    glyphColor: Theme.text
                    onClicked: Lock.closeSheet()
                }

                Text {
                    anchors.left: back.right
                    anchors.leftMargin: Theme.dp(6)
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Choose an account"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontTitleMd
                    font.variableAxes: Theme.axes(Theme.fontTitleMd, 520, 0)
                    font.weight: Font.Medium
                }

            }

            ListView {
                id: list

                anchors.top: head.bottom
                anchors.topMargin: Theme.dp(10)
                width: parent.width
                // five and a half rows show there is more without a scrollbar
                height: Math.min(card.rows, 5.5) * (card.rowH + list.spacing) - list.spacing
                spacing: Theme.dp(4)
                clip: true
                model: card.rows
                boundsBehavior: Flickable.StopAtBounds
                keyNavigationEnabled: true
                Keys.onUpPressed: (event) => {
                    card.kbd = true;
                    event.accepted = false;
                }
                Keys.onDownPressed: (event) => {
                    card.kbd = true;
                    event.accepted = false;
                }
                Keys.onReturnPressed: card.activate(list.currentIndex)
                Keys.onEnterPressed: card.activate(list.currentIndex)
                Keys.onSpacePressed: card.activate(list.currentIndex)
                Keys.onEscapePressed: Lock.closeSheet()
                Keys.onLeftPressed: Lock.closeSheet()
                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Backspace) {
                        Lock.closeSheet();
                        event.accepted = true;
                    }
                }

                delegate: Item {
                    id: row

                    required property int index
                    readonly property bool other: row.index >= Lock.accounts.length
                    readonly property var acct: row.other ? null : Lock.accounts[row.index]
                    readonly property bool picked: card.selectedRow() === row.index
                    readonly property string title: row.other ? "Other account" : (row.acct ? Lock.nameOf(row.acct) : "")
                    readonly property string subtitle: {
                        if (row.other)
                            return "Sign in with a username";

                        return row.acct && row.acct.name !== row.title ? row.acct.name : "";
                    }

                    width: ListView.view.width
                    height: card.rowH

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.shapeLg
                        color: row.picked ? Theme.cardHigh : "transparent"
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.shapeLg
                        color: Theme.text
                        opacity: rowTap.pressed ? Theme.statePressed : (rowHover.hovered ? Theme.stateHover : 0)

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.ms(120)
                            }

                        }

                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.shapeLg
                        color: "transparent"
                        border.width: 2
                        border.color: Theme.accent
                        visible: card.kbd && row.ListView.isCurrentItem
                    }

                    Item {
                        id: lead

                        anchors.left: parent.left
                        anchors.leftMargin: Theme.dp(10)
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.dp(40)
                        height: Theme.dp(40)

                        Avatar {
                            anchors.fill: parent
                            source: row.acct ? row.acct.icon : ""
                            initials: row.acct ? Lock.initialsOf(Lock.nameOf(row.acct)) : ""
                            visible: !!row.acct
                        }

                        Cookie {
                            anchors.fill: parent
                            shape: "cookie12"
                            color: Theme.cardHigh
                            visible: !row.acct

                            Glyph {
                                anchors.centerIn: parent
                                name: "personAdd"
                                size: Theme.dp(20)
                                color: Theme.subtext
                            }

                        }

                    }

                    Column {
                        anchors.left: lead.right
                        anchors.leftMargin: Theme.dp(14)
                        anchors.right: tick.left
                        anchors.rightMargin: Theme.dp(10)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.dp(1)

                        Text {
                            width: parent.width
                            text: row.title
                            elide: Text.ElideRight
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontTitleSm
                            font.variableAxes: Theme.axes(Theme.fontTitleSm, row.picked ? 600 : 500, 0)
                            font.weight: row.picked ? Font.DemiBold : Font.Medium
                        }

                        Text {
                            width: parent.width
                            text: row.subtitle
                            elide: Text.ElideRight
                            color: Theme.subtextDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontBodySm
                            font.variableAxes: Theme.axes(Theme.fontBodySm, 420, 0)
                            visible: row.subtitle !== ""
                        }

                    }

                    Glyph {
                        id: tick

                        anchors.right: parent.right
                        anchors.rightMargin: Theme.dp(16)
                        anchors.verticalCenter: parent.verticalCenter
                        name: "check"
                        size: Theme.dp(20)
                        color: Theme.accent
                        opacity: row.picked ? 1 : 0
                    }

                    HoverHandler {
                        id: rowHover

                        cursorShape: Qt.PointingHandCursor
                        onHoveredChanged: {
                            if (rowHover.hovered)
                                card.kbd = false;

                        }
                    }

                    TapHandler {
                        id: rowTap

                        onTapped: card.activate(row.index)
                    }

                }

            }

        }

    }

    // ── the session menu ───────────────────────────────────────────────────
    //
    // NOTE(fork): a popout, not another face of the card. the session pill is
    // the last thing in the question, so its top is a fixed distance up from
    // the bottom of the card -- the menu stands on it and grows upward, over
    // the card's own edge when the list is long enough to need it
    Item {
        id: pop

        // 0 away, 1 standing open
        property real k: Lock.sessionMenu ? 1 : 0
        // the ring only follows the keyboard here too
        property bool kbd: false
        readonly property int rowH: Theme.dp(52)
        readonly property int gap: Theme.dp(2)
        // five and a half rows show there is more without a scrollbar
        readonly property real listH: Math.min(Lock.sessions.length, 5.5) * (pop.rowH + pop.gap) - pop.gap
        readonly property int padding: Theme.dp(8)

        x: Theme.dp(24)
        width: card.width - Theme.dp(48)
        height: pop.listH + pop.padding * 2
        y: card.height - Theme.dp(64) - Theme.dp(10) - pop.height
        visible: pop.k > 0.001
        enabled: Lock.sessionMenu
        opacity: pop.k
        scale: 0.96 + 0.04 * pop.k
        transformOrigin: Item.Bottom

        transform: Translate {
            y: (1 - pop.k) * Theme.dp(10)
        }

        Behavior on k {
            NumberAnimation {
                duration: Theme.ms(300)
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.easeEmphasizedDecel
            }

        }

        Connections {
            function onSessionMenuChanged() {
                if (!Lock.sessionMenu) {
                    Qt.callLater(card.focusInput);
                    return ;
                }
                pop.kbd = false;
                menu.currentIndex = Lock.sessionIndex;
                menu.positionViewAtIndex(menu.currentIndex, ListView.Contain);
                menu.forceActiveFocus();
            }

            target: Lock
        }

        Rectangle {
            anchors.fill: parent
            radius: Theme.shapeLg
            color: Theme.cardHigh
            border.width: 1
            border.color: Theme.alpha(Theme.outline, 0.8)
        }

        // the menu is its own surface: a press on it never reaches the card
        // underneath, which would only shut it again
        MouseArea {
            anchors.fill: parent
        }

        ListView {
            id: menu

            anchors.fill: parent
            anchors.margins: pop.padding
            spacing: pop.gap
            clip: true
            model: Lock.sessions
            boundsBehavior: Flickable.StopAtBounds
            keyNavigationEnabled: true
            Keys.onUpPressed: (event) => {
                pop.kbd = true;
                event.accepted = false;
            }
            Keys.onDownPressed: (event) => {
                pop.kbd = true;
                event.accepted = false;
            }
            Keys.onReturnPressed: Lock.pickSession(menu.currentIndex)
            Keys.onEnterPressed: Lock.pickSession(menu.currentIndex)
            Keys.onSpacePressed: Lock.pickSession(menu.currentIndex)
            Keys.onEscapePressed: Lock.closeSessionMenu()
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Backspace) {
                    Lock.closeSessionMenu();
                    event.accepted = true;
                }
            }

            delegate: Item {
                id: srow

                required property int index
                required property var modelData
                readonly property bool picked: Lock.sessionIndex === srow.index

                width: ListView.view.width
                height: pop.rowH

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.shapeMd
                    color: Theme.text
                    opacity: srowTap.pressed ? Theme.statePressed : (srowHover.hovered ? Theme.stateHover : 0)

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.ms(120)
                        }

                    }

                }

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.shapeMd
                    color: "transparent"
                    border.width: 2
                    border.color: Theme.accent
                    visible: pop.kbd && srow.ListView.isCurrentItem
                }

                Glyph {
                    id: slead

                    anchors.left: parent.left
                    anchors.leftMargin: Theme.dp(14)
                    anchors.verticalCenter: parent.verticalCenter
                    name: "session"
                    size: Theme.dp(19)
                    color: srow.picked ? Theme.accent : Theme.subtext
                }

                Column {
                    anchors.left: slead.right
                    anchors.leftMargin: Theme.dp(14)
                    anchors.right: stick.left
                    anchors.rightMargin: Theme.dp(10)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.dp(1)

                    Text {
                        width: parent.width
                        text: srow.modelData.name
                        elide: Text.ElideRight
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontLabelLg
                        font.variableAxes: Theme.axes(Theme.fontLabelLg, srow.picked ? 600 : 500, 0)
                        font.weight: srow.picked ? Font.DemiBold : Font.Medium
                    }

                    Text {
                        width: parent.width
                        text: srow.modelData.comment
                        elide: Text.ElideRight
                        color: Theme.subtextDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontLabelSm
                        font.variableAxes: Theme.axes(Theme.fontLabelSm, 420, 0)
                        visible: srow.modelData.comment !== ""
                    }

                }

                Glyph {
                    id: stick

                    anchors.right: parent.right
                    anchors.rightMargin: Theme.dp(14)
                    anchors.verticalCenter: parent.verticalCenter
                    name: "check"
                    size: Theme.dp(18)
                    color: Theme.accent
                    opacity: srow.picked ? 1 : 0
                }

                HoverHandler {
                    id: srowHover

                    cursorShape: Qt.PointingHandCursor
                    onHoveredChanged: {
                        if (srowHover.hovered)
                            pop.kbd = false;

                    }
                }

                TapHandler {
                    id: srowTap

                    onTapped: Lock.pickSession(srow.index)
                }

            }

        }

    }

}
