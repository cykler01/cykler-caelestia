pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.lock.canvas.elements

// One element on the lock canvas: loads its kind's delegate (elements/<Kind>Element.qml), sizes it
// (its natural size times its scale, or the box it's given), turns it, and places it so that its
// anchor point sits at its x and y on the screen. In the editor, an element with nothing to show
// right now (no weather yet, session buttons switched off) is drawn as an outline with its name,
// so it can still be found and moved
Item {
    id: host

    required property var element
    required property int index
    property var lock: null
    property real uiScale: 1
    property real screenW: parent?.width ?? 0
    property real screenH: parent?.height ?? 0
    property bool editing: false
    // How far it is shown, from the canvas's curtain: 1 shown, 0 hidden
    property real shown: 1
    // A drag or resize in progress in the editor, applied on top of what's saved until it's let go
    property point liveOffset: Qt.point(0, 0)
    property real liveScale: 1
    property size liveBox: Qt.size(0, 0)

    readonly property var kind: ElementCatalog.kind(element.id)
    readonly property bool sized: kind?.sized ?? false
    readonly property var opts: ElementCatalog.optionsFor(element.id, element.options)
    readonly property real s: uiScale * Math.max(0.1, (element.scale ?? 1) * liveScale)
    readonly property bool turned: Math.abs(element.rotation ?? 0) === 90

    readonly property real boxW: liveBox.width > 0 ? liveBox.width : (element.w ?? 0) * screenW
    readonly property real boxH: liveBox.height > 0 ? liveBox.height : (element.h ?? 0) * screenH
    readonly property bool boxed: sized && boxW > 0 && boxH > 0

    readonly property bool hasContent: (loader.item?.visible ?? false) && naturalW > 1 && naturalH > 1
    readonly property real naturalW: loader.item?.implicitWidth ?? 0
    readonly property real naturalH: loader.item?.implicitHeight ?? 0
    readonly property bool placeholder: editing && !boxed && !hasContent

    // The content's size before it's turned
    readonly property real contentW: boxed ? (turned ? boxH : boxW) : placeholder ? 180 * uiScale : naturalW
    readonly property real contentH: boxed ? (turned ? boxW : boxH) : placeholder ? 56 * uiScale : naturalH

    readonly property string anchorPoint: element.anchor ?? "c"
    readonly property real ax: anchorPoint.endsWith("l") ? 0 : anchorPoint.endsWith("r") ? 1 : 0.5
    readonly property real ay: anchorPoint.startsWith("t") ? 0 : anchorPoint.startsWith("b") ? 1 : 0.5

    width: turned ? contentH : contentW
    height: turned ? contentW : contentH
    x: (element.x ?? 0.5) * screenW - ax * width + liveOffset.x
    y: (element.y ?? 0.5) * screenH - ay * height + liveOffset.y

    visible: element.enabled ?? true
    opacity: (element.opacity ?? 1) * shown
    // Hidden by the curtain it's out of reach too. Never for the password field: a disabled item
    // can't hold the keyboard, and the field has to keep it to catch the key that lifts the curtain
    enabled: shown > 0.5 || element.id === "password" || editing

    Behavior on opacity {
        Anim {
            type: Anim.DefaultEffects
        }
    }

    Loader {
        id: loader

        anchors.centerIn: parent
        width: host.contentW
        height: host.contentH
        rotation: host.element.rotation ?? 0
        focus: host.element.id === "password"
        sourceComponent: ({
                password: passwordKind,
                avatar: avatarKind,
                username: usernameKind,
                greeting: greetingKind,
                clock: clockKind,
                date: dateKind,
                text: textKind,
                weather: weatherKind,
                status: statusKind,
                chips: chipsKind,
                stat: statKind,
                media: mediaKind,
                calendar: calendarKind,
                terminal: terminalKind,
                widgets: widgetsKind,
                session: sessionKind,
                panel: panelKind,
                divider: dividerKind
            })[host.element.id] ?? null
    }

    Binding {
        target: loader.item
        property: "s"
        value: host.s
        when: loader.status === Loader.Ready
    }

    Binding {
        target: loader.item
        property: "opts"
        value: host.opts
        when: loader.status === Loader.Ready
    }

    Binding {
        target: loader.item
        property: "lock"
        value: host.lock
        when: loader.status === Loader.Ready
    }

    // In the editor only: what an element with nothing to show is
    StyledRect {
        anchors.fill: parent
        visible: host.placeholder
        radius: Tokens.rounding.medium
        color: Qt.alpha(Colours.palette.m3onSurface, 0.05)
        border.width: 1
        border.color: Qt.alpha(Colours.palette.m3outline, 0.6)

        Row {
            anchors.centerIn: parent
            spacing: Tokens.spacing.small

            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                text: host.kind?.icon ?? "help"
                color: Colours.palette.m3onSurfaceVariant
                fontStyle: Tokens.font.icon.small
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: host.kind?.name ?? host.element.id
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.medium
            }
        }
    }

    // One per kind in ElementCatalog
    Component {
        id: passwordKind

        PasswordElement {}
    }

    Component {
        id: avatarKind

        AvatarElement {}
    }

    Component {
        id: usernameKind

        UsernameElement {}
    }

    Component {
        id: greetingKind

        GreetingElement {}
    }

    Component {
        id: clockKind

        ClockElement {}
    }

    Component {
        id: dateKind

        DateElement {}
    }

    Component {
        id: textKind

        TextElement {}
    }

    Component {
        id: weatherKind

        WeatherElement {}
    }

    Component {
        id: statusKind

        StatusElement {}
    }

    Component {
        id: chipsKind

        ChipsElement {}
    }

    Component {
        id: statKind

        StatElement {}
    }

    Component {
        id: mediaKind

        MediaElement {}
    }

    Component {
        id: calendarKind

        CalendarElement {}
    }

    Component {
        id: terminalKind

        TerminalElement {}
    }

    Component {
        id: widgetsKind

        WidgetsElement {}
    }

    Component {
        id: sessionKind

        SessionElement {}
    }

    Component {
        id: panelKind

        PanelElement {}
    }

    Component {
        id: dividerKind

        DividerElement {}
    }
}
