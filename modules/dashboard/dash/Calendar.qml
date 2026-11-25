pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import M3Shapes
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.components.effects
import qs.components.misc
import qs.components.widgets
import qs.services

CustomMouseArea {
    id: root

    required property ScreenState screenState

    property date currentDate: screenState.dashboardDate
    readonly property int currMonth: currentDate.getMonth()
    readonly property int currYear: currentDate.getFullYear()
    readonly property int nonAnimCurrMonth: screenState.dashboardDate.getMonth()
    readonly property int nonAnimCurrYear: screenState.dashboardDate.getFullYear()

    // NOTE(fork): -1 slides the grid out to the left (a later month), 1 to the right (an earlier
    // one). Fixed when a change starts rather than bound to the dates: a binding only catches up
    // after the change has already begun, so the slide out read the old answer and every forward
    // step went out to the right and came back in from the right
    property int animDirection: 1
    property real animTranslate
    property real animOpacity: 1

    // Days with special and rare events are marked in their kind's colour, when GNOME Calendar's store is
    // there to read them from (services/CalendarEvents.qml). The events themselves are listed by
    // the event widgets rather than here, which keeps this card the height it always was
    readonly property bool showEvents: CalendarEvents.enabled && CalendarEvents.available
    // Keeps GNOME Calendar running in the background while the dashboard is open, so a click on
    // a day opens it straight away (see CalendarEvents.warmApp)
    readonly property bool warmsApp: screenState.dashboard && showEvents

    // The day under the pointer, and the one whose events the hover card is showing. Kept apart
    // so the card waits a moment before it opens (no flicker sweeping across the grid) but
    // follows straight away once it is open
    property Item hoveredDay: null
    property Item shownDay: null
    readonly property int hoverLimit: 3

    function onWheel(event: WheelEvent): void {
        if (event.angleDelta.y > 0)
            screenState.dashboardDate = new Date(nonAnimCurrYear, nonAnimCurrMonth - 1, 1);
        else if (event.angleDelta.y < 0)
            screenState.dashboardDate = new Date(nonAnimCurrYear, nonAnimCurrMonth + 1, 1);
    }

    anchors.left: parent.left
    anchors.right: parent.right
    implicitHeight: inner.implicitHeight + inner.anchors.margins * 2

    acceptedButtons: Qt.MiddleButton
    onClicked: root.screenState.dashboardDate = new Date()

    onNonAnimCurrMonthChanged: CalendarEvents.focusMonth(nonAnimCurrYear, nonAnimCurrMonth)
    onNonAnimCurrYearChanged: CalendarEvents.focusMonth(nonAnimCurrYear, nonAnimCurrMonth)
    Component.onCompleted: {
        CalendarEvents.focusMonth(nonAnimCurrYear, nonAnimCurrMonth);
        if (warmsApp)
            CalendarEvents.appWarmers++;
    }
    Component.onDestruction: {
        if (warmsApp)
            CalendarEvents.appWarmers--;
    }
    onWarmsAppChanged: CalendarEvents.appWarmers += warmsApp ? 1 : -1
    onHoveredDayChanged: {
        if (!hoveredDay) {
            hoverHideTimer.restart();
        } else if (shownDay) {
            hoverHideTimer.stop();
            shownDay = hoveredDay;
        } else {
            hoverHideTimer.stop();
            hoverShowTimer.restart();
        }
    }
    onCurrentDateChanged: {
        hoverShowTimer.stop();
        hoveredDay = null;
        shownDay = null;
    }

    // Keeps the event reader running only while a calendar card is around to show what it reads
    Ref {
        service: CalendarEvents
    }

    Timer {
        id: hoverShowTimer

        interval: 350
        onTriggered: root.shownDay = root.hoveredDay
    }

    Timer {
        id: hoverHideTimer

        interval: 120
        onTriggered: {
            hoverShowTimer.stop();
            if (!root.hoveredDay)
                root.shownDay = null;
        }
    }

    Anim {
        id: trOutAnim

        running: false
        target: root
        property: "animTranslate"
        to: root.Tokens.padding.extraLarge * root.animDirection
        type: Anim.FastSpatial
    }

    Behavior on currentDate {
        SequentialAnimation {
            ParallelAnimation {
                // NOTE(fork): started right here rather than through Qt.callLater. Deferred, it
                // began a frame late (a stutter on every month change), and with animations off
                // (low power) the whole sequence below had already finished by the time it ran,
                // so it slid the grid out to one side and left it there until the card reloaded.
                // currentDate still holds the old month here (the Behavior hasn't written it yet)
                // while dashboardDate already has the new one, so the two give the direction
                ScriptAction {
                    script: {
                        root.animDirection = root.screenState.dashboardDate > root.currentDate ? -1 : 1;
                        trOutAnim.restart();
                    }
                }
                Anim {
                    target: root
                    property: "animOpacity"
                    to: 0
                    type: Anim.FastEffects
                }
            }
            ScriptAction {
                script: {
                    // Stopped outright so nothing of the slide out can land after the slide in
                    trOutAnim.stop();
                    root.animTranslate = root.Tokens.padding.extraLarge * -root.animDirection;
                }
            }
            PropertyAction {}
            ParallelAnimation {
                Anim {
                    target: root
                    property: "animTranslate"
                    to: 0
                    type: Anim.DefaultSpatial
                }
                Anim {
                    target: root
                    property: "animOpacity"
                    to: 1
                    type: Anim.DefaultEffects
                }
            }
        }
    }

    ColumnLayout {
        id: inner

        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.extraSmall

        RowLayout {
            id: monthNavigationRow

            Layout.fillWidth: true
            spacing: Tokens.spacing.extraSmall

            IconButton {
                isRound: true
                icon: "chevron_left"
                type: IconButton.Text
                font: Tokens.font.icon.builders.small.weight(Font.Bold).build()
                padding: Tokens.padding.small
                onClicked: root.screenState.dashboardDate = new Date(root.nonAnimCurrYear, root.nonAnimCurrMonth - 1, 1)
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                implicitWidth: monthYearDisplay.implicitWidth + Tokens.padding.large * 2
                implicitHeight: monthYearDisplay.implicitHeight + Tokens.padding.extraSmall * 2

                StateLayer {
                    color: Colours.palette.m3primary
                    radius: pressed ? Tokens.rounding.small : height / 2
                    disabled: {
                        const now = Time.date;
                        return root.nonAnimCurrMonth === now.getMonth() && root.nonAnimCurrYear === now.getFullYear();
                    }
                    onClicked: root.screenState.dashboardDate = new Date()

                    Behavior on radius {
                        Anim {
                            type: Anim.DefaultEffects
                        }
                    }
                }

                StyledText {
                    id: monthYearDisplay

                    opacity: root.animOpacity
                    transform: Translate {
                        x: root.animTranslate
                    }

                    anchors.centerIn: parent
                    text: grid.title
                    color: Colours.palette.m3primary
                    font: Tokens.font.title.builders.small.capitalisation(Font.Capitalize).build()
                }
            }

            IconButton {
                isRound: true
                icon: "chevron_right"
                type: IconButton.Text
                font: Tokens.font.icon.builders.small.weight(Font.Bold).build()
                padding: Tokens.padding.small
                onClicked: root.screenState.dashboardDate = new Date(root.nonAnimCurrYear, root.nonAnimCurrMonth + 1, 1)
            }
        }

        DayOfWeekRow {
            id: daysRow

            Layout.fillWidth: true
            locale: grid.locale

            delegate: StyledText {
                required property var model

                horizontalAlignment: Text.AlignHCenter
                text: model.shortName
                font: Tokens.font.body.builders.small.weight(Font.Medium).build()
                color: (model.day === 0 || model.day === 6) ? Colours.palette.m3tertiary : Colours.palette.m3onSurface
            }
        }

        Item {
            Layout.fillWidth: true
            implicitHeight: grid.implicitHeight

            opacity: root.animOpacity
            transform: Translate {
                x: root.animTranslate
            }

            MonthGrid {
                id: grid

                month: root.currMonth
                year: root.currYear

                anchors.fill: parent

                spacing: 3
                locale: Tr.locale

                delegate: Item {
                    id: dayItem

                    required property var model

                    // Special and rare only: the routine stays off the calendar
                    readonly property var dayEvents: root.showEvents ? CalendarEvents.shownOn(model.date) : []
                    readonly property bool inMonth: model.month === grid.month
                    // The square the number sits in, which today's shape is sized off. The dots
                    // for the day's events sit in its bottom padding, so marking events costs the
                    // grid no height
                    readonly property real baseSize: text.implicitHeight + Tokens.padding.small
                    readonly property real dotSize: 3
                    readonly property bool hasDots: !model.today && dayEvents.length > 0

                    implicitWidth: baseSize
                    implicitHeight: baseSize

                    Component.onDestruction: {
                        if (root.hoveredDay === dayItem)
                            root.hoveredDay = null;
                        if (root.shownDay === dayItem)
                            root.shownDay = null;
                    }

                    // A wash in the colour of the day's events - blue for a special one, green for
                    // a birthday or holiday - so the days that matter read at a glance. Today has its own shape instead, and anything drawn under that is
                    // recoloured along with the number
                    StyledRect {
                        anchors.centerIn: parent
                        implicitWidth: Math.min(parent.width, dayItem.baseSize + 4)
                        implicitHeight: dayItem.baseSize + 2

                        visible: !dayItem.model.today && dayItem.dayEvents.length > 0
                        radius: Tokens.rounding.small
                        color: Qt.alpha(CalendarEvents.dayColour(dayItem.model.date) ?? "transparent", dayItem.inMonth ? 0.22 : 0.08)
                    }

                    StyledText {
                        id: text

                        anchors.horizontalCenter: parent.horizontalCenter
                        // Nudged up to make room for the dots under it
                        y: (dayItem.baseSize - height) / 2 - (dayItem.hasDots ? 2 : 0)

                        horizontalAlignment: Text.AlignHCenter
                        text: grid.locale.toString(dayItem.model.day)
                        color: {
                            const dayOfWeek = dayItem.model.date.getDay();
                            if (dayOfWeek === 0 || dayOfWeek === 6)
                                return Colours.palette.m3tertiary;

                            return Colours.palette.m3onSurfaceVariant;
                        }
                        opacity: dayItem.model.today || dayItem.inMonth ? 1 : 0.4
                        font: Tokens.font.body.small
                    }

                    // One dot per event, up to three, each in its kind's colour. Today's count
                    // goes on a badge beside its shape instead (see todayBadge)
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 1

                        visible: dayItem.hasDots
                        opacity: dayItem.inMonth ? 1 : 0.4
                        spacing: 2

                        Repeater {
                            model: dayItem.dayEvents.slice(0, 3)

                            StyledRect {
                                required property var modelData

                                implicitWidth: dayItem.dotSize
                                implicitHeight: dayItem.dotSize
                                radius: dayItem.dotSize / 2
                                color: CalendarEvents.colourOf(modelData)
                            }
                        }
                    }

                    // A day opens in GNOME Calendar
                    StateLayer {
                        anchors.fill: undefined
                        anchors.centerIn: parent
                        implicitWidth: Math.min(parent.width, dayItem.baseSize + 4)
                        implicitHeight: dayItem.baseSize + 2

                        visible: root.showEvents
                        radius: Tokens.rounding.small
                        // Handed to GNOME Calendar first, so it is already opening while the
                        // dashboard closes out of its way
                        onClicked: {
                            CalendarEvents.openDate(dayItem.model.date);
                            root.screenState.dashboard = false;
                        }
                        onContainsMouseChanged: {
                            if (containsMouse)
                                root.hoveredDay = dayItem;
                            else if (root.hoveredDay === dayItem)
                                root.hoveredDay = null;
                        }
                    }
                }
            }

            MaterialShape {
                id: todayIndicator

                readonly property Item todayItem: grid.contentItem.children.find(c => c.model.today) ?? null
                property Item today

                onTodayItemChanged: {
                    if (todayItem)
                        today = todayItem;
                }

                x: today ? today.x + (today.width - implicitWidth) / 2 : 0
                y: today ? today.y - Tokens.padding.extraSmall - 1 : 0

                // qmllint disable missing-property
                implicitSize: today ? today.baseSize + Tokens.padding.extraSmall * 2 : 0
                // qmllint enable missing-property
                shape: MaterialShape.Sunny

                clip: true
                color: Colours.palette.m3primary

                opacity: todayItem ? 1 : 0

                Colouriser {
                    x: -todayIndicator.x
                    y: -todayIndicator.y

                    implicitWidth: grid.width
                    implicitHeight: grid.height

                    source: grid
                    sourceColor: Colours.palette.m3onSurface
                    colorizationColor: Colours.palette.m3onPrimary
                }
            }

            // Today's special and rare events as a count on the corner of its shape
            StyledRect {
                id: todayBadge

                readonly property var events: root.showEvents && todayIndicator.todayItem ? CalendarEvents.today : []

                x: todayIndicator.x + todayIndicator.width - width + 3
                y: todayIndicator.y - 3
                implicitWidth: Math.max(implicitHeight, badgeText.implicitWidth + 6)
                implicitHeight: badgeText.implicitHeight + 2

                visible: events.length > 0
                opacity: todayIndicator.opacity
                radius: height / 2
                color: CalendarEvents.dayColour(Time.date) ?? "transparent"
                border.width: 1.5
                border.color: Colours.palette.m3surfaceContainer

                StyledText {
                    id: badgeText

                    anchors.centerIn: parent
                    text: todayBadge.events.length > 9 ? "9+" : todayBadge.events.length
                    color: Colours.on(todayBadge.color)
                    font: Tokens.font.label.builders.small.size(7).weight(Font.Bold).build()
                }
            }
        }
    }

    // What is on the hovered day, in a small card beside it: above for the lower rows and below
    // for the upper ones, kept inside the calendar so the card never clips it. For today that is
    // what is left - anything under way first, then what comes next, three in all - and for any
    // other day its first three. Passes the pointer through, so moving on to another day just
    // moves the card along
    Item {
        id: hoverCard

        // Held on to while the card fades out, so it doesn't jump to the corner on the way
        property Item day
        readonly property date date: day?.model.date ?? new Date()
        readonly property bool isToday: CalendarEvents.dayDiff(date) === 0
        readonly property var events: {
            if (!day)
                return [];
            const all = CalendarEvents.shownOn(date);
            if (!isToday)
                return all;
            void Time.date;
            const left = all.filter(e => !CalendarEvents.isOver(e));
            return [...left.filter(e => CalendarEvents.isOngoing(e)), ...left.filter(e => !CalendarEvents.isOngoing(e))];
        }
        readonly property bool open: root.showEvents && root.shownDay !== null
        readonly property point dayPos: {
            void root.animTranslate;
            void grid.width;
            return day ? day.mapToItem(root, 0, 0) : Qt.point(0, 0);
        }
        readonly property bool above: dayPos.y > root.height / 2
        readonly property real margin: Tokens.padding.small

        z: 10
        width: Math.min(root.width - margin * 2, 240)
        height: card.implicitHeight
        x: day ? Math.max(margin, Math.min(root.width - width - margin, dayPos.x + day.width / 2 - width / 2)) : 0
        y: {
            if (!day)
                return 0;
            const want = above ? dayPos.y - height - 4 : dayPos.y + day.height + 4;
            return Math.max(margin, Math.min(root.height - height - margin, want));
        }

        opacity: open ? 1 : 0
        visible: opacity > 0
        scale: open ? 1 : 0.95
        transformOrigin: above ? Item.Bottom : Item.Top

        Connections {
            function onShownDayChanged(): void {
                if (root.shownDay)
                    hoverCard.day = root.shownDay;
            }

            target: root
        }

        Elevation {
            anchors.fill: card
            radius: card.radius
            level: 2
        }

        StyledRect {
            id: card

            anchors.left: parent.left
            anchors.right: parent.right
            implicitHeight: cardLayout.implicitHeight + Tokens.padding.small * 2

            radius: Tokens.rounding.medium
            color: Colours.palette.m3surfaceContainerHigh

            ColumnLayout {
                id: cardLayout

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Tokens.padding.small
                spacing: 0

                StyledText {
                    Layout.leftMargin: Tokens.padding.small
                    Layout.bottomMargin: Tokens.spacing.extraSmall
                    text: CalendarEvents.dayLabel(hoverCard.date)
                    color: Colours.palette.m3primary
                    font: Tokens.font.label.builders.medium.weight(Font.Medium).build()
                }

                Repeater {
                    model: hoverCard.events.slice(0, root.hoverLimit)

                    EventRow {
                        required property var modelData

                        Layout.fillWidth: true
                        event: modelData
                        day: hoverCard.date
                        interactive: false
                    }
                }

                StyledText {
                    Layout.leftMargin: Tokens.padding.small
                    Layout.bottomMargin: Tokens.spacing.extraSmall
                    visible: hoverCard.events.length === 0
                    text: hoverCard.isToday ? Tr.tr("No events left today") : Tr.tr("No events")
                    color: Colours.palette.m3outline
                    font: Tokens.font.label.medium
                }

                StyledText {
                    Layout.leftMargin: Tokens.padding.small
                    visible: hoverCard.events.length > root.hoverLimit
                    text: Tr.tr("+%1 more").arg(hoverCard.events.length - root.hoverLimit)
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.small
                }
            }
        }

        Behavior on opacity {
            Anim {
                type: Anim.FastEffects
            }
        }

        Behavior on scale {
            Anim {
                type: Anim.FastSpatial
            }
        }

        Behavior on x {
            enabled: hoverCard.opacity > 0

            Anim {
                type: Anim.FastSpatial
            }
        }

        Behavior on y {
            enabled: hoverCard.opacity > 0

            Anim {
                type: Anim.FastSpatial
            }
        }
    }
}
