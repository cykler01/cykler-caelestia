pragma Singleton

import QtQuick
import Quickshell
import Caelestia
import Caelestia.Config
import Caelestia.I18n

Singleton {
    id: root

    // Backing store for the "ai " launcher state: the item forwards the typed
    // question here, it is debounced and sent to the configured AI service.
    // Requests are tagged with an id so a stale reply can never overwrite a
    // newer answer.
    property string query
    property string answer
    property string errorText
    property bool busy: false

    // The services this can ask, and what each one needs. OpenAI and Ollama
    // share the chat-completions shape, and so does anything else that speaks it
    // (OpenRouter, Groq, LM Studio), which is what "custom" is that API pointed
    // at a URL of your own. `key` is whether an API key is required at all.
    readonly property list<var> providers: [
        {
            id: "gemini",
            name: "Google Gemini",
            icon: "auto_awesome",
            baseUrl: "https://generativelanguage.googleapis.com/v1beta",
            defaultModel: "gemini-3.5-flash-lite",
            key: true
        },
        {
            id: "openai",
            name: "OpenAI",
            icon: "smart_toy",
            baseUrl: "https://api.openai.com/v1",
            defaultModel: "gpt-5.4-mini",
            key: true
        },
        {
            id: "anthropic",
            name: "Anthropic",
            icon: "psychology",
            baseUrl: "https://api.anthropic.com/v1",
            defaultModel: "claude-sonnet-4-5",
            key: true
        },
        {
            id: "ollama",
            name: "Ollama (local)",
            icon: "dns",
            baseUrl: "http://localhost:11434/v1",
            defaultModel: "llama3.2",
            key: false
        },
        {
            id: "custom",
            name: "Custom (OpenAI-compatible)",
            icon: "settings_ethernet",
            baseUrl: "",
            defaultModel: "",
            key: true
        }
    ]

    readonly property var provider: root.providers.find(p => p.id === GlobalConfig.launcher.aiProvider) ?? root.providers[0]
    // Empty means whatever the provider suggests, so switching provider does not
    // leave a model name the new service has never heard of
    readonly property string model: (GlobalConfig.launcher.aiModel ?? "").trim() || root.provider.defaultModel
    // A URL set for a custom endpoint wins over the provider's own
    readonly property string baseUrl: ((GlobalConfig.launcher.aiBaseUrl ?? "").trim() || root.provider.baseUrl).replace(/\/+$/, "")

    readonly property bool configured: root.baseUrl !== "" && root.model !== "" && (!root.provider.key || GlobalConfig.launcher.aiApiKey !== "")

    readonly property string systemPrompt: "You are the launcher AI assistant of a Linux desktop shell for computer enthusiasts. Answer usefully and as briefly as possible, in plain text without any markdown formatting."

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
            errorText = root.provider.key && GlobalConfig.launcher.aiApiKey === "" ? Tr.trCtx("No API key", "launcher AI search error") : Tr.trCtx("Not configured", "launcher AI search error");
            return;
        }

        const id = ++requestId;
        busy = true;

        root.send([{
                role: "user",
                content: root.query
            }], root.systemPrompt, answer => root.handleAnswer(id, answer), (metadata, response) => root.handleError(id, metadata, response));
    }

    // The provider-shaped request for a conversation: the sidebar chat sends the whole
    // history through the same table, the launcher just one question. `messages` are
    // { role: "user"|"assistant", content }.
    function buildRequest(messages: var, system: string): var {
        switch (root.provider.id) {
        case "gemini":
            return {
                url: `${root.baseUrl}/models/${root.model}:generateContent`,
                body: {
                    contents: messages.map(m => ({
                            role: m.role === "assistant" ? "model" : "user",
                            parts: [{
                                    text: m.content
                                }]
                        })),
                    systemInstruction: {
                        parts: [{
                                text: system
                            }]
                    }
                },
                headers: {
                    "x-goog-api-key": GlobalConfig.launcher.aiApiKey
                },
                parse: root.answerFromGemini
            };
        case "anthropic":
            return {
                url: `${root.baseUrl}/messages`,
                body: {
                    model: root.model,
                    max_tokens: 1024,
                    system,
                    messages: messages.map(m => ({
                            role: m.role,
                            content: m.content
                        }))
                },
                headers: {
                    "x-api-key": GlobalConfig.launcher.aiApiKey,
                    "anthropic-version": "2023-06-01"
                },
                parse: root.answerFromAnthropic
            };
        default:
            // OpenAI, Ollama and everything else that speaks chat completions; the
            // key is optional because a local server has no use for one. The system
            // prompt is a message here rather than a field of its own.
            return {
                url: `${root.baseUrl}/chat/completions`,
                body: {
                    model: root.model,
                    messages: [{
                            role: "system",
                            content: system
                        }, ...messages.map(m => ({
                                    role: m.role,
                                    content: m.content
                                }))]
                },
                headers: GlobalConfig.launcher.aiApiKey !== "" ? {
                    "Authorization": `Bearer ${GlobalConfig.launcher.aiApiKey}`
                } : {},
                parse: root.answerFromOpenAi
            };
        }
    }

    // The plumbing all of them share; `parse` reads the reply into the answer, or
    // returns undefined when the reply was not one
    function send(messages: var, system: string, onAnswer: var, onError: var): void {
        const request = root.buildRequest(messages, system);
        Requests.post(request.url, JSON.stringify(request.body), text => onAnswer(request.parse(text)), (error, metadata, response) => onError(metadata, response), request.headers);
    }

    function handleAnswer(id: int, answer: var): void {
        if (id !== root.requestId)
            return;

        busy = false;
        errorText = "";

        if (answer === undefined) {
            root.answer = "";
            errorText = Tr.tr("AI request failed");
            return;
        }

        root.answer = answer;
        if (!answer)
            errorText = Tr.tr("The AI returned no answer");
    }

    function handleError(id: int, metadata: var, response: string): void {
        if (id !== root.requestId)
            return;

        busy = false;
        root.answer = "";
        errorText = root.errorMessage(metadata, response);
    }

    // The message to show for a failed request, shared with the sidebar chat
    function errorMessage(metadata: var, response: string): string {
        let message;
        try {
            message = JSON.parse(response).error?.message;
        } catch (parseError) {
            console.warn(lc, `Unable to parse the AI error response: ${parseError}`);
        }

        if (typeof message === "string" && message)
            return message;

        const status = metadata?.statusCode;
        return status === 401 || status === 403 ? Tr.trCtx("No API key", "launcher AI search error") : status === 429 ? Tr.trCtx("Rate limited", "launcher AI search error") : Tr.tr("AI request failed (HTTP %1)").arg(status ?? 0);
    }

    // Gemini: the parts of the first candidate, joined because a reply can arrive
    // in several of them
    function answerFromGemini(text: string): var {
        let json;
        try {
            json = JSON.parse(text);
        } catch (error) {
            console.warn(lc, `Unable to parse the AI response: ${error}`);
            return undefined;
        }

        return json.candidates?.[0]?.content?.parts?.map(part => part.text).filter(Boolean).join("") ?? "";
    }

    // OpenAI: the assistant message, which is a string, or the same parts shape as
    // Gemini on some compatible endpoints
    function answerFromOpenAi(text: string): var {
        let json;
        try {
            json = JSON.parse(text);
        } catch (error) {
            console.warn(lc, `Unable to parse the AI response: ${error}`);
            return undefined;
        }

        const content = json.choices?.[0]?.message?.content;
        if (typeof content === "string")
            return content;

        return content?.map(part => part.text).filter(Boolean).join("") ?? "";
    }

    // Anthropic: the text blocks of the message, leaving out any thinking or tool
    // blocks that come with them
    function answerFromAnthropic(text: string): var {
        let json;
        try {
            json = JSON.parse(text);
        } catch (error) {
            console.warn(lc, `Unable to parse the AI response: ${error}`);
            return undefined;
        }

        return json.content?.filter(block => block.type === "text").map(block => block.text).join("") ?? "";
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
