pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services
import qs.modules.nexus
import qs.modules.launcher.items
import qs.modules.launcher.services

StyledListView {
    id: root

    required property SearchBar search
    required property ScreenState screenState

    property string displayText

    readonly property string requestedState: stateForText(search.text)
    readonly property string displayState: stateForText(displayText)

    // The result modes build their rows fresh on every keystroke, so nothing in the list survives
    // from one query to the next: every row is a remove and an add rather than a move. Animating
    // that is not just pointless, it is what draws one row on top of another - rows slide through
    // each other on their way to positions the rows being replaced have not left yet
    readonly property bool rebuildsWholesale: ["spotlight", "settings", "files"].includes(displayState)
    // False while a switch between modes is in flight. The switch tears the list down and builds
    // it again, so nothing in it is where it was: animating rows to their new places just slides
    // them through each other. Set at both ends of the transition below
    property bool settled

    function syncDisplayText(): void {
        if (screenState.launcher && requestedState === displayState)
            displayText = search.text;
    }

    function stateForText(text: string): string {
        const prefix = GlobalConfig.launcher.actionPrefix;
        if (text.startsWith(prefix)) {
            if (text.startsWith(`${prefix}calc `))
                return "calc";

            if (GlobalConfig.launcher.enableAiSearch && (text === `${prefix}ai` || text.startsWith(`${prefix}ai `)))
                return "ai";

            if (text === `${prefix}gpu` || text.startsWith(`${prefix}gpu `))
                return "gpu";

            if (text === `${prefix}ssh` || text.startsWith(`${prefix}ssh `))
                return "ssh";

            if (text === `${prefix}b` || text.startsWith(`${prefix}b `))
                return "browser";

            if (text === `${prefix}settings` || text.startsWith(`${prefix}settings `))
                return "settings";

            if (FileSearch.queryFor(text) !== null)
                return "files";

            return "actions";
        }

        // Nothing typed is still the plain app list: a bare launcher should open on apps, not on an
        // empty unified list
        if (GlobalConfig.launcher.unifiedSearch && text.trim())
            return "spotlight";

        return "apps";
    }

    function resultsForText(text: string): var {
        switch (stateForText(text)) {
        case "spotlight":
            // Each source still runs its own search; Spotlight only ranks and groups what they
            // return (see services/Spotlight.qml)
            return Spotlight.query(text, Apps.search(text));
        case "files":
            // Searched off the main thread; this reads whatever came back last, and the model is
            // rebuilt when the next lot arrives
            return FileSearch.rows();
        case "settings": {
            const query = text.slice(`${GlobalConfig.launcher.actionPrefix}settings`.length).trim();
            return Spotlight.querySettings(query, query ? SettingsSearch.querySettingsScored(query) : []);
        }
        case "actions":
            return Actions.query(text);
        case "calc":
            return [0];
        case "ai":
            return [0];
        case "gpu":
            return Supergfxctl.modeData;
        case "ssh":
            return SSH.search(text);
        case "browser":
            return [0];
        default:
            return Apps.search(text);
        }
    }

    model: ScriptModel {
        values: {
            SSH.hostRevision;
            Supergfxctl.modeRevision;
            Supergfxctl.modeData;
            // The calculator answers off the main thread, so the unified list has to be rebuilt
            // when its answer arrives rather than only when the text changes
            Qalculator.rawResult;
            // Both of these answer off the main thread, so the list has to be rebuilt when their
            // results land rather than only when the text changes
            FileSearch.results;
            FileSearch.unavailable;
            return root.resultsForText(root.displayText);
        }
        onValuesChanged: root.currentIndex = 0
    }

    spacing: Tokens.spacing.small
    orientation: Qt.Vertical
    // The AI answer is one tall wrapping row, and the result rows come in two heights (the first
    // of each group carries its heading), so both are measured rather than counted. Every other
    // delegate is a fixed-height row, still capped by maxShown. ContentList clamps the whole thing
    // to maxHeight either way.
    //
    // Keyed off displayState, not state: `state` flips the moment you type, while the model keeps
    // showing the old results until the switch animation swaps them. Measuring the old uncapped
    // app list with the new state's rule is what made the panel shoot to full height for a moment
    // and then collapse back on the first keystroke.
    implicitHeight: displayState === "ai" || displayState === "spotlight" || displayState === "settings" || displayState === "files" ? contentHeight : (Tokens.sizes.launcher.itemHeight + spacing) * Math.min(Config.launcher.maxShown, count) - spacing

    preferredHighlightBegin: 0
    preferredHighlightEnd: height
    highlightRangeMode: ListView.ApplyRange

    highlightFollowsCurrentItem: false
    highlight: StyledRect {
        radius: Tokens.rounding.large
        color: Colours.palette.m3onSurface
        opacity: 0.08

        y: root.currentItem?.y ?? 0
        implicitWidth: root.width
        implicitHeight: root.currentItem?.implicitHeight ?? 0

        Behavior on y {
            Anim {}
        }
    }

    state: screenState.launcher ? requestedState : displayState

    onStateChanged: {
        if (state === "gpu")
            Supergfxctl.reload();
        else if (state === "ssh")
            SSH.reload();
    }

    Component.onCompleted: displayText = search.text

    states: [
        State {
            name: "apps"

            PropertyChanges {
                root.delegate: appItem
            }
        },
        State {
            name: "spotlight"

            PropertyChanges {
                root.delegate: resultItem
            }
        },
        State {
            name: "settings"

            PropertyChanges {
                root.delegate: resultItem
            }
        },
        State {
            name: "files"

            PropertyChanges {
                root.delegate: resultItem
            }
        },
        State {
            name: "actions"

            PropertyChanges {
                root.delegate: actionItem
            }
        },
        State {
            name: "calc"

            PropertyChanges {
                root.delegate: calcItem
            }
        },
        State {
            name: "ai"

            PropertyChanges {
                root.delegate: aiItem
            }
        },
        State {
            name: "gpu"

            PropertyChanges {
                root.delegate: actionItem
            }
        },
        State {
            name: "ssh"

            PropertyChanges {
                root.delegate: sshItem
            }
        },
        State {
            name: "browser"

            PropertyChanges {
                root.delegate: browserItem
            }
        }
    ]

    transitions: Transition {
        SequentialAnimation {
            PropertyAction {
                target: root
                property: "settled"
                value: false
            }
            ParallelAnimation {
                Anim {
                    target: root
                    property: "opacity"
                    from: 1
                    to: 0
                    duration: Tokens.anim.durations.small
                    easing: Tokens.anim.standardAccel
                }
                Anim {
                    target: root
                    property: "scale"
                    from: 1
                    to: 0.9
                    duration: Tokens.anim.durations.small
                    easing: Tokens.anim.standardAccel
                }
            }
            PropertyAction {
                target: root
                property: "delegate"
                value: null
            }
            ScriptAction {
                script: root.displayText = root.search.text
            }
            PropertyAction {
                target: root
                property: "delegate"
            }
            // Swapping the delegate out and back can leave an item from the old contents behind,
            // unpositioned at the top of the list and fully opaque - a whole row drawn over the
            // first real one. Relaying out drops it.
            ScriptAction {
                script: root.forceLayout()
            }
            ParallelAnimation {
                Anim {
                    target: root
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: Tokens.anim.durations.small
                    easing: Tokens.anim.standardDecel
                }
                Anim {
                    target: root
                    property: "scale"
                    from: 0.9
                    to: 1
                    duration: Tokens.anim.durations.small
                    easing: Tokens.anim.standardDecel
                }
            }
            PropertyAction {
                target: root
                property: "settled"
                value: true
            }
        }
    }

    StyledScrollBar.vertical: StyledScrollBar {
        flickable: root
    }

    add: Transition {
        enabled: root.settled && !root.rebuildsWholesale

        Anim {
            type: Anim.DefaultEffects
            property: "opacity"
            from: 0
            to: 1
        }
    }

    remove: Transition {
        enabled: root.settled && !root.rebuildsWholesale

        Anim {
            type: Anim.DefaultEffects
            property: "opacity"
            from: 1
            to: 0
        }
    }

    move: Transition {
        enabled: root.settled && !root.rebuildsWholesale

        Anim {
            property: "y"
        }
        Anim {
            type: Anim.DefaultEffects
            property: "opacity"
            to: 1
        }
    }

    // No y animation here, unlike `move` and `displaced`. A row being added takes its final place
    // immediately, so animating the rows it pushes down leaves the new row sitting on top of the
    // one that was there - a whole row's worth of text over text, for as long as the slide lasts
    addDisplaced: Transition {
        Anim {
            type: Anim.DefaultEffects
            property: "opacity"
            to: 1
        }
    }

    displaced: Transition {
        enabled: root.settled && !root.rebuildsWholesale

        Anim {
            property: "y"
        }
        Anim {
            type: Anim.DefaultEffects
            property: "opacity"
            to: 1
        }
    }

    Component {
        id: appItem

        AppItem {
            screenState: root.screenState
        }
    }

    Component {
        id: resultItem

        ResultItem {
            list: root
        }
    }

    Component {
        id: actionItem

        ActionItem {
            list: root
        }
    }

    Component {
        id: calcItem

        CalcItem {
            list: root
        }
    }

    Component {
        id: aiItem

        AiItem {
            list: root
        }
    }

    Component {
        id: sshItem

        ActionItem {
            list: root
        }
    }

    Component {
        id: browserItem

        BrowserItem {
            list: root
        }
    }

    Connections {
        function onTextChanged() {
            Spotlight.prime(root.search.text);
            FileSearch.prime(root.search.text);
            root.syncDisplayText();
        }

        target: root.search
    }

    Connections {
        function onLauncherChanged() {
            root.syncDisplayText();
        }

        target: root.screenState
    }
}
