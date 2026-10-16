pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components.controls
import qs.modules.nexus
import qs.modules.nexus.common

PageBase {
    id: root

    readonly property list<string> alignNames: [
        Tr.trCtx("Left", "panel alignment"),
        Tr.trCtx("Centre", "panel alignment"),
        Tr.trCtx("Right", "panel alignment")
    ]

    readonly property list<string> edgeNames: [
        Tr.trCtx("Top", "panel edge"),
        Tr.trCtx("Bottom", "panel edge")
    ]

    title: Tr.tr("Launcher")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // General
        SectionHeader {
            first: true
            text: Tr.tr("General")
        }

        ToggleRow {
            first: true
            text: Tr.trCtx("Enabled", "toggle label")
            checked: Config.launcher.enabled
            onToggled: GlobalConfig.launcher.enabled = checked
        }

        ToggleRow {
            text: Tr.tr("Show on hover")
            subtext: Tr.tr("Reveal when the cursor reaches the screen edge")
            checked: Config.launcher.showOnHover
            onToggled: GlobalConfig.launcher.showOnHover = checked
        }

        TextFieldRow {
            id: prefixRow

            last: true
            label: Tr.tr("Action prefix")
            subtext: Tr.tr("Prefix used to run actions in the launcher")
            errorText: Tr.tr("Prefix must not be alphanumeric")
            value: GlobalConfig.launcher.actionPrefix === ">" ? "" : GlobalConfig.launcher.actionPrefix // TODO: replace with empty only when not loaded once loaded state is exposed
            placeholderText: ">"
            maximumLength: 1
            smallField: true
            validate: /^[^a-zA-Z0-9\s]$/
            onEditingFinished: value => {
                if (!field.valid)
                    return;
                /// TODO: replace with GlobalConfig.launcher.resetOption("actionPrefix") on empty commit when reset is fixed
                GlobalConfig.launcher.actionPrefix = value || ">";
                if (GlobalConfig.launcher.actionPrefix === ">")
                    clear();
            }
        }

        // Position
        SectionHeader {
            text: Tr.tr("Position")
        }

        NavRow {
            first: true
            last: true
            icon: "dashboard_customize"
            text: Tr.tr("Screen position")
            subtext: Tr.tr("Currently %1 — change it, and everything else's position, in Layout").arg(`${root.edgeNames[Config.launcher.edge] ?? root.edgeNames[0]} · ${root.alignNames[Config.launcher.align] ?? root.alignNames[0]}`)
            onClicked: root.nState.currentPageIdx = PageRegistry.indexOfKey("layout")
        }

        // Display
        SectionHeader {
            text: Tr.tr("Display")
        }

        StepperRow {
            first: true
            label: Tr.tr("Max items shown")
            value: Config.launcher.maxShown
            from: 1
            to: 20
            stepSize: 1
            onMoved: v => GlobalConfig.launcher.maxShown = v
        }

        StepperRow {
            label: Tr.tr("Max wallpapers")
            value: Config.launcher.maxWallpapers
            from: 1
            to: 30
            stepSize: 1
            onMoved: v => GlobalConfig.launcher.maxWallpapers = v
        }

        StepperRow {
            last: true
            label: Tr.tr("Drag threshold")
            subtext: Tr.tr("Pixels dragged before the launcher opens")
            value: Config.launcher.dragThreshold
            from: 0
            to: 200
            stepSize: 5
            onMoved: v => GlobalConfig.launcher.dragThreshold = v
        }

        // Behaviour
        SectionHeader {
            text: Tr.tr("Behaviour")
        }

        ToggleRow {
            first: true
            text: Tr.tr("Vim keybinds")
            subtext: Tr.tr("Navigate results with Ctrl+hjkl")
            checked: GlobalConfig.launcher.vimKeybinds
            onToggled: GlobalConfig.launcher.vimKeybinds = checked
        }

        ToggleRow {
            text: Tr.tr("Enable dangerous actions")
            subtext: Tr.tr("Allow actions that shut down or log out")
            checked: GlobalConfig.launcher.enableDangerousActions
            onToggled: GlobalConfig.launcher.enableDangerousActions = checked
        }

        ToggleRow {
            last: true
            text: Tr.tr("Enable Supergfxctl")
            subtext: Tr.tr("Show GPU mode switching for ASUS laptops")
            checked: GlobalConfig.launcher.enableSupergfxctl
            onToggled: GlobalConfig.launcher.enableSupergfxctl = checked
        }

        // Fuzzy search
        SectionHeader {
            text: Tr.tr("Fuzzy search")
        }

        ToggleRow {
            first: true
            text: Tr.tr("Apps")
            checked: GlobalConfig.launcher.useFuzzy.apps
            onToggled: GlobalConfig.launcher.useFuzzy.apps = checked
        }

        ToggleRow {
            text: Tr.tr("Actions")
            checked: GlobalConfig.launcher.useFuzzy.actions
            onToggled: GlobalConfig.launcher.useFuzzy.actions = checked
        }

        ToggleRow {
            last: true
            text: Tr.tr("Wallpapers")
            checked: GlobalConfig.launcher.useFuzzy.wallpapers
            onToggled: GlobalConfig.launcher.useFuzzy.wallpapers = checked
        }

        // AI search
        SectionHeader {
            text: Tr.tr("AI search")
        }

        TextFieldRow {
            first: true
            label: Tr.tr("API key")
            subtext: Tr.tr("Google Gemini API key for the launcher's AI search")
            value: GlobalConfig.launcher.aiApiKey
            onEditingFinished: value => GlobalConfig.launcher.aiApiKey = value.trim()
        }

        TextFieldRow {
            last: true
            label: Tr.tr("Model")
            subtext: Tr.tr("Gemini model to ask, e.g. gemini-3.5-flash-lite")
            value: GlobalConfig.launcher.aiModel
            onEditingFinished: value => {
                const trimmed = value.trim();
                if (trimmed)
                    GlobalConfig.launcher.aiModel = trimmed;
            }
        }
    }
}
