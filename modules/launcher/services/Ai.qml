pragma Singleton

import QtQuick
import Quickshell
import Caelestia
import Caelestia.Config
import Caelestia.I18n

Singleton {
    id: root

    // Backing store for the "ai " launcher state: the item forwards the typed
    // question here, it is debounced and sent to the Gemini API. Requests are
    // tagged with an id so a stale reply can never overwrite a newer answer.
    property string query
    property string answer
    property string errorText
    property bool busy: false

    readonly property bool configured: GlobalConfig.launcher.aiApiKey !== ""
    property int requestId: 0

    function setQuery(query: string): void {
        query = query.trim();

        if (query === root.query)
            return;

        requestId++;
        busy = false;

        root.query = query;
        answer = "";
        errorText = "";

        if (!query) {
            requestTimer.running = false;
            return;
        }

        requestTimer.restart();
    }

    function ask(): void {
        if (!root.query)
            return;

        if (!root.configured) {
            errorText = Tr.trCtx("No API key", "launcher AI search error");
            return;
        }

        const id = ++requestId;
        busy = true;

        const body = JSON.stringify({
            contents: [{
                    parts: [{
                            text: root.query
                        }]
                }],
            systemInstruction: {
                parts: [{
                        text: "You are the launcher AI assistant of a Linux desktop shell for computer enthusiasts. Answer usefully and as briefly as possible, in plain text without any markdown formatting."
                    }]
            }
        });

        Requests.post(`https://generativelanguage.googleapis.com/v1beta/models/${GlobalConfig.launcher.aiModel}:generateContent`, body, text => {
            if (id !== root.requestId)
                return;

            busy = false;
            errorText = "";

            let parts;
            try {
                parts = JSON.parse(text).candidates?.[0]?.content?.parts;
            } catch (error) {
                console.warn(lc, `Unable to parse the AI response: ${error}`);
                errorText = Tr.tr("AI request failed");
                return;
            }

            const answer = parts?.map(part => part.text).filter(Boolean).join("") ?? "";
            if (!answer)
                errorText = Tr.tr("The AI returned no answer");
            root.answer = answer;
        }, (error, metadata, response) => {
            if (id !== root.requestId)
                return;

            busy = false;
            root.answer = "";

            let message;
            try {
                message = JSON.parse(response).error.message;
            } catch (parseError) {
                console.warn(lc, `Unable to parse the AI error response: ${parseError}`);
            }

            if (typeof message === "string" && message) {
                errorText = message;
                return;
            }

            const status = metadata?.statusCode;
            errorText = status === 403 ? Tr.trCtx("No API key", "launcher AI search error") : status === 429 ? Tr.trCtx("Rate limited", "launcher AI search error") : Tr.tr("AI request failed (HTTP %1)").arg(status ?? 0);
        }, {
            "x-goog-api-key": GlobalConfig.launcher.aiApiKey
        });
    }

    // Delays the request until the question has settled for the timer's
    // duration, so typing a whole question does not fire a call per keystroke
    Timer {
        id: requestTimer

        interval: 600
        onTriggered: root.ask()
    }

    LoggingCategory {
        id: lc

        name: "caelestia.qml.modules.launcher.ai"
        defaultLogLevel: LoggingCategory.Warning
    }
}
